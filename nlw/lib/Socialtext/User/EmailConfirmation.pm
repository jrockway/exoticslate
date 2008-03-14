package Socialtext::User::EmailConfirmation;
# @COPYRIGHT@
use strict;
use warnings;
use Socialtext::SQL qw/sql_execute/;
use Socialtext::AppConfig;
use Digest::SHA1;
use DateTime;
use DateTime::Format::Pg;
use Carp qw/croak/;

sub new {
    my ($class, $user_id) = @_;
    croak 'new requires user_id!' unless defined $user_id;

    my $sth = sql_execute(<<EOSQL, $user_id);
SELECT * FROM "UserEmailConfirmation" WHERE user_id = ?
EOSQL

    my $self = $sth->fetchrow_hashref();
    return unless $self;
    bless $self, $class;
    return $self;
}

sub create_or_update {
    my $class = shift;
    my %p = @_;

    my $self = $class->new($p{user_id});
    if ($self) {
        return $self->_update(%p);
    }
    else {
        return $class->_create(%p);
    }
}

sub _create {
    my $class = shift;
    my %p = @_;

    my @vals = (
        $p{user_id},
        _generate_confirmation_hash($p{user_id}),
        _expiration_datetime(),
        $p{is_password_change} ? 'TRUE' : 'FALSE',
    );

    sql_execute(<<EOSQL, @vals);
INSERT INTO "UserEmailConfirmation" VALUES (?, ?, ?, ?)
EOSQL

    return $class->new($p{user_id});
}

sub _update {
    my $self = shift;
    my %p = @_;
    my $user_id = delete $p{user_id};

    my @vals = (_expiration_datetime(), $p{is_password_change});
    sql_execute(<<EOSQL, @vals, $user_id);
UPDATE "UserEmailConfirmation"
    SET expiration_datetime = ?, is_password_change = ?
    WHERE user_id = ?
EOSQL

    # Update object too
    $self->{expiration_datetime} = $vals[0];
    $self->{is_password_change}  = $vals[1];
    return $self;
}

sub id_from_hash {
    my $class = shift;
    my $hash  = shift;

    my $sth = sql_execute(
        'SELECT user_id FROM "UserEmailConfirmation" WHERE sha1_hash=?',
        $hash,
    );
    return $sth->fetchall_arrayref->[0][0];
}

sub hash               { shift->{sha1_hash} }
sub is_password_change { shift->{is_password_change} }

sub expiration_datetime { 
    my $self = shift;
    return DateTime::Format::Pg->parse_timestamptz( 
        $self->{expiration_datetime},
    );
}

sub has_expired {
    my $self = shift;
    return $self->expiration_datetime < DateTime->now();
}

sub delete {
    my $self = shift;
    sql_execute(<<EOSQL, $self->{user_id});
DELETE FROM "UserEmailConfirmation"
    WHERE user_id = ?
EOSQL
}

# Reuse existing hashes before making new ones.  This helps avoid issues like
# RT 20767, where future hashes were clobering older ones when a non-existant
# user was invited to multiple workspaces.
sub _generate_confirmation_hash {
    my $user_id = shift;
    return Digest::SHA1::sha1_base64(
        $user_id, time,
        Socialtext::AppConfig->MAC_secret
    );
}

sub _expiration_datetime {
    my $expires = DateTime->now->add( days => 14 );
    return DateTime::Format::Pg->format_timestamptz($expires);
}

1;
