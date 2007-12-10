# @COPYRIGHT@
package Socialtext::User::LDAP;

use strict;
use warnings;

use Net::LDAP;
use Encode;
use Class::Field 'field';
use YAML;
use Socialtext::AppConfig;
use Socialtext::User;

our $VERSION = '0.01';

field 'user_id';
field 'username';
field 'email_address';
field 'first_name';
field 'last_name';

sub driver_name { 'LDAP' }
sub has_valid_password { 1 }

my $yaml_file = Socialtext::AppConfig->config_dir . '/ldap.yaml';
my $yaml = YAML::LoadFile($yaml_file);

sub new {
    my ( $class, $key, $val ) = @_;

    my $self = bless {}, $class;

    my $filter_key = $yaml->{attr_map}{$key};
    return undef unless $filter_key;
    return undef unless $val;

    # With stock LDAP, the best way to find a record via dn is by making that
    # the base of the search, and restricting the scope to just that object
    my @search_args = ( $filter_key =~ m/^(dn|distinguishedName)$/ )
        ? ( base => $val, scope => 'base', filter => '(objectClass=*)')
        : ( base => $yaml->{base}, scope => 'sub', filter => "($filter_key=$val)" );

    my $ldap = $class->_bind_ldap;

    return undef unless $ldap;

    my $res = $ldap->search( @search_args )->shift_entry();

    return $res ? $self->_init_from_result($res) : undef;
}

sub _bind_ldap {
    my $class = shift;
    my ($bind_user, $bind_password) = @_;
    $bind_user     = $yaml->{bind_user}     unless defined $bind_user;
    $bind_password = $yaml->{bind_password} unless defined $bind_password;
    my @bind_args =
        ( $bind_user && $bind_password )
      ? ( $bind_user, password => $bind_password ) # authenticated bind
      : (); # anonymous bind

    my $ldap = Net::LDAP->new( $yaml->{host}, port => $yaml->{port} );
    my $result = $ldap->bind(@bind_args);

    if ($result->code) {
        warn "# Socialtext::User::LDAP - ", $result->error, "\n";
        return;
    }

    return $ldap;
}

sub _init_from_result {
    my ( $self, $result ) = @_;

    # This seems necessary to account for the weirdness of the 'dn'
    # "attribute"
    for my $attr
        qw( user_id username password first_name last_name email_address ) {
        my $ldap_attr = $yaml->{attr_map}{$attr};
        $self->$attr( $result->get_value($ldap_attr) );

        # dn isn't an attribute carried by the record, it's a method of the
        # Net::LDAP::Entry object
        if ( $ldap_attr =~ m/^(dn|distinguishedName)$/ ) {
            $self->$attr( $result->dn );
        }
    }

    return $self;

    # But I like the simplicity of the following :^( --zbir

    # map { $self->$_( $result->get_value( $yaml->{attr_map}{$_} ) ) }
    #     qw( user_id username password first_name last_name email_address );
    # return $self;
}

sub password {
    return '*no-password*';
}

sub password_is_correct {
    my $self = shift;
    my $pw   = shift;

    return 0 unless $pw; # No empty passwords

    # we probably won't have $self->password to check against, need to
    # re-submit a query with our unique user_id and the $pw passed in - if it
    # comes back, the password was good, if nothing comes back, it was
    # invalid.
    return ($self->_bind_ldap($self->user_id, $pw)) ? 1 : 0;
}

sub Search {
    my $class = shift;
    my $term = shift;
    my @users;

    my $filter = join ' ',
                 map { "($_=*$term*)" }
                 map { $yaml->{attr_map}{$_} }
                 qw/username email_address first_name last_name/;

    my $ldap = $class->_bind_ldap;

    return @users unless $ldap;

    my $res = $ldap->search(
        base   => $yaml->{base},
        scope  => 'sub',
        filter => "(|$filter)",
        attrs  => $yaml->{attr_map}{user_id},
    );

    for my $e ( $res->entries ) {
        my $email = $e->get_value( $yaml->{attr_map}{email_address} );
        my $name  = Socialtext::User->FormattedEmail(
            $e->get_value( $yaml->{attr_map}{first_name} ),
            $e->get_value( $yaml->{attr_map}{last_name} ),
            $email,
        );
        push @users,
            {
                driver_name    => $class->driver_name,
                email_address  => $email,
                name_and_email => $name,
            };
    }
    return @users;
}

1;

__END__

=head1 NAME

Socialtext::User::LDAP - A Socialtext LDAP User Factory

=head1 SYNOPSIS

  use Socialtext::User::LDAP;

  my $user = Socialtext::User::LDAP->new( user_id => $user_id );

  my $user = Socialtext::User::LDAP->new( username => $username );

  my $user = Socialtext::User::LDAP->new( email_address => $email_address );

=head1 DESCRIPTION

This class provides methods for dealing with data from an LDAP
server. Each object represents a single record from LDAP.

=head1 METHODS

=head2 Socialtext::User::LDAP->new(PARAMS)

Looks for an existing user matching PARAMS and returns a
C<Socialtext::User::LDAP> object representing that user if it exists.

PARAMS can be I<one> of:

=over 4

=item * user_id => $user_id

=item * username => $username

=item * email_address => $email_address

=back

=head2 $user->user_id()

=head2 $user->username()

=head2 $user->email_address()

=head2 $user->first_name()

=head2 $user->last_name()

=head2 $user->driver_name()

Returns the corresponding attribute for the user.

=head2 $user->password_is_correct($pw)

Returns a boolean indicating whether or not the given password is
correct.

=head2 $user->has_valid_password()

Returns true if the user has a valid password.

We test this by attempting to rebind to the LDAP server using the
credentials provided.

=head2 Socialtext::User::LDAP->Search( 'foo' )

Search for user records where 'foo' is found in any of username, email
address, first name, or last name. Returns a list of hashes containing
three key-value pairs:

=over 4

=item driver_key => Socialtext::User::LDAP->driver_key

=item email_address => the email_address of the record

=item name_and_email => the result of passing in the record's
first_name, last_name, and email_address to
Socialtext::User->name_and_email()

=back

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005 Socialtext, Inc., All Rights Reserved.

=cut
