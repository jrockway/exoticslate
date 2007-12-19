#!perl
# @COPYRIGHT@

use warnings;
use strict;

use Test::Socialtext tests => 39;
fixtures( 'admin', 'foobar' );

my $admin = new_hub('admin');
my $foobar = new_hub('foobar');

{
    my $page = $admin->pages->new_from_name('interwiki copy test in admin');
    $page->content('This is a test page for interwiki copy.');
    $page->store( user => $admin->current_user );

    my $same_page =
        $admin->pages->new_from_name('interwiki copy test in admin');
    my $new_page =
        $foobar->pages->new_from_name('interwiki copy test in foobar');

    my $return = $page->duplicate( $foobar->current_workspace, 'interwiki copy test in foobar' );
    ok( $return, 'duplication was successful' );
    ok( $same_page, 'original page was saved in admin workspace' );
    ok( length $same_page->content, 'original page has some content' );
    ok( $new_page, 'copied page exists in foobar workspace' );
    ok( length $new_page->content, 'new page has some content' );
    is( $new_page->content, $page->content,
        'copied page content is the same in both workspaces' );
}

{
    my $page_admin = $admin->pages->new_from_name('interwiki copy two');
    my $page_foobar = $foobar->pages->new_from_name('interwiki copy two');
    
    $page_admin->content('This page copy is supposed to fail');
    $page_admin->store( user => $admin->current_user );
    $page_foobar->content('This page copy is supposed to be clobbered');
    $page_foobar->store( user => $admin->current_user );

    my $return = $page_admin->duplicate( $foobar->current_workspace, 'interwiki copy two' );

    $page_admin = $admin->pages->new_from_name('interwiki copy two');
    $page_foobar = $foobar->pages->new_from_name('interwiki copy two');
    
    ok( $return == 0, 'copy denied, no flag');
    isnt( $page_admin->content, $page_foobar->content,
        'two pages are different as expected');
}

{
    my $page_admin =
        $admin->pages->new_from_name('interwiki copy three');
    my $page_foobar =
        $foobar->pages->new_from_name('interwiki copy three');

    $page_admin->content('This page copy is supposed to fail');
    $page_admin->store( user => $admin->current_user );
    $page_foobar->content('This page copy is supposed to be clobbered');
    $page_foobar->store( user => $admin->current_user );

    my $return = $page_admin->duplicate( $foobar->current_workspace, 'interwiki copy three',
        '', '', 'interwiki copy three' );

    $page_admin = $admin->pages->new_from_name('interwiki copy three');
    $page_foobar = $foobar->pages->new_from_name('interwiki copy three');
    
    ok( $return, 'copy succeeded, flag was right' );
    is( $page_admin->content, $page_foobar->content,
        'two pages are the same as expected' );
}

{
    my $page_admin =
        $admin->pages->new_from_name('interwiki copy four');
    my $page_foobar =
        $foobar->pages->new_from_name('interwiki copy four');

    $page_admin->content('This page copy is supposed to fail');
    $page_admin->store( user => $admin->current_user );
    $page_foobar->content('This page copy is supposed to be clobbered');
    $page_foobar->store( user => $admin->current_user );

    my $return = $page_admin->duplicate( $foobar->current_workspace, 'interwiki copy four',
        '', '', 'interwiki copy three' );

    $page_admin = $admin->pages->new_from_name('interwiki copy four');
    $page_foobar = $foobar->pages->new_from_name('interwiki copy four');
    
    ok( $return == 0, 'copy failed, flag was wrong' );
    isnt( $page_admin->content, $page_foobar->content,
        'two pages are different, as expected' );
}

{
    my $page_admin_one =
        $admin->pages->new_from_name('intrawiki copy one');
    my $page_admin_two =
        $admin->pages->new_from_name('intrawiki copy two');

    $page_admin_one->content('This page copy is supposed to fail');
    $page_admin_one->store( user => $admin->current_user );
    $page_admin_two->content('This page copy is supposed to be clobbered');
    $page_admin_two->store( user => $admin->current_user );

    my $return = $page_admin_one->duplicate( $admin->current_workspace, 'intrawiki copy two',
        '', '', 'intrawiki copy three' );

    $page_admin_one = $admin->pages->new_from_name('intrawiki copy one');
    $page_admin_two = $admin->pages->new_from_name('intrawiki copy two');
    
    ok( $return == 0, 'copy failed, flag was wrong' );
    isnt( $page_admin_one->content, $page_admin_two->content,
        'two pages are different, as expected' );
}

{
    my $page_admin_one =
        $admin->pages->new_from_name('intrawiki copy three');
    my $page_admin_two =
        $admin->pages->new_from_name('intrawiki copy four');

    $page_admin_one->content('This page copy is supposed to succeed');
    $page_admin_one->store( user => $admin->current_user );
    $page_admin_two->content('This page copy is supposed to be clobbered');
    $page_admin_two->store( user => $admin->current_user );

    my $return = $page_admin_one->duplicate( $admin->current_workspace, 'intrawiki copy four',
        '', '', 'intrawiki copy four' );

    $page_admin_one = $admin->pages->new_from_name('intrawiki copy three');
    $page_admin_two = $admin->pages->new_from_name('intrawiki copy four');
    
    ok( $return, 'copy succeeded, flag was wrong' );
    is( $page_admin_one->content, $page_admin_two->content,
        'two pages are the same, as expected' );
}


