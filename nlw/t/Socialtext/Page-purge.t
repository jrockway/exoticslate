#!perl
# @COPYRIGHT@
use warnings;
use strict;
use Test::Socialtext tests => 5;
fixtures( 'admin', 'destructive' );
use Socialtext::Jobs;


my $hub = new_hub('admin');
my $page = $hub->pages->new_from_name('Start here');

{
    my @pages = $hub->category->get_pages_for_category('Welcome');
    my $is_in_help = grep { $_->title eq 'Start here' } @pages;
    ok( $is_in_help, '"Start here" is in Welcome category before purge()' );
}

{
    Socialtext::Jobs->clear_jobs();

    my $attachment_path =
        join '/', $page->hub->attachments->plugin_directory, $page->id;
    my $page_path = $page->directory_path;
    my $file_path = $page->file_path;

    $page->purge();

    ok( ! -d $attachment_path,
        'Attachment dir for page is gone after purge()' );
    ok( ! -d $page_path,
        'Data dir for page is gone after purge()' );

    my @pages = $hub->category->get_pages_for_category('Welcome');
    my $is_in_help = grep { $_->title eq 'Start here' } @pages;
    ok( !$is_in_help,
        '"Start here" is not in Welcome category before purge()' );

    my $queue_dir = Socialtext::Paths::change_event_queue_dir();
    opendir my $dh, $queue_dir
        or die "Cannot read $queue_dir: $!";

    my @events = grep { -l } map { "$queue_dir/$_" } readdir $dh;

    is ( scalar @events, 0,
        'No change event was recorded when calling purge()' );
}
