#!perl
# @COPYRIGHT@

# Tests that all source code has copyright, or the @COPYRIGHT@ macro, in it

use warnings;
use strict;

use Test::More;
use File::Slurp qw( read_file );

BEGIN {
    eval 'use File::Next 0.30';
    plan skip_all => 'This test requires File::Next' if $@;

    eval 'use App::Ack';
    plan skip_all => 'This test requires App::Ack' if $@;
}

# REVIEW: Should include html, mason and tt, too, but I don't want to mess up any templates at this point.
my @keeper_types = qw( perl javascript );
my %keeper_types = map { ($_,1) } @keeper_types;

# Data in these paths need not have copyright
my @skip_paths = qw(
    t/Socialtext/File/stringify_data
    t/attachments
    t/extra-pages
    t/test-data
    appliance-bin
    bench
);
my %skip_paths = map { ($_,1) } @skip_paths;

my @skip_files = qw(
    share/js-test/run/bin/render-template
    dev-bin/bad-bot-does-not-follow-redirect
);
my %skip_files = map { ($_,1) } @skip_files;

my $dir = '.';

my $iter =
    File::Next::files( {
        descend_filter => sub {
            return if $_ eq '.svn';
            return if $skip_paths{$File::Next::dir};
            return 1;
        },
        sort_files => 1,
    }, $dir );

my @checkers;
while ( my $filename = $iter->() ) {
    next if $skip_files{$filename};
    my @types = App::Ack::filetypes( $filename );
    my $keep = grep { exists $keeper_types{$_} } @types;

    push( @checkers, $filename ) if $keep;
}

plan tests => scalar @checkers;

for my $filename ( @checkers ) {
    my $text = read_file( $filename );
    my $has_copyright = ($text =~ /\@COPYRIGHT\@/) || ($text =~ /Copyright.+Socialtext/);
    ok( $has_copyright, $filename );
}
