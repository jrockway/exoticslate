package Socialtext::User::LDAP::Factory;
# @COPYRIGHT@

use strict;
use warnings;
use Class::Field qw(field);
use Socialtext::LDAP;
use Socialtext::User::LDAP;
use Socialtext::Log qw(st_log);
use Net::LDAP::Util qw(escape_filter_value);
use Socialtext::SQL qw(sql_execute sql_singlevalue);
use Readonly;

field 'ldap';

Readonly my %valid_search_terms => (
    user_id         => 1,
    username        => 1,
    email_address   => 1,
    );

sub new {
    my ($class, $driver_id) = @_;

    # connect to named LDAP server
    my $ldap = Socialtext::LDAP->new($driver_id);
    return unless $ldap;

    # create the factory object
    my $self = {
        ldap    => $ldap,
    };
    bless $self, $class;
}

sub driver_name { 'LDAP' }

sub driver_id {
    my $self = shift;
    return $self->ldap->config->id;
}

sub driver_key {
    my $self = shift;
    my @components = $self->driver_name();
    if ($self->driver_id()) {
        push @components, $self->driver_id();
    }
    return join ':', @components;
}

sub attr_map {
    my $self = shift;
    my %attr_map = %{$self->ldap->config->attr_map()};
    $attr_map{driver_unique_id} = delete $attr_map{user_id};
    return \%attr_map;
}

sub GetUser {
    my ($self, $key, $val) = @_;

    # SANITY CHECK: have inbound parameters
    return undef unless $key;
    return undef unless $val;

    # SANITY CHECK: search term is acceptable
    return undef unless ($valid_search_terms{$key});

    # search LDAP directory for our record
    my $mesg = $self->_find_user( $key, $val );
    unless ($mesg) {
        st_log->error( "ST::User::LDAP: no suitable LDAP response" );
        return undef;
    }
    if ($mesg->code()) {
        st_log->error( "ST::User::LDAP: LDAP error while finding user; " . $mesg->error() );
        return undef;
    }
    if ($mesg->count() > 1) {
        st_log->error( "ST::User::LDAP: found multiple matches for user; $key/$val" );
        return undef;
    }

    # extract result record
    my $result = $mesg->shift_entry();
    unless ($result) {
        st_log->debug( "ST::User::LDAP: unable to find user in LDAP; $key/$val" );
        return undef;
    }

    # instantiate from search results
    my $attr_map = $self->attr_map;
    my $user = {
        driver_key  => $self->driver_key(),
    };
    while (my ($user_attr, $ldap_attr) = each %{$attr_map}) {
        if ($ldap_attr =~ m{^(dn|distinguishedName)$}) {
            # DN isn't an attribute, its a Net::LDAP::Entry method
            $user->{$user_attr} = $result->dn();
        }
        else {
            $user->{$user_attr} = $result->get_value( $ldap_attr );
        }
    }

    $self->_vivify($user);
    return Socialtext::User::LDAP->new_from_hash($user);
}

sub _vivify {
    my ($self, $p) = @_;

    $p->{driver_key} ||= $self->driver_key;

    # NOTE: *always* use the driver_unique_id to update LDAP user records

    my $user_id = sql_singlevalue(
        q{SELECT user_id FROM users 
          WHERE driver_key = ? AND driver_unique_id = ?},
        $p->{driver_key},
        $p->{driver_unique_id}
    );
    unless ($user_id) {
        $user_id = Socialtext::User::Base->NewUserId();
        sql_execute(q{
                INSERT INTO users
                (user_id, driver_key, driver_username, driver_unique_id, email_address)
                VALUES
                (?, ?, ?, ?, ?)
            },
            $user_id, $p->{driver_key}, $p->{username},
            $p->{driver_unique_id}, $p->{email_address}
        );
        # just created a new user in the DB; flush the cache
        Socialtext::User::Cache->Clear();
    }
    $p->{user_id} = $user_id;
}

sub Search {
    my ($self, $term) = @_;
    my $ldap = $self->ldap();

    # SANITY CHECK: have inbound parameters
    return unless $term;
    $term = escape_filter_value($term);

    # build up the search options
    my $attr_map = $ldap->config->attr_map();
    my $filter = join ' ',
                    map { "($_=*$term*)" }
                    values %{$attr_map};
    my %options = (
        base    => $ldap->config->base(),
        scope   => 'sub',
        filter  => "(|$filter)",
        attrs   => [ values %{$attr_map} ],
        );

    # execute search against LDAP directory
    my $mesg = $ldap->search( %options );
    unless ($mesg) {
        st_log->error( "ST::User::LDAP; no suitable LDAP response" );
        return;
    }
    if ($mesg->code()) {
        st_log->error( "ST::User::LDAP; LDAP error while performing search; " . $mesg->error() );
        return;
    }

    # extract search results
    my @users;
    foreach my $rec ($mesg->entries()) {
        my $email = $rec->get_value( $attr_map->{email_address} );
        my $first = $rec->get_value( $attr_map->{first_name} );
        my $last  = $rec->get_value( $attr_map->{last_name} );
        push @users, {
            driver_name     => $self->driver_key(),
            email_address   => $email,
            name_and_email  => Socialtext::User->FormattedEmail($first, $last, $email),
            };
    }
    return @users;
}

