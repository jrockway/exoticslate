#!perl
# @COPYRIGHT@
BEGIN {
    $ENV{NLW_APPCONFIG} = 'search_factory_class=Socialtext::Search::KinoSearch::Factory';
}

use strict;
use warnings;

use Test::Socialtext tests => 17;
fixtures( 'admin_with_extra_pages' );
use Socialtext::Search::AbstractFactory;

use Readonly;
use Socialtext::User;

Readonly my $WORKSPACE_ID    => 'admin';
Readonly my $PAGE_URI        => 'start_here';
Readonly my $POSITIVE_TERM   => 'wOrKsPaCe';
Readonly my $NEGATIVE_TERM   => 'fnord';

Readonly my $ATTACHMENT_PAGE_URI => 'formattingtest';
Readonly my $ATTACHMENT_NAME     => 'Robot.txt';
Readonly my $ATTACHMENT_TERM     => 'deriv';

BEGIN {
    use_ok( "Socialtext::Search::KinoSearch::Searcher" );
}

my $hub      = new_hub('admin');
my $factory  = Socialtext::Search::AbstractFactory->GetFactory;
my $indexer  = $factory->create_indexer($WORKSPACE_ID);
my $searcher = $factory->create_searcher($WORKSPACE_ID);

isa_ok( $indexer, 'Socialtext::Search::KinoSearch::Indexer', 'indexer' );
isa_ok( $searcher, 'Socialtext::Search::KinoSearch::Searcher', 'searcher' );

search_ok( $POSITIVE_TERM, 0, 'at first' );
search_ok( $NEGATIVE_TERM, 0, 'at first' );

{
    $indexer->index_page($PAGE_URI);

    my ($hit) = search_ok( $POSITIVE_TERM, 1, "after indexing '$PAGE_URI'" );
    isa_ok( $hit, 'Socialtext::Search::PageHit', 'hit' );
    is( $hit->page_uri, $PAGE_URI, "hit found in '$PAGE_URI'" );
    search_ok( $NEGATIVE_TERM, 0, "after indexing '$PAGE_URI'" );
}

{
    $indexer->delete_page($PAGE_URI);

    search_ok( $POSITIVE_TERM, 0, "after deleting '$PAGE_URI'" );
    search_ok( $NEGATIVE_TERM, 0, "after deleting '$PAGE_URI'" );
}

attachments_ok();
exit;


# Tests the whole search/index/delete setup for attachments.
sub attachments_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    search_ok( $ATTACHMENT_TERM, 0, 'at first' );

    my $attachment;
    foreach my $candidate_attachment (
        @{$hub->attachments->all( page_id => $ATTACHMENT_PAGE_URI )} ) {

        # get the right one
        next unless $candidate_attachment->filename eq $ATTACHMENT_NAME;
        $attachment = $candidate_attachment;
        $indexer->index_attachment( $ATTACHMENT_PAGE_URI, $attachment->id );
    }

    my ($hit) = search_ok( $ATTACHMENT_TERM, 1, 'after indexing attachment');
    isa_ok( $hit, 'Socialtext::Search::AttachmentHit', 'hit' );

    is(
        $hit->page_uri,
        $ATTACHMENT_PAGE_URI,
        "hit attached to '$ATTACHMENT_PAGE_URI'"
    );

    is(
        $hit->attachment_id,
        $attachment->id,
        'hit attachment id is correct'
    );

    $indexer->delete_attachment( $ATTACHMENT_PAGE_URI, $attachment->id );

    search_ok( $ATTACHMENT_TERM, 0, 'after deleting attachment' );
}

sub search_ok {
    my ( $term, $expected_results, $condition ) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $searcher = $searcher;
    my @results = $searcher->search($term);

    is(
        scalar @results,
        $expected_results,
        "'$term' returns $expected_results hit(s) $condition"
    );

    return @results;
}
