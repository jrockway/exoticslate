#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More qw(no_plan);

my $tempid = 'TESTING';

use Socialtext::AppConfig;

for my $sub (qw(YAML PSQL)) {
    use_ok "Socialtext::Storage::$sub";
    INIT: {
        my $storage = "Socialtext::Storage::$sub"->new($tempid);
        $storage->purge;
        is $storage->get('test_var'), undef;
        $storage->set('test_var', 'myvalue');
        $storage->set('test_var2', 'myvalue2');
        is $storage->get('test_var'), 'myvalue';
        is $storage->get('test_var2'), 'myvalue2';
        $storage->save;
    }

    SETSAVE: {
        my $storage = "Socialtext::Storage::$sub"->new($tempid);
        is $storage->get('other_var'), undef;
        is $storage->get('test_var'), 'myvalue';
        is $storage->get('test_var2'), 'myvalue2';
        $storage->set('test_var3', 'myvalue3');
    }

    NOSAVE: {
        my $storage = "Socialtext::Storage::$sub"->new($tempid);
        is $storage->get('test_var3'), undef; # didn's save
    }

    KEYS: {
        my $storage = "Socialtext::Storage::$sub"->new($tempid);
        is_deeply [sort $storage->keys], [qw(test_var test_var2)];
    }

    COMPLEX_DATATYPES: {
        my $storage = "Socialtext::Storage::$sub"->new($tempid);
        $storage->set('test_array', [qw(an array)]);
        $storage->set('test_hash', {a => 'cool', hash => 'variable'});
        is_deeply $storage->get('test_array'), [qw(an array)];
        is_deeply $storage->get('test_hash'), {a => 'cool', hash => 'variable'};
        $storage->save;
    }
}
