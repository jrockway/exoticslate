package Socialtext::Storage::PSQL;
# @COPYRIGHT@
use strict;
use base 'Socialtext::Storage';
use YAML;
use Socialtext::SQL qw( sql_execute sql_singlevalue);
use Carp qw(croak);

sub load_data {
    my $self = shift;
    $self->{_cache} = {};
}

sub get {
    my ($self,@keys) = @_;
    croak 'key is required' unless @keys;

    if (@keys == grep { exists $self->{_cache}{$_} } @keys) {
        return $self->{_cache}{$keys[0]} if @keys == 1;
        return map { $self->{_cache}{$_} } @keys;
    }

    my $key_query = join ',', map { "?" } @keys;
    my $sth = sql_execute("
        SELECT key, value, datatype
          FROM storage
          WHERE class=? AND key IN ($key_query)
    ", $self->{id}, @keys);

    while (my $row = $sth->fetchrow_hashref) {
        $self->{_cache}{ $row->{key} } =
            $row->{datatype} eq 'STRING'
            ? $row->{value}
            : YAML::Load( $row->{value} );
    }
        
    return $self->{_cache}{$keys[0]} if @keys == 1;
    return grep { defined $_ } map { $self->{_cache}{$_} } @keys;
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
            UPDATE storage
              SET value=?, datatype=?
              WHERE class=? AND key=?
        ', $val, $type, $self->{id}, $key);
    }
    else {
        sql_execute('
            INSERT INTO storage
              VALUES (?,?,?,?,?)
        ', $self->{user_id}, $self->{id}, $key, $val, $type);
    }
}

sub delete {
    my ($self, $key) = @_;
    delete $self->{_cache}{$key};
    sql_execute(
        'DELETE FROM storage WHERE class=? AND key=?',
        $self->{id}, $key
    );
}

sub exists {
    my ($self,$key) = @_;
    croak 'key is required' unless $key;
    return 1 if defined $self->{_cache}{$key};
    return sql_singlevalue('
        SELECT COUNT(*)
          FROM storage
          WHERE class=? AND key=?
    ', $self->{id}, $key);
}

sub purge {
    my $self = shift;
    sql_execute(
        'DELETE FROM storage WHERE class=?',
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
        'SELECT key FROM storage WHERE class=?',
        $self->{id},
    );
    my $res = $sth->fetchall_arrayref;
    return map({ $_->[0] } @$res);
}

sub classes {
    my $self = shift;
    my $sth = sql_execute('
        SELECT distinct class
          FROM storage
          WHERE user_id=?
    ', $self->{user_id});
    my $res = $sth->fetchall_arrayref;
    return map({ $_->[0] } @$res);
}

1;
