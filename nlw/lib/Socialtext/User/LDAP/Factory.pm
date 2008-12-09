package Socialtext::User::LDAP::Factory;
# @COPYRIGHT@

use strict;
use warnings;

use base qw(Socialtext::User::Factory);

use Class::Field qw(field const);
use Socialtext::LDAP;
use Socialtext::User::LDAP;
use Socialtext::Log qw(st_log);
use Socialtext::SQL qw(sql_selectrow);
use Net::LDAP::Util qw(escape_filter_value);
use Socialtext::SQL qw(sql_execute sql_singlevalue);
use Readonly;

# Flag to allow for the long-term caching of LDAP user data in the DB to be
# disabled.
#
# FOR TESTING/INSTRUMENTATION PURPOSES ONLY!!!
#
# This should *NEVER* be disabled in a production environment!
our $CacheEnabled = 1;

# please treat these fields as read-only:

field 'ldap_config'; # A Socialtext::LDAP::Config object

# only connect to the LDAP server when we really need to:
field 'ldap', -init => 'Socialtext::LDAP->new($self->ldap_config)';

field 'driver_id', -init => '$self->ldap_config->id';
const 'driver_name' => 'LDAP';
field 'driver_key', -init => '$self->driver_name . ":" . $self->driver_id';

field 'attr_map', -init => '$self->_attr_map()';

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
    if ($CacheEnabled) {
        my $cached = $self->_check_cache($key => $val);
        return $cached if $cached;
    }

    local $self->{_user_not_found};
    my $proto_user = $self->lookup($key => $val);

    if ($proto_user) {
        $self->_vivify($proto_user);
        return $self->new_homunculus($proto_user);
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

    # SANITY CHECK: given a value to lookup
    return unless ((defined $val) && ($val ne ''));

    # EDGE CASE: lookup by user_id
    #
    # The 'user_id' is internal to ST and isn't stored/held in the LDAP
    # server, so we handle this as a special case; grab the data we've got on
    # this user out of the DB and recursively look the user up by each of the
    # possible unique identifiers.
    if ($key eq 'user_id') {
        return if ($val =~ /\D/);   # id *must* be numeric

        my ($unique_id, $username, $email) =
            sql_selectrow(
                q{SELECT driver_unique_id, driver_username, email_address
                   FROM users
                  WHERE driver_key=? AND user_id=?
                },
                $self->driver_key, $val,
            );

        my $user = $self->lookup( driver_unique_id => $unique_id )
                || $self->lookup( username => $username )
                || $self->lookup( email_address => $email );
        return $user;
    }

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
    my $cached = $self->GetHomunculus(
        $key, $val, $self->driver_key
    );
    return unless $cached;
    return unless $cached->cached_at;

    # We might need to use an expired cached copy if the LDAP query fails.
    $self->{_cache_lookup} = $cached;

    my $ttl    = $self->cache_ttl;
    my $cutoff = $self->Now() - $ttl;

    return unless ($cached->cached_at > $cutoff);

    #warn "Cached LDAP user is fresh";
    return $cached;
}

sub cache_ttl {
    my $self = shift;
    return DateTime::Duration->new( seconds => $self->ldap_config->ttl );
}

sub ResolveId {
    my $class = shift;
    my $p = shift;

    # in LDAP, any of these fields *could* be considered a unique identifier
    # for the User.  They all have to be unique in LDAP, but they're all also
    # subject to change; a user _could_ have their DN or e-mail changed.
    my @possible_ldap_identifiers
        = qw(driver_unique_id driver_username email_address);

    # some of the fields are also case IN-sensitive
    my %case_insensitive_identifier
        = map { $_ => 1 } qw(driver_username email_address);

    foreach my $field (@possible_ldap_identifiers) {
        my $sql = $case_insensitive_identifier{$field}
            ?  qq{SELECT user_id FROM users WHERE driver_key=? AND LOWER($field) = LOWER(?)}
            :  qq{SELECT user_id FROM users WHERE driver_key=? AND $field = ?};
        my $user_id = sql_singlevalue( $sql, $p->{driver_key}, $p->{$field} );
        return $user_id if $user_id;
    }

    # nope, couldn't find the user.
    return;
}

