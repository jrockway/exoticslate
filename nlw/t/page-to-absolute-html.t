#!perl
# @COPYRIGHT@

use warnings;
use strict;

use Test::Socialtext tests => 11;
fixtures( 'workspaces' );
my $hub = new_hub('admin');
isa_ok( $hub, 'Socialtext::Hub' );

my $title = 'Formatter Test for html-page wafl';

{
    my $page = Socialtext::Page->new(hub => $hub)->create(
        title => $title,
        content => <<"EOF",
This is the page.

This is the [help] wiki link.

{link public [welcome]}

{link foobar [welcome]}

{weblog help}

{category help}

http:base/images/docs/Browse-Collection_of_pages.png

EOF
        creator => $hub->current_user,
    );
    isa_ok( $page, 'Socialtext::Page' );

    $hub->pages->current($page);
    add_attachment($page->id, 'html-page-wafl.html');
    add_attachment($page->id, 'socialtext-logo-30.gif');

    my $server_root = qr{https?://[-\w\.]+\w+};

    my @tests = (
        [ "{file html-page-wafl.html}" =>
            qr{href="$server_root\Q/admin/index.cgi/html-page-wafl.html},
        ],
        [ "{image socialtext-logo-30.gif}" =>
            qr{src="$server_root\Q/admin/index.cgi/socialtext-logo-30.gif},
        ],
        [ "[help]" =>
            qr{href="$server_root\Q/admin/index.cgi?help},
        ],
        [ "{link public [welcome]}" =>
            qr{href="$server_root\Q/public/index.cgi?welcome},
        ],
        [ "{link foobar [welcome]}" =>
            qr{href="$server_root\Q/foobar/index.cgi?welcome},
        ],
        [ "{weblog help}" =>
            qr{href="$server_root\Q/admin/index.cgi?action=weblog},
        ],
        [ "{category help}" =>
            qr{href="$server_root\Q/admin/index.cgi?action=category},
        ],
        [ "http:base/images/docs/Browse-Collection_of_pages.png" =>
            qr{src="$server_root\Q/admin/base/images/docs/Browse-Collection_of_pages.png},
        ]
    );

    run_tests(\@tests);
}

sub add_attachment {
    my $id = shift;
    my $filename = shift;
    my $filepath = "t/attachments/$filename";

    open my $fh, '<', $filepath or die "$filepath: $!";
    $hub->attachments->create(
        filename => $filename,
        fh => $fh,
        embed => 1,
        creator => $hub->current_user,
    );

    return;
}

sub run_tests {
    my $tests = shift;

    my @noisy_decode_args;
    no warnings qw'redefine once';
    local *Socialtext::Encode::noisy_decode = sub {
        my %args = @_;
        push @noisy_decode_args, %args;
        $args{input};
    };

    my $page = $hub->pages->new_from_name($title);
    my $html = $page->to_absolute_html;

    ok @noisy_decode_args, 'noisy_decode should be called';

    foreach my $test (@$tests) {
        my $text = shift @$test;
        my $re = shift @$test;
        like( $html, $re, $text . " $re");
    }

    return;
}
