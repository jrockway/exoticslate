#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 20;
fixtures( 'admin_no_pages' );

BEGIN {
    use_ok( 'Socialtext::ChangeEvent' );
    use_ok( 'Socialtext::Page' );
    use_ok( 'Socialtext::Paths' );
}

my $hub = new_hub('admin');
isa_ok( $hub, 'Socialtext::Hub' );

my $page = Socialtext::Page->new(hub => $hub)->create(
    title => 'ceqlotron test',
    content => 'some stuff',
    creator => $hub->current_user,
);
isa_ok( $page, 'Socialtext::Page' );

my $attachment = make_attachment($page);
isa_ok( $attachment, 'Socialtext::Attachment' );

my $workspace = $hub->current_workspace;
isa_ok( $workspace, 'Socialtext::Workspace' );

# test a page

test_object( $page,       $page->file_path );
test_object( $attachment, $attachment->full_path );
test_object(
    $workspace,
    Socialtext::Paths::page_data_directory( $workspace->name )
);
test_object( (bless {}, 'MyButt'), '/tmp/fakery', 'fail' );

sub test_object {
    my $object         = shift;
    my $target_path    = shift;
    my $desire_to_fail = shift;

    remove_files();

    eval {
        Socialtext::ChangeEvent->Record($object);
    };

    if ($desire_to_fail) {
        ok(defined($@), "\$\@ is set to $@");
    } else {
        is($@ , '', "\$\@, $@, ought to be empty");
        # should be only one
        my @files = get_files();
        is( scalar @files, 1, 'should be one and only one symlink');
        ok( -l $files[0], "$files[0] is a symlink");
        is( readlink $files[0], $target_path,
            "$files[0] points to $target_path" );
    }
}

sub remove_files {
    unlink(get_files());
}

sub get_files {
    my $directory = Socialtext::Paths::change_event_queue_dir();
    if ( -e $directory ) {
        opendir my $dh, $directory
            or die "unable to open directory: $!";

        # dupe with Socialtext::File::all_directory_files, except it gets plain files
        return map {"$directory/$_"} grep { !/^(?:\.|\.\.)$/ } readdir $dh;
    }
    else {
        return ();
    }
}

sub make_attachment {
    my $page     = shift;
    my $filepath = 't/attachments/foo.txt';
    open my $fh, '<', $filepath or die "$filepath: $!";
    my $attachment = $hub->attachments->new_attachment(
        filename => 'foo.txt',
        page_id  => $page->id,
        fh       => $fh,
    );
    $attachment->save($fh);
    $attachment->store( user => $hub->current_user );
    return $attachment;
}