sub _vivify {
    my ($self, $proto_user) = @_;

    $proto_user->{driver_key} ||= $self->driver_key;

    # NOTE: *always* use the driver_unique_id to update LDAP user records

    $proto_user->{driver_username} = delete $proto_user->{username};
    $proto_user->{cached_at} = 'now'; # auto-set to 'now'
    $proto_user->{password} = '*no-password*';

    my $user_id = $self->ResolveId($proto_user);

    if ($user_id) {
        # update cache
        $proto_user->{user_id} = $user_id;
        $self->UpdateUserRecord($proto_user);
    }
    else {
        # will add a user_id to $proto_user:
        $self->NewUserRecord($proto_user);
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
    require Socialtext::User;
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
that happen to exist in an LDAP data store.  Copies of retrieved users are stored in the "users" table, creating a "long-term cache" of LDAP user information (with the exception of passwords and authentication).  See L<GetUser($key, $val)> for details.

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

=item B<ldap()>

Returns the C<Socialtext::LDAP> for this factory.

=item B<connect()>

The same as C<ldap()>, but ensures that it is connected.

=item B<ldap_config()>

Returns the C<Socialtext::LDAP::Config> for this factory.

=item B<attr_map()>

Returns the mapping of Socialtext user attributes (as they appear in the DB)
to their respective LDAP representations.

This B<is> different than the mapping returned by 
C<< Socialtext::LDAP::Config->attr_map() >> in that this mapping is
specifically targetted towards the underlying database representation of the
user attributes.

=item B<cache_ttl()>

Returns a C<DateTime::Duration> object representing the TTL for this Factory's
LDAP data.

=item B<ResolveId(\%params)>

Attempts to resolve the C<user_id> for the User represented by the given
C<\%params>.

For LDAP Users, we do an extended lookup to see if we can find the User by any
one (or more) of:

=over

=item * driver_unique_id (their dn)

=item * driver_username

=item * email_address

=back

If any one of these match and can be found, we can be confident that we've
found a matching User (we're still limiting ourselves to B<just> Users from
this LDAP factory instance, so we're not doing cross-factory resolution).

If the LDAP administrator re-uses somebodies username or e-mail address for a
completely different User we'll mismatch, but that's the risk we take.

=item B<GetUser($key, $val)>

Searches for the specified user in the LDAP data store and returns a new
C<Socialtext::User::LDAP> Homunculus object representing that user if it
exists.  

Long-term caching of LDAP users is implemented by storing user
records in the "users" database table.

The long-term cache is checked before connecting to the LDAP server..  If a
user is not found in the cache, or the cached copy has expired, the user is
retrieved from the LDAP server.  If the retrieval is successful, the details
of that user are stored in the long-term cache.

If the cached copy has expired, and the LDAP server is unreachable, the cached copy is used.

If a user has been used on this system, but is no longer present in the LDAP directory, a C<Socialtext::User::Deleted> Homunculus is returned.

User lookups can be performed by I<one> of:

=over

=item * user_id => $user_id

=item * driver_unique_id => $driver_unique_id

=item * username => $username

=item * email_address => $email_address

=back

=item B<lookup($key, $val)>

Looks up a user in the LDAP data store and returns a hash-ref of data on that
user.

Lookups can be performed using the same criteria as listed for C<GetUser()>
above.

The long-term cache is B<not> consulted when using this method.

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
C<< Socialtext::User->FormattedEmail() >>.

=back

The long-term cache is B<not> consulted when using this method.

=back

=head1 AUTHOR

Socialtext, Inc.  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2008 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
