#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use YAML;
use Graphics::ColorNames;

our %RGB;
tie %RGB, 'Graphics::ColorNames', 'X';

my $data = YAML::LoadFile("Widgets.yaml");
my $widgets = [sort keys %{$data->{widget}}];

for my $widget_id (@$widgets) {
    my $color = $data->{widget}{$widget_id}{color} or next;
    my $rgb = $RGB{$color} or die "No RGB defined for '$color'\n";
    create_image($widget_id, $rgb);
}

# http://www.signgenerator.org/rss/
sub create_image {
    my ($widget_id, $rs_bg) = @_;

    my $url = eval join '', qw(
        "
        http://buy4cheap.brinkster.net/signs/rss/?
        ALLOW=4688028 &
        MAKE=true &
        LEFT_TEXT= &
        LS_COLOR=FFFFCC &
        LS_BACKGROUND=000000 &
        RIGHT_TEXT=$widget_id &
        RS_COLOR=FFFFFF &
        RS_BACKGROUND=$rs_bg &
        VBAR=30 &
        LEFTSIZE=8 &
        RIGHTSIZE=8 &
        FONT=album &
        R_UP=1 &
        L_UP=1 &
        R_LR=1 &
        L_LR=0
        "
    );

    my $output_file = "../images/wikiwyg_icons/widgets/${widget_id}.png";
    warn "Generating $output_file\n";
    system(qq{wget -q -O "$output_file" '$url'}) == 0
      or die "Failed...\n";
}
