#!perl
# @COPYRIGHT@
use strict;
use warnings FATAL => 'all';

use Test::More tests => 33;
use Test::Exception;
use mocked 'Socialtext::SQL', ':test';

use_ok 'Socialtext::SQL::Builder', ':all';

nextval: {
    sql_mock_result([42]);

    my $next = sql_nextval('somesequence');
    is $next, 42, "got expected nextval";
    sql_ok(
        sql => "SELECT nextval(?)",
        args => ['somesequence'],
        name => 'sql_nextval',
    );
}

update_invalid_calls: {
    dies_ok sub { sql_update('') };
    dies_ok sub { sql_update(undef) };
    dies_ok sub { sql_update('mytable') }, 'missing args';

    dies_ok sub { sql_update('mytable', undef, 'id') }, 'missing params';
    dies_ok sub { sql_update('mytable', {}, 'id') }, 'empty params';

    dies_ok sub { sql_update('mytable', {foo=>12}, 'id') }, 'missing key';
    dies_ok sub { sql_update('mytable', {foo=>undef}, 'foo') }, 'undef value';

    ok !@Socialtext::SQL::SQL, 'no sql got run';
}

update_works: {
    sql_update(
        'mytable_1',
        {
            foo  => 'bar',
            this => 'that',
            baz  => 'quxx',
        },
        'foo'
    );
    sql_ok(
        sql => q{UPDATE mytable_1 SET baz = ?, this = ? WHERE foo = ?},
        args => ['quxx', 'that', 'bar'],
        name => 'sql_update works',
    );
    ok !@Socialtext::SQL::SQL, 'no more sql';
}

insert_invalid_calls: {
    dies_ok sub { sql_insert('') };
    dies_ok sub { sql_insert(undef) };
    dies_ok sub { sql_insert('mytable') }, 'missing args';
    dies_ok sub { sql_insert('mytable', undef) }, 'missing params';
    dies_ok sub { sql_insert('mytable', {}) }, 'empty params';

    ok !@Socialtext::SQL::SQL, 'no sql got run';
}

insert_works: {
    sql_insert(
        'mytable_2',
        {
            foo2  => 'bar',
            this2 => 'that',
            baz2  => 'quxx',
        },
    );
    sql_ok(
        sql => q{INSERT INTO mytable_2 (baz2,foo2,this2) VALUES (?,?,?)},
        args => ['quxx', 'bar', 'that'],
        name => 'sql_insert works',
    );
    ok !@Socialtext::SQL::SQL, 'no more sql';
}

insert_many: {
    my $args = [ [qw/a b c/], [qw/d e f/], [qw/g h i/] ];
    sql_insert_many(
        'mytable_3',
        [ qw/foo bar baz/ ],
        $args,
    );
    sql_ok(
        sql => q{INSERT INTO mytable_3 (foo,bar,baz) VALUES (?,?,?)},
        args => $args,
        name => 'sql_insert_many works',
    );
    ok !@Socialtext::SQL::SQL, 'no more sql';
}

insert_many_fail: {
    dies_ok sub { sql_insert_many('') };
    dies_ok sub { sql_insert_many('table') };
    dies_ok sub { sql_insert_many('table', []) };
    dies_ok sub { sql_insert_many('table', [], []) };
    dies_ok sub { sql_insert_many('table', [1], []) };
    dies_ok sub { sql_insert_many('table', [], [1]) };
}
