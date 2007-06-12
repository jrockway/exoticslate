#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext;
fixtures( 'admin_no_pages' );

filters { regexps => [qw'lines chomp make_regexps'] };
plan tests => 1 * (map { ($_->regexps) } blocks);

my $hub = new_hub('admin');
my $viewer = $hub->viewer;

run {
    my $test = shift;
    return if $test->target;
    perform_test($test);
};

$hub->current_workspace->update( external_links_open_new_window => 0 );
run {
    my $test = shift;
    return unless $test->target;
    perform_test($test);
};

sub perform_test {
    my $test = shift;
    my $text = $test->text;
    my $result = $viewer->text_to_html("$text\n");

    for my $re ($test->regexps) {
        like( $result, $re, "$text =~ $re");
    }
}

sub make_regexps { map { eval } @_ }

__DATA__

===
--- text: http://foo.example.com/
--- regexps
qr{\Qtitle="(external link)"\E}
qr{\Qtarget="_blank"\E}
qr{\Qhref="http://foo.example.com/"\E}

===
--- text: https://bar.example.com/
--- regexps
qr{\Qtitle="(external link)"\E}
qr{\Qtarget="_blank"\E}
qr{\Qhref="https://bar.example.com/"\E}

===
--- text: ftp://ftp.example.com/
--- regexps
qr{\Qtitle="(external link)"\E}
qr{\Qtarget="_blank"\E}
qr{\Qhref="ftp://ftp.example.com/"\E}

===
--- text: irc://irc.example.com
--- regexps
qr{\Qtitle="(start irc session)"\E}
qr{\Qhref="irc://irc.example.com"\E}

===
--- text: file://server/filename.txt
--- regexps
qr{\Qtitle="(external link)"\E}
qr{\Qhref="file://server/filename.txt"\E}

===
--- text: http://foo.example.com/path/page.html
--- regexps
qr{\Qtitle="(external link)"\E}
qr{\Qtarget="_blank"\E}
qr{\Qhref="http://foo.example.com/path/page.html"\E}

===
--- text: http://foo.example.com/path/image.png
--- regexps
qr{\Qsrc="http://foo.example.com/path/image.png"\E}

===
--- text: http:path/image.png
--- regexps
qr{\Qsrc="path/image.png"\E},

===
--- text: *"hello"<http://example.com/thing.html>*
--- regexps
qr{\Qhref="http://example.com/thing.html"\E}
qr{\Q<strong><a target\E}
qr{\Qhello<!--\E}
qr{\Q--></a></strong>\E}

===
--- text: *"hello"<http:index.cgi?ass_page>*
--- regexps
qr{\Qhref="index.cgi?ass_page"\E}
qr{\Q<strong><span class="nlw_phrase"><a\E}
qr{\Q<!-- wiki: "hello"<http:index.cgi?ass_page> --></span></strong>\E}

===
--- text: "hello"<http:index.cgi?ass_page>
--- regexps
qr{\Qhref="index.cgi?ass_page"\E}
qr{\Qhello</a>\E}

===
--- target: 1
--- text: http://foo.example.com/
--- regexps
qr{\Qtitle="(external link)"\E}
qr{<a\s+title}
qr{\Qhref="http://foo.example.com/"\E}

===
--- target: 1
--- text: https://bar.example.com/
--- regexps
qr{\Qtitle="(external link)"\E}
qr{<a\s+title}
qr{\Qhref="https://bar.example.com/"\E}

===
--- target: 1
--- text: ftp://ftp.example.com/
--- regexps
qr{\Qtitle="(external link)"\E}
qr{<a\s+title}
qr{\Qhref="ftp://ftp.example.com/"\E}

