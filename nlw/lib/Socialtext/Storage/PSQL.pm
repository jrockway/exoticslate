package Socialtext::Storage::PSQL;
# @COPYRIGHT@
use strict;
use base 'Socialtext::Storage';
use YAML;
use Socialtext::SQL qw( sql_execute sql_singlevalue);
use Carp qw(croak);

sub load_data {
    my $self = shift;
    eval { sql_execute('SELECT COUNT(datatype) FROM "Storage"') };
    if ($@) {
        eval {
            sql_execute('
                CREATE TABLE "Storage" (
                    class    VARCHAR(128),
                    key      VARCHAR(128),
                    value    TEXT
                )
            ');
        };
        sql_execute('
            ALTER TABLE "Storage"
                ADD COLUMN datatype VARCHAR(10)
        ');
    }
    $self->{_cache} = {};
}

sub get {
    my ($self,$key) = @_;
    croak 'key is required' unless $key;
    return $self->{_cache}{$key} if $self->{_cache}{$key};
    my $sth = sql_execute('
        SELECT value, datatype
          FROM "Storage"
          WHERE class=? AND key=?
    ', $self->{id}, $key);

    my $res = $sth->fetchall_arrayref;
    return unless @$res;
    my ($val, $type) = @{$res->[0]};
    $val = YAML::Load($val) if $type ne 'STRING';
    return $self->{_cache}{$key} = $val;
}

sub set {
    my ($self,$key,$val) = @_;
    croak 'key is required' unless $key;
    my $type = ref $val || 'STRING';

    my $exists = $self->exists($key);

    $self->{_cache}{$key} = $val;
    $val = YAML::Dump($val) if $type ne 'STRING';

    if ($exists) {
        sql_execute('
            UPDATE "Storage"
              SET value=?, datatype=?
              WHERE class=? AND key=?
        ', $val, $type, $self->{id}, $key);
    }
    else {
        sql_execute('
            INSERT INTO "Storage"
              VALUES (?,?,?,?)
        ', $self->{id}, $key, $val, $type);
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
