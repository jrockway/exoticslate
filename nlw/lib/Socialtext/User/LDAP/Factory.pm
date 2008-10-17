package Socialtext::User::LDAP::Factory;
# @COPYRIGHT@

use strict;
use warnings;
use Class::Field qw(field const);
use Socialtext::LDAP;
use Socialtext::User::LDAP;
use Socialtext::Log qw(st_log);
use Net::LDAP::Util qw(escape_filter_value);
use Socialtext::SQL qw(sql_execute sql_singlevalue);
use Readonly;

field 'ldap_config'; # A Socialtext::LDAP::Config object

# only connect to the LDAP server when we really need to:
field 'ldap', -init => 'Socialtext::LDAP->new($self->ldap_config)';

field 'driver_id', -init => '$self->ldap_config->id';
const 'driver_name' => 'LDAP';
field 'driver_key', -init => '$self->driver_name . ":" . $self->driver_id';

Readonly my %valid_get_user_terms => (
    user_id          => 1,
    username         => 1,
    email_address    => 1,
    driver_unique_id => 1,
);

sub new {
    my ($class, $driver_id) = @_;

    my $config = Socialtext::LDAP->ConfigForId($driver_id);
    return unless $config; # driver configuration is missing

    # create the factory object
    my $self = {
        ldap_config => $config,
    };
    bless $self, $class;
}

# this should create (and thus connect) the LDAP object if this has not
# already happened.
sub connect { return $_[0]->ldap; }

field 'attr_map', -init => '$self->_attr_map()';
sub _attr_map {
    my $self = shift;
    my %attr_map = %{$self->ldap_config->attr_map()}; # copy!
    $attr_map{driver_unique_id} = delete $attr_map{user_id};

    # The "password" attr_map entry has been deprecated and removed from all
    # docs/code, *but* its still possible that some legacy installs have it
    # set up.  *DON'T* remove this code unless a migration script is put in
    # place that cleans up LDAP configs and removes unknown attributes from
    # the map.
    delete $attr_map{password};

    return \%attr_map;
}

sub GetUser {
    my ($self, $key, $val) = @_;

    # SANITY CHECK: have inbound parameters
    return unless $key;
    return unless $val;

    # SANITY CHECK: get user term is acceptable
    return unless ($valid_get_user_terms{$key});

    local $self->{_cache_lookup}; # temporary cache-lookup storage
    my $cached = $self->_check_cache($key => $val);

    return $cached if $cached;

    local $self->{_user_not_found};
    my $proto_user = $self->lookup($key => $val);

    if ($proto_user) {
        $self->_vivify($proto_user);
        return Socialtext::User::LDAP->new_from_hash($proto_user);
    }

    if ($self->{_cache_lookup}) {
        if ($self->{_user_not_found}) {
            # The cache found the user, but the LDAP server cannot find them.
            # This means the user existed in our system at some point but is
            # no longer on the server.  Convert the cached homunculus to a
            # Deleted user:
            return Socialtext::User::Deleted->new(
                $self->{_cache_lookup}
            );
        }
        else {
            # Some other LDAP error caused us to not find the user (e.g. a
            # connection problem).  Return what we found in the cache (which
            # is expired) as it's better than nothing.
            return $self->{_cache_lookup};
        }
    }

    return;
}

sub lookup {
    my ($self, $key, $val) = @_;

    # SANITY CHECK: lookup term is acceptable
    return unless ($valid_get_user_terms{$key});

    # search LDAP directory for our record
    my $mesg = $self->_find_user($key => $val);
    unless ($mesg) {
        st_log->error( "ST::User::LDAP: no suitable LDAP response" );
        return;
    }
    if ($mesg->code()) {
        st_log->error( "ST::User::LDAP: LDAP error while finding user; " . $mesg->error() );
        return;
    }
    if ($mesg->count() > 1) {
        st_log->error( "ST::User::LDAP: found multiple matches for user; $key/$val" );
        return;
    }

    # extract result record
    my $result = $mesg->shift_entry();
    unless ($result) {
        st_log->debug( "ST::User::LDAP: unable to find user in LDAP; $key/$val" );
        # XXX: other code expects lookup() to return false when it can't find
        # the LDAP user.  Throwing an exception seems like the right thing to
        # do, but we can't do that either due to previous design decisions.
        # For now, set a private field that GetUser can check ~stash
        $self->{_user_not_found} = 1;
        return;
    }

    # instantiate from search results
    my $attr_map = $self->attr_map;
    my $proto_user = {
        driver_key  => $self->driver_key(),
    };
    while (my ($user_attr, $ldap_attr) = each %$attr_map) {
        if ($ldap_attr =~ m{^(dn|distinguishedName)$}) {
            # DN isn't an attribute, its a Net::LDAP::Entry method
            $proto_user->{$user_attr} = $result->dn();
        }
        else {
            $proto_user->{$user_attr} = $result->get_value($ldap_attr);
        }
    }

    return $proto_user;
}

