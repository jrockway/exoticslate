# @COPYRIGHT@
package Test::Socialtext::Search;
use strict;
use warnings;

use File::Path;
use File::Spec;
use Test::More;
use Test::Socialtext ();
use Test::Socialtext::Environment;
use Socialtext::Ceqlotron;
use Socialtext::Paths;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(init delete_page search_for_term
                 search_for_term_in_attach confirm_term_in_result
                 create_and_confirm_page turn_on_rampup
                 turn_off_rampup);

Socialtext::Ceqlotron::clean_queue_directory();
our $hub;

sub hub {
    $hub = Test::Socialtext::Environment->instance()
        ->hub_for_workspace('admin');
    return $hub;
}

sub delete_page {
    my $title = shift;
    my $page = $hub->pages->new_from_name($title);
    $page->delete( user => $hub->current_user );
}

sub search_for_term {
    my $term = shift;
    my $negation = shift;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    Test::Socialtext::ceqlotron_run_synchronously();

    my $search = $hub->search;
    $search->search_for_term(search_term => $term);
    my $set = $search->result_set;

    if ($negation) {
        ok( $set, 'we have results' );
        is_deeply(
            $set->{rows},
            [],
            "result set found no hits $term"
        );
    } else {
        ok( $set, 'we have results' );
        ok( $set->{hits} > 0, 'result set found hits' );
        confirm_term_in_result($hub, $term, $set->{rows}->[0]->{page_uri});
        like( $set->{rows}->[0]->{Date}, qr/\d+/,
            'date has some numbers in it');
        like( $set->{rows}->[0]->{DateLocal}, qr/\d+/,
            'date local has some numbers in it');
    }
}

# XXX refactor to remove the dreaded duplication
# XXX add actually looking inside the attachments to confirm
sub search_for_term_in_attach {
    my $term = shift;
    my $filename = shift;

    Test::Socialtext::ceqlotron_run_synchronously();

    my $search = $hub->search;
    $search->search_for_term(search_term => $term);
    my $set = $search->result_set;
    ok( $set->{hits} > 0, "have page hits via term $term");
    ok( grep($_->{is_attachment}, @{$set->{rows}}), "have attachments");
    is( $set->{rows}->[0]->{document_title}, $filename,
        "found right file: $filename");
}

sub confirm_term_in_result {
    my $hub = shift;
    my $term = shift;
    my $page_uri = shift;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    unless (defined $page_uri) {
        fail("subject, content or category contains correct term ($term)");
        return;
    }

    my $page = $hub->pages->new_from_name($page_uri);
    my $metadata = $page->metadata;
    my $subject = $metadata->Subject;
    my $content = $page->content;
    my $categories = $metadata->Category;
    $term =~ s/^category://;
    $term =~ s/^title://;
    $term =~ s/^=//;
    $term =~ s/^"//;
    $term =~ s/"$//;

    ok(
        ($subject =~ /$term/i or
        $content =~ /$term/i or
        grep(/\b$term\b/i, @$categories)),
        "subject, content or category contains correct term ($term)"
    );
}


sub create_and_confirm_page {
    my $title = shift;
    my $content = shift;
    my $categories = shift || [];

    # FIXME: $categories goes in as a reference to a
    # list. It can be here as [] and come out the other
    # side as ('Recent Changes') because there is
    # code down inside CategoryPlugin that is manipulates
    # the list ref
    Socialtext::Page->new(hub => $hub)->create(
        title => $title,
        content => "$content\n",
        categories => $categories,
        creator    => $hub->current_user,
    );

    {
        my $pages  = $hub->pages;
        my $page   = $pages->new_from_name($title);
        ok( $page->exists, 'a test page exists' );
        like( $page->content, qr{$content},
            'page content is correct');
        if (@$categories) {
            my $page_categories = $page->metadata->Category;
            foreach my $category (grep !/recent changes/i, @$categories) {
                ok((grep /\b$category\b/i, @$page_categories),
                    "page is in $category");
            }
        }
    }
}

sub turn_on_rampup {
    my $dir = 't/tmp/etc/socialtext/search';
    my $rampup_yaml = <<EOY;
---
version: 9999
index_type: combined
search_engine: kinosearch
directory_pattern: %system_plugin_directory%/woot
query_parser_method: _parse_query
hits_processor_method: _process_hits
key_generator: composite_key
field_spec:
    key:
        analyzed: 0

    title:
        stored: 0
        boost: 4

    tag:
        stored: 0
        boost: 2

    text:
        stored: 0

EOY

    open RAMPUP, ">" . File::Spec->catdir( $dir, "rampup.yaml" ) || die "I just can't! $!\n";
    print RAMPUP $rampup_yaml;
    close RAMPUP;
}

sub turn_off_rampup {
    unlink 't/tmp/etc/socialtext/search/rampup.yaml';
    #rmtree( File::Spec->catdir( Socialtext::Paths::system_plugin_directory, 'woot' ) );
}

1;
