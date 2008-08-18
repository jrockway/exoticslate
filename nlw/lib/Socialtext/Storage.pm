package Socialtext::Storage;
# @COPYRIGHT@
use strict;
use YAML;
use Socialtext::SQL qw( sql_execute sql_singlevalue);
use Carp qw(croak);

sub Search {
    my ($class, %terms) = @_;
    die "Terms required" unless %terms;

    my @keys = keys %terms;
    s/;// for @keys;

    my @selects;
    for my $i (0 .. $#keys) {
        my $key = $keys[$i];
        push @selects, "
            (SELECT class, value AS $key
             FROM storage
             WHERE key = ? AND value = ?
            ) AS select_$key
        ";
        push @selects, "JOIN" unless $i == $#keys;
        push @selects, "USING(class)" if $i;
    }

    my $all_keys = join ", ", @keys;
    my $all_selects = join "\n", @selects;
    my $sql = "SELECT class, $all_keys FROM $all_selects";

    my @binding = map { $_ => $terms{$_} } @keys;
    my $sth = sql_execute($sql, @binding);
    my $res = $sth->fetchall_arrayref;
    return unless @$res;
    if (@$res > 1) {
        warn "$class: returned more than one result for query ($sql), ("
            . join(', ', @binding) . ")";
    }
    return $class->new($res->[0][0]);
}

sub new {
    my ($class, $id, $user_id) = @_;
    croak "id required" unless $id;
    my $self = {
        id => $id,
        user_id => $user_id || 0,
    };
    bless $self, $class;
    $self->load_data;
    return $self;
}

sub id {
    my $self = shift;
    return $self->{id};
}

sub load_data {
    my $self = shift;
    $self->{_cache} = {};
}

sub get {
    my ($self,$key) = @_;
    croak 'key is required' unless $key;
    return $self->{_cache}{$key} if exists $self->{_cache}{$key};
    my $sth = sql_execute('
        SELECT value, datatype
          FROM storage
          WHERE class=? AND key=?
    ', $self->{id}, $key);

    my $res = $sth->fetchall_arrayref;
    return $self->{_cache}{$key} = undef unless @$res;
    my ($val, $type) = @{$res->[0]};
    $val = YAML::Load($val) if $type ne 'STRING';
    return $self->{_cache}{$key} = $val;
}

sub preload {
    my ($self,@keys) = @_;
    croak 'key is required' unless @keys;

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
    $self->{_cache}{$_} ||= undef for @keys;
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