{
    my $page_admin_one =
        $admin->pages->new_from_name('intrawiki copy three');
    my $page_admin_two =
        $admin->pages->new_from_name('intrawiki copy four');

    my $temp_file = "/tmp/attachment.$$";
    open my $fh, '>', $temp_file
        or die "Cannot write to $temp_file: $!";
    print $fh 'my test content'
        or die "Cannot write to $temp_file: $!";
    close $fh;

    $admin->pages->current($page_admin_one);
    my $attachment = $admin->attachments->new_attachment(
        filename => "/tmp/attachment.$$.txt");
    $attachment->save("$temp_file");
    $attachment->store( user => $admin->current_user );

    unlink $temp_file;

    $page_admin_one->content('This page copy is supposed to succeed');
    $page_admin_one->store( user => $admin->current_user );
    $page_admin_two->content('This page copy is supposed to be clobbered');
    $page_admin_two->store( user => $admin->current_user );

    my $return = $page_admin_one->duplicate( $admin->current_workspace, 'intrawiki copy four',
        '', '', 'intrawiki copy four' );

    $page_admin_one = $admin->pages->new_from_name('intrawiki copy three');
    $page_admin_two = $admin->pages->new_from_name('intrawiki copy four');
    
    my $attachments_one
        = $admin->attachments->all( page_id => $page_admin_one->id );
    my $attachments_two
        = $admin->attachments->all( page_id => $page_admin_two->id );

    ok( $return, 'copy succeeded, flag was right' );
    is( $page_admin_one->content, $page_admin_two->content,
        'two pages are the same, as expected' );
    is( scalar(@$attachments_one), 1, 'one attachment on source');
    is( scalar(@$attachments_two), 0, 'no attachments on dest');
    is( $attachments_one->[0]->{'page_id'}, 'intrawiki_copy_three',
        'correct id with attachment');
}

{
    my $page_admin_one =
        $admin->pages->new_from_name('intrawiki copy three');
    my $page_admin_two =
        $admin->pages->new_from_name('intrawiki copy four');

    my $return = $page_admin_one->duplicate( $admin->current_workspace, 'intrawiki copy four',
        '1', '1', 'intrawiki copy four' );

    $page_admin_one = $admin->pages->new_from_name('intrawiki copy three');
    $page_admin_two = $admin->pages->new_from_name('intrawiki copy four');
    
    my $attachments_one
        = $admin->attachments->all( page_id => $page_admin_one->id );
    my $attachments_two
        = $admin->attachments->all( page_id => $page_admin_two->id );

    ok( $return, 'copy succeeded, flag was right' );
    is( $page_admin_one->content, $page_admin_two->content,
        'two pages are the same, as expected' );
    is( scalar(@$attachments_one), 1, 'one attachment on source page');
    is( scalar(@$attachments_two), 1, 'one attachment on dest page');
    is( $attachments_two->[0]->{'page_id'}, 'intrawiki_copy_four',
        'attachment present on second thing');
}

{
    my $page_admin_one =
        $admin->pages->new_from_name('intrawiki copy five');

    my $temp_file = "/tmp/space in name - $$";
    open my $fh, '>', $temp_file
        or die "Cannot write to $temp_file: $!";
    print $fh 'my test content'
        or die "Cannot write to $temp_file: $!";
    close $fh;

    $admin->pages->current($page_admin_one);
    $admin->attachments;
    my $attachment = $admin->attachments->new_attachment(
        filename => "/tmp/space in name - $$");
    $attachment->save("$temp_file");
    $attachment->store( user => $admin->current_user );

    unlink $temp_file;

    $page_admin_one->content('This page copy is supposed to succeed');
    $page_admin_one->store( user => $admin->current_user );

    my $return = $page_admin_one->duplicate( $admin->current_workspace, 'intrawiki copy six',
                                             1, 1 );

    my $page_admin_two = $admin->pages->new_from_name('intrawiki copy six');

    my $attachments_one
        = $admin->attachments->all( page_id => $page_admin_one->id );
    my $attachments_two
        = $admin->attachments->all( page_id => $page_admin_two->id );

    ok( $return, 'copy succeeded, flag was right' );
    is( $page_admin_one->content, $page_admin_two->content,
        'two pages are the same, as expected' );
    is( scalar(@$attachments_one), 1, 'one attachment on source');
    is( scalar(@$attachments_two), 1, 'one attachments on dest');
    is( $attachments_one->[0]->{'page_id'}, 'intrawiki_copy_five',
        'correct id with attachment for source');
    is( $attachments_two->[0]->{'page_id'}, 'intrawiki_copy_six',
        'correct id with attachment for dest');
}

BAD_PAGE_TITLE: {
    my $class      = 'Socialtext::DuplicatePagePlugin';
    my @bad_titles = (
        "Untitled Page",
        "Untitled ///////////////// Page",
        "&&&& UNtiTleD ///////////////// PaGe",
        "&&&& UNtiTleD ///////////////// PaGe *#\$*@!#*@!#\$*",
        "Untitled_Page",
        "",
    );
    for my $page (@bad_titles) {
        ok(
            $class->_page_title_bad("Untitled Page"),
            "Invalid title: \"$page\""
        );
    }
    ok( !$class->_page_title_bad("Cows Are Good"), "OK page title" );
}