sub _check_cache {
    my ($self, $key, $val) = @_;

    # get cached user data, returning that if the cache is fresh
    my $cached = Socialtext::User::Base->GetUserRecord(
        $key, $val, $self->driver_key
    );
    return unless $cached;
    return unless $cached->cached_at;

    # We might need to use an expired cached copy if the LDAP query fails.
    $self->{_cache_lookup} = $cached;

    my $ttl    = $self->cache_ttl;
    my $cutoff = Socialtext::User::Base::_hires_dt_now() - $ttl;

    return unless ($cached->cached_at > $cutoff);

    #warn "Cached LDAP user is fresh";
    return $cached;
}

sub cache_ttl {
    my $self = shift;
    return DateTime::Duration->new( seconds => $self->ldap_config->ttl );
}

sub _vivify {
    my ($self, $proto_user) = @_;

    $proto_user->{driver_key} ||= $self->driver_key;

    # NOTE: *always* use the driver_unique_id to update LDAP user records

    $proto_user->{driver_username} = delete $proto_user->{username};
    $proto_user->{cached_at} = 'now'; # auto-set to 'now'
    $proto_user->{password} = '*no-password*';

    my $user_id = Socialtext::User::Base->ResolveId($proto_user);

    if ($user_id) {
        # update cache
        $proto_user->{user_id} = $user_id;
        Socialtext::User::Base->UpdateUserRecord($proto_user);
    }
    else {
        # will add a user_id to $proto_user:
        Socialtext::User::Base->NewUserRecord($proto_user);
    }

    $proto_user->{username} = delete $proto_user->{driver_username};
}

sub Search {
    my ($self, $term) = @_;

    # SANITY CHECK: have inbound parameters
    return unless $term;
    $term = escape_filter_value($term);

    # build up the search options
    my $attr_map = $self->attr_map;
    my $filter = join ' ', map { "($_=*$term*)" } values %$attr_map;

    my %options = (
        base    => $self->ldap_config->base(),
        scope   => 'sub',
        filter  => "(|$filter)",
        attrs   => [ values %$attr_map ],
    );

    # execute search against LDAP directory
    my $ldap = $self->ldap();
    return unless $ldap;
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
        my $email = $rec->get_value($attr_map->{email_address});
        my $first = $rec->get_value($attr_map->{first_name});
        my $last  = $rec->get_value($attr_map->{last_name});
        push @users, {
            driver_name     => $self->driver_key(),
            email_address   => $email,
            name_and_email  => 
                Socialtext::User->FormattedEmail($first, $last, $email),
        };
    }
    return @users;
}

sub _find_user {
    my ($self, $key, $val) = @_;

    my $attr_map = $self->attr_map();

    # map the ST::User key to an LDAP attribute
    my $search_attr = $attr_map->{$key};
    return unless $search_attr;

    # build up the search options
    my %options = (
        attrs => [ values %$attr_map ],
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
        $options{'base'}    = $self->ldap_config->base(),
        $options{'scope'}   = 'sub';
        $options{'filter'}  = "($search_attr=$val)";
    }

    my $ldap = $self->ldap;
    return unless $ldap;
    return $self->ldap->search( %options );
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

=item B<cache_ttl()>

Returns a C<DateTime::Duration> object representing the TTL for this Factory's
LDAP data.

=item B<GetUser($key, $val)>

Searches for the specified user in the LDAP data store and returns a new
C<Socialtext::User::LDAP> object representing that user if it exists.

User lookups can be performed by I<one> of:

=over

=item * user_id => $user_id

=item * username => $username

=item * email_address => $email_address

=back

=item B<lookup($key, $val)>

Looks up a user in the LDAP data store and returns a hash-ref of data on that
user.

Lookups can be performed using the same criteria as listed for C<GetUser()>
above.

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
