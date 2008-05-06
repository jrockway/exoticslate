package Socialtext::Storage::PSQL;
# @COPYRIGHT@
use strict;
use base 'Socialtext::Storage';
use YAML;
use Socialtext::SQL qw( sql_execute sql_singlevalue);
use Carp qw(croak);

sub load_data {
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
    $self->{_cache} = {};
}

sub get {
    my ($self,$key) = @_;
    croak 'key is required' unless $key;
    return $self->{_cache}{$key} if $self->{_cache}{$key};
    my $val = sql_singlevalue('
        SELECT value
          FROM "Storage"
          WHERE class=? AND key=?
    ', $self->{id}, $key);
    return unless defined $val;
    return $self->{_cache}{$key} = YAML::Load($val . "\n");
}

sub set {
    my ($self,$key,$val) = @_;
    croak 'key is required' unless $key;
    my $yaml_val = YAML::Dump($val);

    if ($self->exists($key)) {
        $self->{_cache}{$key} = $val;
        my $sth = sql_execute('
            UPDATE "Storage"
              SET value=?
              WHERE class=? AND key=?
        ', $yaml_val, $self->{id}, $key);
    }
    else {
        $self->{_cache}{$key} = $val;
        my $a=sql_execute('
            INSERT INTO "Storage"
              VALUES (?,?,?)
        ', $self->{id}, $key, $yaml_val);
    }
}

sub delete {
    my ($self, $key) = @_;
    delete $self->{_cache}{$key};
    sql_execute(
        'DELETE FROM "Storage" WHERE class=? AND key=?',
        $self->{id}, $key
    );
}

sub exists {
    my ($self,$key) = @_;
    croak 'key is required' unless $key;
    return 1 if exists $self->{_cache}{$key};
    return sql_singlevalue('
        SELECT COUNT(*)
          FROM "Storage"
          WHERE class=? AND key=?
    ', $self->{id}, $key);
}

sub purge {
    my $self = shift;
    sql_execute(
        'DELETE FROM "Storage" WHERE class=?',
        $self->{id},
    );
    $self->{_cache} = {};
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
    return map({ $_->[0] } @$res);
}


1;
