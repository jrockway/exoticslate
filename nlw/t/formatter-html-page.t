#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 6;
fixtures('admin');
use Socialtext::Encode;

my $hub = new_hub('admin');

{
    my $page = $hub->pages->new_from_name('Formatter Test for html-page wafl');

    my $attachment =
        $hub->attachments->new_attachment( page_id => $page->id,
                                       filename => 'html-page-wafl.html',
                                     );
    $attachment->save('t/attachments/html-page-wafl.html');
    $attachment->store( user => $hub->current_user );

    $page->metadata->Subject('Formatter Test for html-page wafl');
    $page->metadata->update( user => $hub->current_user );
    $page->content('foo');
    $page->store( user => $hub->current_user );

    my @tests =
        ( [ "{html-page html-page-wafl.html}\n" =>
            qr{\Qhref="/admin/index.cgi/html-page-wafl.html?action=attachments_download\E},
            qr{id=[\d-]+\Q;as_page=1\E},
          ],
          [ "{html-page no-such-page.html}\n" =>
            qr{\Qno-such-page.html\E},
            qr{(?!href)},
          ],
        );

    run_tests( $page, $_ ) for @tests;
}

{
    my $page = $hub->pages->new_from_name('Another html-page wafl test page');

    $page->metadata->Subject('Another html-page wafl test page');
    $page->metadata->update( user => $hub->current_user );
    $page->content('foo');
    $page->store( user => $hub->current_user );

    my @tests =
        ( [ "{html-page [Formatter Test for html-page wafl] html-page-wafl.html}\n" =>
            qr{\Qhref="/admin/index.cgi/html-page-wafl.html?action=attachments_download\E},
            qr{id=[\d-]+\Q;as_page=1\E},
          ],
        );

    run_tests( $page, $_ ) for @tests;
}

sub run_tests {
    my ($page, $tests) = @_;

    my $text = shift @$tests;
    $page->content($text);
    # XXX without this the existence of the attachment to the page
    # is not correct, and the test fails, so there appears to be
    # an issue with a hidden dependency on current
    $page->hub->pages->current($page);

    my $html = $page->to_html;

    for my $re (@$tests) {
        my $name = $text;
        chomp $name;

        $name .= " =~ $re";

        like( $html, $re, $name );
    }
}
