package Socialtext::User::LDAP;
# @COPYRIGHT@

use strict;
use warnings;
use Class::Field qw(field);
use Socialtext::LDAP;
use Socialtext::User;
use Socialtext::Log qw(st_log);
use Readonly;

our $VERSION = '0.02';

field 'user_id';
field 'username';
field 'email_address';
field 'first_name';
field 'last_name';

Readonly my %valid_search_terms => (
    user_id         => 1,
    username        => 1,
    email_address   => 1,
    );

sub new {
    my ($class, $key, $val) = @_;

    # SANITY CHECK: have inbound parameters
    return undef unless $key;
    return undef unless $val;

    # SANITY CHECK: search term is acceptable
    return undef unless ($valid_search_terms{$key});

    # connect to LDAP server
    my $ldap = Socialtext::LDAP->new();
    return undef unless $ldap;

    # search LDAP directory for our record
    my $mesg = _ldap_find_user( $ldap, $key, $val );
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
    my $attr_map = $ldap->config->attr_map();
    my $self     = {};
    while (my ($user_attr, $ldap_attr) = each %{$attr_map}) {
        if ($ldap_attr =~ m{^(dn|distinguishedName)$}) {
            # DN isn't an attribute, its a Net::LDAP::Entry method
            $self->{$user_attr} = $result->dn();
        }
        else {
            $self->{$user_attr} = $result->get_value( $ldap_attr );
        }
    }
    bless $self, $class;
    return $self;
}

sub driver_name {
    return 'LDAP';
}

sub has_valid_password {
    return 1;
}

sub password {
    return '*no-password*';
}

sub password_is_correct {
    my ($self, $pass) = @_;

    # empty passwords not allowed
    return 0 unless ($pass);

    # authenticate against LDAP server
    return Socialtext::LDAP->authenticate($self->user_id(), $pass);
}

sub Search {
    my ($class, $term) = @_;

    # SANITY CHECK: have inbound parameters
    return unless $term;

    # connect to LDAP server
    my $ldap = Socialtext::LDAP->new();
    return unless $ldap;

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
            driver_name     => $class->driver_name(),
            email_address   => $email,
            name_and_email  => Socialtext::User->FormattedEmail($first, $last, $email),
            };
    }
    return @users;
}

sub _ldap_find_user {
    my ($ldap, $key, $val) = @_;
    my $attr_map = $ldap->config->attr_map();

    # map the ST::User key to an LDAP attribute
    my $search_attr = $attr_map->{$key};
    return undef unless ($search_attr);

    # build up the search options
    my %options = (
        base    => $ldap->config->base(),
        scope   => 'sub',
        attrs   => [ values %{$attr_map} ],
        );
    if ($search_attr =~ m{^(dn|distinguishedName)$}) {
        # DN searches are best done as -exact- searches
        $options{'base'}    = $val;
        $options{'scope'}   = 'base';
        $options{'filter'}  = '(objectClass=*)';
    }
    else {
        # all other searches are done as sub-tree under Base DN
        $options{'filter'}  = "($search_attr=$val)";
    }

    # search LDAP, and return results back to caller
    return $ldap->search( %options );
}


1;

=head1 NAME

Socialtext::User::LDAP - A Socialtext LDAP User Factory

=head1 SYNOPSIS

  use Socialtext::User::LDAP;

  # instantiate user
  $user = Socialtext::User::LDAP->new( user_id => $user_id );
  $user = Socialtext::User::LDAP->new( username => $username );
  $user = Socialtext::User::LDAP->new( email_address => $email );

  # authenticate (an already instantiated user)
  $auth_ok = $user->password_is_correct( $password );

  # user search
  @results = Socialtext::User::LDAP->Search( 'foo' );

=head1 DESCRIPTION

C<Socialtext::User::LDAP> provides an implementation for a User record that
happens to exist in an LDAP data store.

=head1 METHODS

=over

=item B<Socialtext::User::LDAP-E<gt>new($key,$val)>

Searches for the specified user in the LDAP data store and returns a new
LDAP User object if it exists.

User lookups can be performed by I<one> of:

=over

=item * user_id => $user_id

=item * username => $username

=item * email_address => $email_address

=back

=item B<user_id()>

Returns the ID for the user, as per the attribute mapping in the LDAP
configuration.

=item B<username()>

Returns the username for the user, as per the attribute mapping in the LDAP
configuration.

=item B<email_address()>

Returns the e-mail address for the user, as per the attribute mapping in the
LDAP configuration.  If the user has multiple e-mail addresses, only the
B<first> is returned.

=item B<first_name()>

Returns the first name for the user, as per the attribute mapping in the LDAP
configuration.

=item B<last_name()>

Returns the last name for the user, as per the attribute mapping in the LDAP
configuration.

=item B<driver_name()>

Returns the name of the driver used for the data store this user was found in.

=item B<password_is_correct($pass)>

Checks to see if the given password is correct for this user.  Returns true if
the given password is correct, false otherwise.

This check is performed by attempting to re-bind to the LDAP connection as the
user.

=item B<has_valid_password()>

Returns true if the user has a valid password.

=item B<Socialtext::User::LDAP-E<gt>Search($term)>

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

Name of the driver for the data store that the user was found in.

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
