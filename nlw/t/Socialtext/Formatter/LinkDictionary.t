#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 31;
fixtures( 'admin_no_pages' );

use Socialtext::Formatter::LinkDictionary;

my %DEFAULTLINKS = (
    free => 'index.cgi?%{page_uri}',
    interwiki => '/%{workspace}/index.cgi?%{page_uri}%{section}',
    search_query => '/%{workspace}/index.cgi?action=search;search_term=%{search_term}',
    category_query => '/%{workspace}/index.cgi?action=weblog_display;category=%{category}',
    recent_changes_query => '/%{workspace}/index.cgi?action=recent_changes',
    special_http => '%{arg1}',
    category => '/%{workspace}/index.cgi?action=category_display;category=%{category}',
    weblog => '/%{workspace}/index.cgi?action=weblog_display;category=%{category}',
    file => '/data/workspaces/%{workspace}/attachments/%{page_uri}:%{id}/original/%{filename}',
    image => '/data/workspaces/%{workspace}/attachments/%{page_uri}:%{id}/%{size}/%{filename}',
);

my $hub = new_hub('admin');

# confirm the default object is correctly created
{
    my $ld = Socialtext::Formatter::LinkDictionary->new();
    confirm_defaults($ld);
}

# make some changes from the default, a custom link dictionary
{
    my $ld = Socialtext::Formatter::LinkDictionary->new();

    my $custom_free = '/page/%{workspace}/%{page_uri}';

    $ld->free($custom_free);

    is( $ld->free, $custom_free,
        'store and retrieve of customization match' );
    confirm_defaults($ld, 'free');
}

# make a lite dictionary and check it's freelink
{
    use_ok("Socialtext::Formatter::LiteLinkDictionary");
    my $ld = Socialtext::Formatter::LiteLinkDictionary->new();

    is( $ld->free, '%{page_uri}', 'free link is %{page_uri}' );
    is( $ld->interwiki, '/lite/page/%{workspace}/%{page_uri}%{section}',
        'interwiki link is peachy' );
    is( $ld->file, $DEFAULTLINKS{file},
        'file link is parent default' );
}

# check an absolute
{
    use_ok("Socialtext::Formatter::AbsoluteLinkDictionary");
    my $ld = Socialtext::Formatter::AbsoluteLinkDictionary->new();

    is( $ld->free, '%{url_prefix}' . $DEFAULTLINKS{interwiki},
        'free link is absolute via interwiki' );
    is( $ld->interwiki, '%{url_prefix}' . $DEFAULTLINKS{interwiki},
        'interwiki link (automethod) is absolute' );
}

# format something with the default dictionary
{
    my $text = "\n[hello moto]\n{link admin [junkie] farter}\n";

    my $html = $hub->viewer->text_to_html($text);

    like( $html, qr{"index.cgi\?hello%20moto"},
        'free link formats as expected' );
    like( $html, qr{"/admin/index.cgi\?junkie#farter"},
        'interwiki link formats as expected' );
}

# format something with the lite dictionary
{
    my $text = "\n[hello moto]\n{link admin [junkie] farter}\n";

    my $viewer = $hub->viewer;
    $viewer->link_dictionary(Socialtext::Formatter::LiteLinkDictionary->new());

    my $html = $viewer->text_to_html($text);

    like( $html, qr{"hello%20moto"},
        'free link formats as expected' );
    like( $html, qr{"/lite/page/admin/junkie#farter"},
        'interwiki link formats as expected' );
}

sub confirm_defaults {
    my $ld = shift;
    my %skips = map {$_ => 1} @_;
    foreach my $link_type (keys(%DEFAULTLINKS)) {
        next if $skips{$link_type};
        is( $ld->$link_type, $DEFAULTLINKS{$link_type},
            "$link_type yields $DEFAULTLINKS{$link_type}" );
    }
}
