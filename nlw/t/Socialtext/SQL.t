#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Exception;
use Test::Socialtext tests => 35;

fixtures( 'db' );

BEGIN {
    use_ok 'Socialtext::Schema';
    use_ok 'Socialtext::SQL', qw( 
        get_dbh disconnect_dbh invalidate_dbh
        :exec :bool :txn :time
    );
}

lives_ok {
    disconnect_dbh()
} "can disconnect okay";
lives_ok {
    get_dbh()
} "can connect okay";

sql_execute: {
    my $sth;
    sql_execute('CREATE TABLE foo (name text)');
    $sth = sql_execute('SELECT * FROM foo');
    is_deeply $sth->fetchall_arrayref, [], 'no data found in table';

    invalidate_dbh();

    sql_execute(q{INSERT INTO foo VALUES ('luke')});
    $sth = sql_execute('SELECT * FROM foo');
    is_deeply $sth->fetchall_arrayref, [ ['luke' ] ], 'data found in table';

    { 
        ##local $SIG{__WARN__} = sub { };
        sql_execute('DROP TABLE foo');
        eval { sql_execute('SELECT * FROM foo') };
        ok $@, "table was deleted";
    }
}

Transactions: {
    my @warnings;
    lives_ok {
        local $SIG{__WARN__} = sub {push @warnings, $_};
        sql_rollback();
    } "rollback outside of transaction is not fatal";
    ok @warnings == 1, "got a warning";
    @warnings = ();

    lives_ok {
        local $SIG{__WARN__} = sub {push @warnings, $_};
        sql_commit();
    } "outside of transaction is not fatal";
    ok @warnings == 1, "got a warning";
    @warnings = ();

    ok get_dbh->{AutoCommit}, "AutoCommit it turned on";
    ok !sql_in_transaction(), 'not in transaction';

    lives_ok { sql_begin_work() } 'begin';

    ok !get_dbh->{AutoCommit}, "AutoCommit becomes disabled";
    ok sql_in_transaction(), 'in transaction';

    lives_ok { sql_rollback() } 'rollback';

    ok get_dbh->{AutoCommit}, "AutoCommit it turned on again";
    ok !sql_in_transaction(), 'not in transaction';

    my $tt = q{
        CREATE TEMPORARY TABLE goes_away (id bigint NOT NULL) ON COMMIT DROP
    };

    dies_ok {
        sql_execute($tt);
        sql_singlevalue("SELECT * FROM goes_away LIMIT 1");
    } "should die because no txn started";

    sql_begin_work();
    lives_ok {
        sql_execute($tt);
        sql_singlevalue("SELECT * FROM goes_away LIMIT 1");
    } "should be fine because txn in progress";
    sql_commit();

    dies_ok {
        sql_begin_work();
        sql_begin_work();
    } "can't nest transactions";
    sql_rollback();

    sql_begin_work();
    sql_execute($tt);

    lives_ok {
        local $SIG{__WARN__} = sub {push @warnings, join('',@_)};
        invalidate_dbh();
    } "invalidating while in txn is not fatal";
    ok @warnings == 2, "get a set of warnings";
    @warnings = ();
    ok !sql_in_transaction(), 'not in transaction';
}

sql_execute_array: {
    my $sth;
    sql_execute('CREATE TABLE bar (name text, value text)');

    sql_execute_array(
        q{INSERT INTO bar VALUES (?,?)},
        {},
        [ map { "name $_" } 0 .. 10 ],
        [ map { "value $_" } 0 .. 10 ],
    );
    $sth = sql_execute('SELECT * FROM bar');
    is_deeply $sth->fetchall_arrayref, [ 
        map { ["name $_", "value $_"] } 0 .. 10 
    ], 'data found in table';

    { 
        local $SIG{__WARN__} = sub { };
        sql_execute('DROP TABLE bar');
        eval { sql_execute('SELECT * FROM bar') };
        ok $@, "table was deleted";
    }
}

sql_execute_array_errors: {
    eval { sql_execute('DROP TABLE parent (id integer)'); };
    sql_begin_work();

    sql_execute('CREATE TEMPORARY TABLE parent (id integer) ON COMMIT DROP');
    sql_execute(
        'ALTER TABLE parent ADD CONSTRAINT parent_id_pk PRIMARY KEY (id)'
    );
    sql_execute('CREATE TEMPORARY TABLE child (id integer, dad integer) ON COMMIT DROP');
    sql_execute('
        ALTER TABLE child ADD CONSTRAINT parent_id_fk
         FOREIGN KEY (dad) REFERENCES parent(id)
    ');

    sql_execute_array('INSERT INTO parent values (?)', {}, [1,2,3,4,5]);
    my $dbh = get_dbh;
    $dbh->pg_savepoint('foo');
    dies_ok {
        sql_execute_array(
            'INSERT INTO child values (?, ?)', {},
            [1,2,3,4,5], [1,2,3,7,5],
        );
    } "foreign key constraint violation";
    like $@, qr{violates foreign key constraint "parent_id_fk"},
         "Eror is propogated";
    $dbh->pg_rollback_to('foo');

    lives_ok {
        sql_execute("SELECT * FROM parent");
    } "savepoint worked okay";

    sql_rollback();
}

SQL_CONVERT_TO_BOOLEAN: {
    my $value = 0;
    my $sql_value = sql_convert_to_boolean($value,'t');
    is($sql_value, 'f', 'false if f');

    $value = 1;
    $sql_value = sql_convert_to_boolean($value,'f');
    is($sql_value, 't', 'true if t');

    $value = undef;
    $sql_value = sql_convert_to_boolean($value,'t');
    is($sql_value, 't', 'default works');
}

SQL_CONVERT_FROM_BOOLEAN: {
    my $sql_value = 't';
    my $value = sql_convert_from_boolean($sql_value);
    is($value, 1, 'true is 1');

    $sql_value = 'f';
    $value = sql_convert_from_boolean($sql_value);
    is($value, 0, 'false is 0');
}
