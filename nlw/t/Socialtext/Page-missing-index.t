#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 1;
fixtures( 'admin', 'destructive' );

use Socialtext::File;

my $hub = new_hub('admin');

my $file = Socialtext::File::catfile(
    Socialtext::Paths::page_data_directory('admin'),
    'quick_start',
    'index.txt'
);

unlink $file or die "Cannot unlink $file: $!";

# This test makes sure that we don't spit out a warning when a page
# data directory is missing its index.txt symlink.
my $warnings = '';
local $SIG{__WARN__} = sub { $warnings .= $_ for @_ };

my @ids = $hub->pages->all_ids_newest_first();
is( $warnings, '', 'no warnings from calling all_ids_newest_first()' );
