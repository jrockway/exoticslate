package Socialtext::Storage::PSQL;
# @COPYRIGHT@
use strict;
use base 'Socialtext::Storage';
use Carp qw(croak);
use Socialtext::SQL qw( sql_execute sql_singlevalue);

sub new {
    my ($class, $id) = @_;
    croak "id required" unless $id;
    my $self = {
        id => $id,
    };
    bless $self, $class;
    $self->_create;
    return $self;
}

sub _create {
    my $self = shift;
    eval { sql_execute('SELECT COUNT(*) FROM "Storage"') };
    if ($@) {
        sql_execute('
            CREATE TABLE "Storage" (
                class VARCHAR(128),
                key   VARCHAR(128),
                value TEXT
            )
        ');
    }
}

sub get {
    my ($self,$key) = @_;
    return $self->{_cache}{$key} if $self->{_cache}{$key};
    my $sth = sql_execute(<<EOT, $self->{id}, $key);
SELECT value
  FROM "Storage"
  WHERE class=? AND key=?
EOT
    return $sth->fetchall_arrayref->[0][0];
}

sub set {
    my ($self,$key,$val) = @_;
    $self->{_cache}{$key} = $val;
    $self->{_modified}{$key} = 1;
}

sub save {
    my $self = shift;

    my %keys = map { $_ => 1 } $self->keys;
    my $mods = $self->{_modified};

    for my $key (keys %$mods) {
        my $val  = $self->{_cache}{$key};
        if ($keys{$key}) {
            sql_execute('
                UPDATE "Storage"
                  SET value=?
                  WHERE class=? AND key=?
            ', $val, $self->{id}, $key);
        }
        else {
            sql_execute('
                INSERT INTO "Storage"
                  VALUES (?,?,?)
            ', $self->{id}, $key, $val);
        }
    }
}

sub purge {
    my $self = shift;
    sql_execute(
        'DELETE FROM "Storage" WHERE class=?',
        $self->{id},
    );
}

sub remove {
    my $self = shift;
    $self->purge;
    # No need to do anything else here...
}

sub keys {
    my $self = shift;
    my $sth = sql_execute(
        'SELECT key FROM "Storage" WHERE class=?',
        $self->{id},
    );
    my $res = $sth->fetchall_arrayref;
    return map { $_->[0] } @$res;
}


1;
