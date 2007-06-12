#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 9;
fixtures( 'admin_no_pages' );
use Storable qw(dclone);

my $singapore = join '', map { chr($_) } 26032, 21152, 22369;
my @categories = (
    ['one'],
    ['one', 'two'],
    ['one', 'two', $singapore],
);
my $content =<<EOF;

^^^ Hello

This link fest

* "link one"<http://foo.example.com/>
* "link two"<http://bar.example.com/>
* "link three"<http://baz.example.com/>
* http://bun.example.com/

And this done

EOF

my $dup_cat = dclone(\@categories);

{
    my $hub = new_hub('admin');
    my $pages = $hub->pages;
    my $display = $hub->display;

    my $count = 0;
    # XXX do this to keep recent changes out of the list of cats
    for my $tag_list (@categories) {
        my $page = $pages->new_from_name('link test ' . $count);
        $page->content($content);
        $page->metadata->Category($tag_list);
        $page->metadata->update( user => $hub->current_user );
        $page->store( user => $hub->current_user );
        $count++;
    }
}

{
    my $hub = new_hub('admin');
    $hub->pages;
    $hub->display;
    my $pages = $hub->pages;
    my $display = $hub->display;

    my $count = 0;
    for my $tag_list (@$dup_cat) {
        my $page = $pages->new_from_name('link test ' . $count);
        $page->load;
        $page->load_metadata;
        my $cat = $page->metadata->Category;
        my @sorted = $page->categories_sorted;
        $hub->pages->current($page);
        my $result = $display->display;

        like($result, qr/<h3 id="hello">Hello/, 'headline is correct');


        foreach my $tag (@$tag_list) {
          my $etag = Socialtext::Base->uri_escape($tag);
          like($result,
          qr|{"count":\d+,"tag":"$tag"}|,
            "tag present");
        }
        $count++;
    }
}
