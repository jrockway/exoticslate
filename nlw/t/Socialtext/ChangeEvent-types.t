#!perl
# @COPYRIGHT@
use warnings;
use strict;

use Test::Socialtext tests => 13;
fixtures( 'admin_with_extra_pages' );

BEGIN {
    use_ok( 'Socialtext::ChangeEvent' );
}

use File::Path;
use Socialtext::Ceqlotron 'foreach_event';
use Socialtext::ChangeEvent;
use Socialtext::Paths;
use Readonly;

Readonly my $WORKSPACE_NAME => 'admin';
Readonly my $PAGE_URI       => 'formattingtest';

{
    my $attachment
        = new_hub($WORKSPACE_NAME)->attachments->all( page_id => $PAGE_URI )
        ->[0];

    my $event = record_ok( $attachment, 'Socialtext::ChangeEvent::Attachment' );
    is(
        $event->workspace_name, $WORKSPACE_NAME,
        'Attachment workspace_name is correct.'
    );
    is( $event->page_uri, $PAGE_URI, 'Attachment page_uri is correct.' );
    is(
        $event->attachment_id, $attachment->id,
        'Attachment attachment_id is correct.'
    );
}

{
    my $event = record_ok(
        new_hub($WORKSPACE_NAME)->pages->new_from_name($PAGE_URI),
        'Socialtext::ChangeEvent::Page'
    );
    is(
        $event->workspace_name, $WORKSPACE_NAME,
        'Page workspace_name is correct.'
    );
    is( $event->page_uri, $PAGE_URI, 'Page page_uri is correct.' );
}

{
    my $event = record_ok(
        Socialtext::Workspace->new( name => $WORKSPACE_NAME ),
        'Socialtext::ChangeEvent::Workspace'
    );
    is(
        $event->workspace_name, $WORKSPACE_NAME,
        'Workspace workspace_name correct.'
    );
}

sub record_ok {
    my ( $item, $class ) = @_;
    my ( $event, $count );

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    Socialtext::Ceqlotron::clean_queue_directory;
    Socialtext::ChangeEvent->Record($item);
    foreach_event( sub {
        ++$count;
        $event = $_[0];
    } );

    is( $count, 1, "Record($item) creates only 1 event." );
    isa_ok( $event, $class );

    return $event;
}
