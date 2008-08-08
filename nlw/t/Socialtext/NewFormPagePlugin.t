#!perl
# @COPYRIGHT@

use strict;
use warnings;

use mocked 'Apache';
use Test::Socialtext;
fixtures( 'admin' );

use Socialtext::Build qw( get_build_setting );

plan skip_all => q{Doesn't run under Socialtext Open} if get_build_setting( 'socialtext-open' );

my @tests = (
    [ "{new_form_page generic The Name of The Link}" =>
      qr{\Q<a class="new_form_page_link" href="index.cgi?action=new_form_page;form_id=generic">The Name of The Link</a>} ],
);

plan tests => 9;

my $hub = new_hub('admin');
my $viewer = $hub->viewer;

# check wafl handling
{
    # XXX \n needed to insure wafl is seen
    my $result = $viewer->text_to_html( $tests[0]->[0] . "\n");
    like( $result, $tests[0]->[1], $tests[0]->[0] );
}

# check form presentation
{
    CGI->initialize_globals;
    $ENV{GATEWAY_INTERFACE} = 1;
    $ENV{REQUEST_METHOD} = 'GET';
    $ENV{QUERY_STRING} = 'action=new_form_page;form_id=generic';

    my $new_form_page = $hub->new_form_page->new_form_page;
    like( $new_form_page, qr{<form.*action="index.cgi"},
          "page includes form w/new_form_page_process action" );
    like( $new_form_page, qr{<input.*type="text".*name="first_name"},
          "page includes form w/first_name input" );
    like( $new_form_page, qr{<input.*type="text".*name="last_name"},
          "page includes form w/first_name input" );
    like( $new_form_page, qr{<input.*type="text".*name="email_address"},
          "page includes form w/first_name input" );
    like( $new_form_page, qr{<input.*type="hidden".*name="action".*value="new_form_page_process"},
          "page includes hidden action input" );
}

# check form input handling
{
    CGI->initialize_globals;
    $hub->rest(undef);
    $ENV{GATEWAY_INTERFACE} = 1;
    $ENV{REQUEST_METHOD} = 'GET';
    $ENV{QUERY_STRING} = 'action=new_form_page_process;form_id=generic;first_name=Basil;last_name=Hogwart;email_address=devnull7@socialtext.com';

    my $process = $hub->new_form_page->new_form_page_process;
    is( '', $process, 'returns empty string' );
    $hub->headers->print;
    my %headers = $hub->rest->header;
    like( $headers{-Location}, qr{\Q?basil_hogwart},
        'redirects to basil_hogwart' );
}

# check page content
{
    my $page = $hub->pages->new_from_name('Basil Hogwart');
    like( $page->content, qr{devnull7\@socialtext\.com},
        'page content contains email address' );
}
