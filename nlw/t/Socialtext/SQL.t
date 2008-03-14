#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Socialtext::SQL qw( sql_convert_to_boolean sql_convert_from_boolean );
use Test::Socialtext tests => 5;

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
