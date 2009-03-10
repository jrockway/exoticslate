#!perl
# @COPYRIGHT@
# Tests that all perl code has use strict
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

my $iter =
    File::Next::files( {
        descend_filter => sub {
            return if $_ eq '.svn';
            return 1;
        },
        sort_files => 1,
    }, qw(lib dev-bin bin));

my @checkers;
while ( my $filename = $iter->() ) {
    my @types = App::Ack::filetypes( $filename );
    my $keep = grep { $_ eq 'perl' } @types;
    push( @checkers, $filename ) if $keep;
}

plan tests => scalar @checkers;

for my $filename ( @checkers ) {
    my $text = read_file( $filename );
    ok( $text =~ /^use strict;$/m, $filename );
}
