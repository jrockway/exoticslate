#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::More;

BEGIN {
    if (! $ENV{ST_BENCHMARK_TEST}) {
        plan skip_all => "Skipping benchmark tests - set \$ST_BENCHMARK_TEST=1 to run them";
        exit;
    }
}

use DateTime;
use DateTime::Duration;

use Socialtext::Account;
use Socialtext::User;
use Socialtext::UserId;
use Socialtext::UserMetadata;
use Socialtext::User::Default;

use Test::Socialtext tests => 1;
fixtures('rdbms_clean');

my $num = 10000;

sub timer {
    my ( $class, $method, $num, $offset, %params ) = @_;

    my $start = DateTime->now();
    warn "# $class -> $method x $num, starting: $start\n";

    for my $i (1 .. $num) {
        my $computed_index = $i + $offset;
        my %transformed_params;
        my ( $key, $val );
        while (($key, $val) = each %params) {
            $val =~ s/\$i/$computed_index/;
            $transformed_params{$key} = $val;
        }
        $class->$method( %transformed_params );
    }

    my $stop = DateTime->now() - $start;
    warn "# $class -> $method x $num, took ", $stop->delta_minutes,
        " minutes, ", $stop->delta_seconds, " seconds\n";
}

sub time_batch_create {
    my ( $class, $num, $offset, %params ) = @_;

    timer( $class, 'create', $num, $offset, %params );
}

sub time_batch_instantiate {
    my ( $class, $num, $offset, %params ) = @_;

    timer( $class, 'new', $num, $offset, %params );
}

sub suite {
    my ( $class, $num, $offset, $new_params, $create_params ) = @_;
    time_batch_create( $class, $num, $offset, @$new_params, @$create_params );
    time_batch_instantiate( $class, $num, $offset, @$new_params );
}

suite( 'Socialtext::Account', 10000, 0, [ name => "Account\$i" ] );
suite(
    'Socialtext::User',
    10000, 0,
    [ username => "user\$i" ],
    [
        email_address      => "loser\$i\@socialtext.com",
        first_name         => "Loser \$i",
        last_name          => "O'Loser",
        password           => "123456",
        created_by_user_id => 4,
    ]
);
suite( 'Socialtext::Role', 10000, 15, [ name => "role\$i" ],
    [ used_as_default => 0 ]
);
suite( 'Socialtext::Permission', 10000, 15, [ name => "permission\$i" ], [] );

is(1, 1, "Stupid test.");
1;