sub _find_user {
    my ($self, $key, $val) = @_;
    my $ldap     = $self->ldap();
    my $attr_map = $ldap->config->attr_map();

    # map the ST::User key to an LDAP attribute
    my $search_attr = $attr_map->{$key};
    return undef unless ($search_attr);

    # we want all of the attributes in our attr_map *EXCEPT* the password.
    # we NEVER, EVER, EVER want to query the password.
    #
    # The "password" attr_map entry has been deprecated and removed from all
    # docs/code, *but* its still possible that some legacy installs have it
    # set up.  *DON'T* remove this code unless a migration script is put in
    # place that cleans up LDAP configs and removes unknown attributes from
    # the map.
    my @attrs = map { $attr_map->{$_} }
                    grep { $_ ne 'password' }
                    keys %{$attr_map};

    # build up the search options
    my %options = (
        base    => $ldap->config->base(),
        scope   => 'sub',
        attrs   => \@attrs,
        );
    if ($search_attr =~ m{^(dn|distinguishedName)$}) {
        # DN searches are best done as -exact- searches
        $options{'base'}    = $val;
        $options{'scope'}   = 'base';
        $options{'filter'}  = '(objectClass=*)';
    }
    else {
        # all other searches are done as sub-tree under Base DN
        $val = escape_filter_value($val);
        $options{'filter'}  = "($search_attr=$val)";
    }

    # search LDAP, and return results back to caller
    return $ldap->search( %options );
}


1;

=head1 NAME

Socialtext::User::LDAP::Factory - A Socialtext LDAP User Factory

=head1 SYNOPSIS

  use Socialtext::User::LDAP::Factory;

  # create a default LDAP factory
  $factory = Socialtext::User::LDAP::Factory->new();

  # create a LDAP factory for named LDAP configuration
  $factory = Socialtext::User::LDAP::Factory->new('My LDAP Config');

  # use the factory to find user records
  $user = $factory->GetUser( user_id => $user_id );
  $user = $factory->GetUser( username => $username );
  $user = $factory->GetUser( email_address => $email );

  # user search
  @results = $factory->Search( 'foo' );

=head1 DESCRIPTION

C<Socialtext::User::LDAP::Factory> provides a User factory for user records
that happen to exist in an LDAP data store.

=head1 METHODS

=over

=item B<Socialtext::User::LDAP::Factory-E<gt>new($driver_id)>

Creates a new LDAP user factory, for the named LDAP configuration.

If no LDAP configuration name is provided, the default LDAP configuration will
be used.

=item B<driver_name()>

Returns the name of the driver this Factory implements, "LDAP".

=item B<driver_id()>

Returns the unique ID of the LDAP configuration instance used by this Factory.
e.g. "0deadbeef0".

=item B<driver_key()>

Returns the full driver key ("name:id") of the LDAP instance used by this
Factory.  e.g. "LDAP:0deadbeef0".

=item B<attr_map()>

Returns the mapping of Socialtext user attributes (as they appear in the DB)
to their respective LDAP representations.

This B<is> different than the mapping returned by
C<Socialtext::LDAP::Config-E<gt>attr_map()> in that this mapping is
specifically targetted towards the underlying database representation of the
user attributes.

=item B<GetUser($key, $val)>

Searches for the specified user in the LDAP data store and returns a new
C<Socialtext::User::LDAP> object representing that user if it exists.

User lookups can be performed by I<one> of:

=over

=item * user_id => $user_id

=item * username => $username

=item * email_address => $email_address

=back

=item B<Search($term)>

Searches for user records where the given search C<$term> is found in any one
of the following fields:

=over

=item * username

=item * email_address

=item * first_name

=item * last_name

=back

The search will return back to the caller a list of hash-refs containing the
following key/value pairs:

=over

=item driver_name

The unique driver key for the instance of the data store that the user was
found in.  e.g. "LDAP:0deadbeef0".

=item email_address

The e-mail address for the user.

=item name_and_email

The canonical name and e-mail for this user, as produced by
C<Socialtext::User-E<gt>FormattedEmail()>.

=back

=back

=head1 AUTHOR

Socialtext, Inc.  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2008 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
