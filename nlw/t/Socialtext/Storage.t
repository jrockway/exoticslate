#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More qw(no_plan);

my $tempid = 'TESTING';

use Socialtext::AppConfig;

for my $sub (qw(YAML PSQL)) {
    use_ok "Socialtext::Storage::$sub";

    INIT_SET: {
        my $storage = "Socialtext::Storage::$sub"->new($tempid);
        $storage->purge;
        is $storage->get('test_var'), undef, 'test_var is undefined';
        $storage->set('test_var', 'myvalue');
        $storage->set('test_var2', 'myvalue2');
    }

    INIT_GET: {
        my $storage = "Socialtext::Storage::$sub"->new($tempid);
        ok $storage->exists('test_var'), 'test_var exists';
        ok !$storage->exists('test_var4'), "test_var4 doesn't exists";
        is $storage->get('test_var'), 'myvalue';
        is $storage->get('test_var2'), 'myvalue2';
    }

    UPDATE: {
        my $storage = "Socialtext::Storage::$sub"->new($tempid);
        $storage->set('test_var', 'my_other_value');
        $storage->load_data;
        is $storage->get('test_var'), 'my_other_value';
        $storage->set('test_var', 'myvalue');
    }

    NOEXIST: {
        my $storage = "Socialtext::Storage::$sub"->new($tempid);
        eval { $storage->get("ISHOULDN'TEXIST") };
        ok !$@, "Finding something that doesn't exist doesn't die";
    }

    SETSAVE: {
        my $storage = "Socialtext::Storage::$sub"->new($tempid);
        is $storage->get('other_var'), undef;
        is $storage->get('test_var'), 'myvalue';
        is $storage->get('test_var2'), 'myvalue2';
        $storage->set('test_var3', 'myvalue3');
    }

    SET_IS_PERSISTENT: {
        my $storage = "Socialtext::Storage::$sub"->new($tempid);
        ok $storage->exists('test_var3'), "test_var3 exists";
        is $storage->get('test_var3'), 'myvalue3';
    }

    KEYS: {
        my $storage = "Socialtext::Storage::$sub"->new($tempid);
        is_deeply [sort $storage->keys], [qw(test_var test_var2 test_var3)];
    }

    COMPLEX_DATATYPES_SET: {
        my $storage = "Socialtext::Storage::$sub"->new($tempid);
        $storage->set('test_array', [qw(an array)]);
        $storage->set('test_hash', {a => 'cool', hash => 'variable'});
    }

    COMPLEX_DATATYPES_GET: {
        my $storage = "Socialtext::Storage::$sub"->new($tempid);
        is_deeply $storage->get('test_array'), [qw(an array)];
        is_deeply $storage->get('test_hash'), {a => 'cool', hash => 'variable'};
    }

    EMPTY_VAL_SET: {
        my $storage = "Socialtext::Storage::$sub"->new($tempid);
        $storage->set('empty', '');
    }
    EMPTY_VAL_GET: {
        my $storage = "Socialtext::Storage::$sub"->new($tempid);
        ok $storage->exists('empty');
        is $storage->get('empty'), '';
    }
}
