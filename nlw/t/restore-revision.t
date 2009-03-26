#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 24;
fixtures( 'admin' );
use Readonly;

my $hub = new_hub('admin');
isa_ok( $hub, 'Socialtext::Hub' ) or die;

my $pages = $hub->pages;
isa_ok( $pages, 'Socialtext::Pages' ) or die;

{
    Readonly my $TITLE => 'William Morris';
    Readonly my $CREED => <<END_OF_CREED;
Have nothing in your houses that you do not know to be useful or
believe to be beautiful.
END_OF_CREED
    Readonly my $RANT  => <<END_OF_RANT;
In literature, they try to avoid saying the same word twice.  He could
have just as easily said, "Have nothing in your houses that you do not
believe to be useful or know to be beautiful."  You take things too
literally, and you can quote me on that.
--- Contributed by ingus
END_OF_RANT

    # The recent changes test at the end will sometimes fail unless
    # we have this sleep. This is because the recent changes index
    # contains the Date metadata field as the data, not the
    # modified time of the index.txt link. We confilict with
    # Admin Wiki in that index unless we wait. Not using the date=>
    # because we are already in a sleep mode.
    sleep( 1 );

    my $page = Socialtext::Page->new( hub => $hub )->create(
        title   => $TITLE,
        content => $CREED,
        creator => $hub->current_user,
    );
    isa_ok( $page, "Socialtext::Page" );
    is $page->revision_count, 1, 'Fresh page has exactly 1 revision id.';
    is $page->metadata->Revision, 1, 'Fresh metadata is Revision 1';

    my $original_revision_id = $page->revision_id;

    # Replace the creed with the rant.
    $page->content($RANT);
    $page->metadata->update( user => $hub->current_user );
    $page->store( user => $hub->current_user );

    # Should have two revisions now
    my @revision_ids = $page->all_revision_ids;
    is scalar @revision_ids, 2,
        '$page->store adds a revision id.';

    $page = $pages->current( $pages->new_from_name($TITLE) );
    isa_ok( $page, "Socialtext::Page" );

    is_deeply [ $page->all_revision_ids ], \@revision_ids,
        'new_from_name produces the same revision ids';
    is $page->metadata->Revision, 2, 'metadata is Revision 2';

    $page->revision_id($original_revision_id);
    is $page->revision_id, $original_revision_id, 'revision_id setter works.';
    is $page->metadata->Revision, 2, 'metadata is still Revision 2 before load';

    $page->load;
    is $page->revision_id, $original_revision_id,
        'load does not molest revision_id.';
    is $page->metadata->Revision, 1, 'metadata is back to  Revision 1';
    is_deeply [ $page->all_revision_ids ], \@revision_ids,
        'loading old content does not molest the revision id list.';

    $page->store( user => $hub->current_user );
    @revision_ids = $page->all_revision_ids;
    is scalar @revision_ids, 3,
        '$page->store adds a revision id.';
    is $page->metadata->Revision, 1, 'After load/store, Revision no. is 1.';
    ok $page->revision_id != $original_revision_id,
        '$page->store updates revision_id';
    is $page->content, $CREED, 'After load/store, page content is restored.';

    # restore a revision and check its version:
    my $orig = $page->original_revision;
    is $orig->revision_id, $original_revision_id,
        '$page->original_revision returns correct revision_id.';
    ok $orig ne $page,
        q{When there are multiple revisions, $page->original_revision returns an object distinct from $page.};

    my $changes = $hub->recent_changes->get_recent_changes;
    my $row     = $changes->{rows}->[0];
    use YAML; warn Dump($changes->{rows});
    is( $row->{Subject}, $TITLE, "most recently modified page is $TITLE" );
    is($row->{Revision}, 1, 'recent_changes revision number is restored.');
    is($row->{revision_count}, 3, 'recent_changes revision count is correct.');
}

package MockPage;
sub revision_id { }
sub load        { }
sub store       { }
sub restore_revision { }
sub uri         {'correct_place_to_redirect_to'}

package main;
{
    my $redirected_to = 'nothing';
    no warnings qw(once redefine);
    local *Socialtext::Pages::current = sub { bless {}, 'MockPage' };
    local *Socialtext::RevisionPlugin::redirect = sub { $redirected_to = $_[1] };

    $hub->revision->revision_restore;    # note that this just uses cgi arg =(
    is $redirected_to, MockPage::uri(),
        'Socialtext::RevisionPlugin::revision_restore redirects to the current page URI.';
}
