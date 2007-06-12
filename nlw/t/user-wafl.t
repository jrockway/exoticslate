#!perl -w
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 1;
fixtures( 'admin_no_pages' );
use Socialtext::Pages;

filters {
    wiki => 'format',
};

my $hub = new_hub('admin');
my $viewer = $hub->viewer;

# for user wafl
Socialtext::Page->new(hub => $hub)->create(
    title => 'devnull1@socialtext.com',
    content => 'hi',
    creator => $hub->current_user,
);

run_like wiki => 'match';

sub format {
    $viewer->text_to_html(shift)
}

__DATA__
=== User wafl gives the goods
--- wiki
By {user devnull1@socialtext.com}
--- match
/index.cgi\?devnull1_socialtext.com/
