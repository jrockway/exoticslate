#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 29;
fixtures( 'admin' );

=head1 DESCRIPTION

Test that backlinks are correctly created and removed
as pages are created and deleted.

=cut

my $path = 't/tmp/root/plugin/admin/backlinks';
my $singapore = join '', map { chr($_) } 26032, 21152, 22369;

my $hub = new_hub('admin');
my $backlinks = $hub->backlinks;
my $pages = $hub->pages;

# check the preference that allows backlinks to be shown
my $user = Socialtext::User->create(
    username      => 'john@doe.com',
    email_address => 'john@doe.com',
    password      => 'whatever',
);
$hub->current_user($user);

my $page_one = Socialtext::Page->new(hub => $hub)->create(
    title => 'page one',
    content => "Hello\n{fake-wafl} this is page one to [page two]\nyou" .
               "\n\n{other fake-wafl} Hello [mr chips] and [the son] " .
               "how are\n" .
               "{include [page three]}\n\n" .
               "{include foobar [page three]}\n\n",

    creator => $user,
);

my $page_two = Socialtext::Page->new(hub => $hub)->create(
    title => 'page two',
    content => "Hello\nthis is page two to [page one]\nyou\n\nGoobye " .
               "[$singapore]\n",
    creator => $user,
);

my $page_three = Socialtext::Page->new(hub => $hub)->create(
    title => 'page three',
    content => "Hello\nthis is page three\n\nGoobye ",
    creator => $user,
);

my $page_four = Socialtext::Page->new(hub => $hub)->create(
    title => 'page four',
    content => "Hello\nthis is page links to [page five]\n",
    creator => $user,
);

my $page_five = Socialtext::Page->new(hub => $hub)->create(
    title => 'page five',
    content => qq!Hello\nthis page links to "super page"[page four]\n! .
    "{link: newworkspace [page four]}"
    ,
    creator => $user,
);

my $page_six = Socialtext::Page->new(hub => $hub)->create(
    title => 'page six',
    content => "Hello\nthis page links to page five [page five]\n",
    creator => $user,
);


# Test _get_backlink_page_ids_for_page
{
    my @link_ids = $backlinks->_get_backlink_page_ids_for_page($page_one);
    is scalar(@link_ids), 1, 'page one should only have one page that links to it';
    @link_ids = $backlinks->_get_backlink_page_ids_for_page($page_two);
    is scalar(@link_ids), 1, 'page two should only have one page that links to it';;
    @link_ids = $backlinks->_get_backlink_page_ids_for_page($page_four);
    is scalar(@link_ids), 1, 'page four should have two pages that links to it';;
    @link_ids = $backlinks->_get_backlink_page_ids_for_page($page_five);
    is scalar(@link_ids), 2, 'page five should have two pages that links to it';;
}

# Test _get_frontlink_page_ids_for_page
TEST_FRONTLINK_IDS: {
    my @link_ids = $backlinks->_get_frontlink_page_ids_for_page($page_one);
    is scalar(@link_ids), 4,
        'page one should have four pages that it links to';
    @link_ids = $backlinks->_get_frontlink_page_ids_for_page($page_two);
    is scalar(@link_ids), 2,
        'page two should have two page that it links to';
    @link_ids = $backlinks->_get_frontlink_page_ids_for_page($page_four);
    is scalar(@link_ids), 1,
        'page four should have one page that it links to';
    @link_ids = $backlinks->_get_frontlink_page_ids_for_page($page_five);
    is scalar(@link_ids), 1,
        'page five should have one page that it links to';
}

TEST_FRONTLINK_PAGES: {
    check_frontlinks($page_one, ['page three', 'page two'], ['mr_chips', 'the_son']);
    check_frontlinks($page_two, ['page one']);
    check_frontlinks($page_three, []);
    check_frontlinks($page_four, ['page five']);
    check_frontlinks($page_five, ['page four']);
    check_frontlinks($page_six, ['page five']);
}

{
    # this should be four: three freelinks and one local inclusion.
    # but not include foobar inclusion
    check_backlinks($page_one, $page_two, 4);
    check_backlinks($page_two, $page_one, 2);
    check_backlinks($pages->new_from_name($singapore), $page_two, 0);
    check_backlinks($pages->new_from_name('page three'), $page_one, 0);

    $page_two->delete( user => $user );
    check_backlinks($page_two, undef, 0);

    $page_one->delete( user => $user );
    check_backlinks($page_one, undef, 0);
}

# from, to, count of links from from
sub check_backlinks {
    my $page = shift;
    my $top_backlink = shift;
    my $count = shift;

    my $links = $backlinks->all_backlinks_for_page($page);

    if ($top_backlink) {
        is($links->[0]{page_uri}, $top_backlink->uri, 'correct top link');
        is($links->[0]{page_title}, $top_backlink->title,
            'correct title in link');
    }

    my $glob_path = $path . '/' . $page->id . '____*';
    my @files = glob $glob_path;
    is(scalar(@files), $count, "expect $count links in the files");
}

sub check_frontlinks {
    my $page = shift;
    my $titles = shift;
    my $incipients = shift;

    my @pages = sort { $a->title cmp $b->title }
        $backlinks->all_frontlink_pages_for_page($page);
    is_deeply(
        [map {$_->title } @pages], $titles,
        $page->title . " has the right front links"
    );

    if ($incipients) {
        use YAML;
        my @pages = sort { $a->id cmp $b->id }
            $backlinks->all_frontlink_pages_for_page($page, 1);
        is_deeply(
            [map {$_->id } @pages], $incipients,
            $page->title . " has the right incipient front links"
        );
    }

}

