#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 17;

BEGIN {
    use_ok( 'Socialtext::MultiCursor' );
}

my @food_stuffs = qw(lambs sloths carps anchovies orangutans
    breakfast_cereals fruit_bats);
my @cheeses = qw(red_leicester tilsit);
my $mc_from_array = Socialtext::MultiCursor->new(
    iterables => [\@food_stuffs]);

is_deeply(
    [ $mc_from_array->all ],
    [ 'lambs', 'sloths', 'carps', 'anchovies', 'orangutans', 'breakfast_cereals', 'fruit_bats' ],
    'All entries accounted for.',
);

is( $mc_from_array->next, 'lambs', 'Next entry is \'lambs\'.' );
is( $mc_from_array->next, 'sloths', 'Next entry is \'sloths\'.' );
ok( $mc_from_array->reset, 'MultiCursor resets properly.' );
is( $mc_from_array->next, 'lambs', 'Next entry is \'lambs\' again.' );
ok( $mc_from_array->reset, 'Resetting.' );

my $mc_from_mc = Socialtext::MultiCursor->new( iterables => [$mc_from_array] );

is( $mc_from_mc->next, 'lambs', 'Next entry is \'lambs\'.' );
is( $mc_from_mc->count, 7, '7 entries in the MultiCursor.' );
ok( $mc_from_mc->reset, 'Resetting.' );

my $mc_from_multiple = Socialtext::MultiCursor->new(
    iterables => [\@cheeses, \@food_stuffs],
);

is( $mc_from_multiple->next, 'red_leicester', 'Next from first source.' );
is( $mc_from_multiple->next, 'tilsit', 'Next from first source.' );
is( $mc_from_multiple->next, 'lambs', 'Next is from second source.' );
is( $mc_from_multiple->count, 9, '9 entries between two sources.' );
ok( $mc_from_multiple->reset, 'Resetting.' );

my $applied_mc = Socialtext::MultiCursor->new(
    iterables => [$mc_from_multiple],
    apply     => sub { uc shift }
);

is( $applied_mc->next, 'RED_LEICESTER', 'Next has been upcased.' );
is_deeply(
    [ $applied_mc->all ],
    [ 'RED_LEICESTER', 'TILSIT', 'LAMBS', 'SLOTHS', 'CARPS', 'ANCHOVIES', 'ORANGUTANS', 'BREAKFAST_CEREALS', 'FRUIT_BATS' ],
    'All elements have been applied properly.'
);
