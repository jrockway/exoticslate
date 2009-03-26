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

# REVIEW: Should include html and tt too, but I don't want to mess up any templates at this point.
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
    share/skin/common/javascript/Ajax-0.11
    share/skin/common/javascript/DOM.Ready-0.14
    share/skin/common/javascript/Subclass-0.10
    share/skin/common/javascript/Test-Base-0.12
    share/skin/common/javascript/Widget-Balloon-0.02
    share/skin/common/javascript/Widget.Lightbox-0.06
    share/skin/common/javascript/Widget.SortableTable-0.21
    share/skin/common/javascript/Wikiwyg-2007-07-17
    share/skin/common/javascript/YAML-0.11
    share/workspaces
    share/skin/js-test/common/plugins/socialcalc/submodule
    share/plugin/socialcalc/share/javascript/dbrick
    share/plugin/socialcalc/submodule
    share/skin/common/submodule
);
my %skip_paths = map { ($_,1) } @skip_paths;

my @skip_matching = (
    qr#test/common/plugins/socialcalc/share/javascript/SocialCalc#,
    qr#test/common/plugins/socialcalc/share/javascript/dBrick#,
    qr#share/skin/js-test/common/plugins/socialcalc/share/javascript/dbrick#,
    qr#share/plugin/socialcalc/share/javascript/SocialCalc#,
    qr#share/plugin/socialcalc/share/javascript/dBrick#
);

my @skip_files = qw(
    share/skin/st/javascript/test/run/bin/render-template
    share/skin/common/select/bin/gen_skins_js.pl
    share/skin/s2/javascript/test/run/bin/render-template
    dev-bin/bad-bot-does-not-follow-redirect
    lib/Socialtext/Widget_resource.pm
);
my %skip_files = map { ($_,1) } @skip_files;

my $dir = '.';

my $iter =
    File::Next::files( {
        descend_filter => sub {
            return if $_ eq '.svn';
            return if $skip_paths{$File::Next::dir};
            for (@skip_matching) {
                return if $File::Next::dir =~ $_;
            }
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
