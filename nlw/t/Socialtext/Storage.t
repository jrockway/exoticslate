#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More qw(no_plan);

my $tempid = 'TESTING';

use Socialtext::AppConfig;

use_ok 'Socialtext::Storage';

INIT_SET: {
    my $storage = Socialtext::Storage->new($tempid);
    $storage->purge;
    is $storage->get('test_var'), undef, 'unset value is undefined';
    $storage->set('test_var', 'myvalue');
    $storage->set('test_var2', 'myvalue2');
}

PRELOAD: {
    my $storage = Socialtext::Storage->new($tempid);
    $storage->preload(qw(test_var test_var2));
    is_deeply $storage->{_cache}, {
        test_var => 'myvalue',
        test_var2 => 'myvalue2',
    }, "preload";
}

INIT_GET: {
    my $storage = Socialtext::Storage->new($tempid);
    ok $storage->exists('test_var'), 'test_var exists';
    ok !$storage->exists('test_var4'), "test_var4 doesn't exists";
    is $storage->get('test_var'), 'myvalue';
    is $storage->get('test_var2'), 'myvalue2';
}

UPDATE: {
    my $storage = Socialtext::Storage->new($tempid);
    $storage->set('test_var', 'my_other_value');
    is $storage->get('test_var'), 'my_other_value';
    $storage->set('test_var', 'myvalue');
}

NOEXIST: {
    my $storage = Socialtext::Storage->new($tempid);
    eval { $storage->get("ISHOULDN'TEXIST") };
    ok !$@, "Finding something that doesn't exist doesn't die";
}

SETSAVE: {
    my $storage = Socialtext::Storage->new($tempid);
    is $storage->get('other_var'), undef;
    is $storage->get('test_var'), 'myvalue';
    is $storage->get('test_var2'), 'myvalue2';
    $storage->set('test_var3', 'myvalue3');
}

SET_IS_PERSISTENT: {
    my $storage = Socialtext::Storage->new($tempid);
    ok $storage->exists('test_var3'), "test_var3 exists";
    is $storage->get('test_var3'), 'myvalue3', 'get returns set value';
}

KEYS: {
    my $storage = Socialtext::Storage->new($tempid);
    is_deeply [sort $storage->keys],
              [qw(test_var test_var2 test_var3)],
              'keys';
}

COMPLEX_DATATYPES_GET: {
    my $setter = Socialtext::Storage->new($tempid);
    $setter->set('test_array', [qw(an array)]);
    $setter->set('test_hash', {a => 'cool', hash => 'variable'});

    my $getter = Socialtext::Storage->new($tempid);
    is_deeply $getter->get('test_array'),
              [qw(an array)],
              'complex array';
    is_deeply $getter->get('test_hash'),
              { a => 'cool', hash => 'variable' },
              'complex hash';
}

EMPTY_VAL: {
    my $setter = Socialtext::Storage->new($tempid);
    $setter->set('empty', '');

    my $getter = Socialtext::Storage->new($tempid);
    ok $getter->exists('empty'), 'exists on empty string is true';
    is $getter->get('empty'), '', 'get on empty string is empty string';
}

SEARCH: {
    my $s1 = Socialtext::Storage->new('id1');
    $s1->set('term_1', 'value_id1_1');
    $s1->set('term_2', 'value_id1_2');

    my $s2 = Socialtext::Storage->new('id2');
    $s2->set('term_1', 'value_id2_1');
    $s2->set('term_2', 'value_id2_2');

    is Socialtext::Storage->Search(
        term_1 => 'value_id1_1',
        term_2 => 'value_id1_2',
    )->id, 'id1', 'Searching for id1 works';

    is Socialtext::Storage->Search(
        term_1 => 'value_id2_1',
        term_2 => 'value_id2_2',
    )->id, 'id2', 'Searching for id2 works';
}
                                
