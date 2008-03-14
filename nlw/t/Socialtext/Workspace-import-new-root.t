#!perl
# @COPYRIGHT@

use strict;
use warnings;

use File::Basename ();
use File::Path;
use File::Spec;
use Socialtext::File;
use Socialtext::Workspace;

use Test::Socialtext tests => 7;
fixtures( 'admin' );

my $hub = new_hub('admin');

my $admin = $hub->current_workspace();
my $tarball = $admin->export_to_tarball(dir => "t/tmp");

$admin->delete();

require Socialtext::AppConfig;
my $data_root = Socialtext::AppConfig->data_root_dir();
File::Path::rmtree($data_root);

my $new_root = Socialtext::File::catdir( File::Basename::dirname($data_root), 'new-root' );
File::Path::rmtree($new_root)
    if -d $new_root;
mkdir $new_root
    or die "Cannot mkdir $new_root: $!";

Socialtext::AppConfig->set( data_root_dir => $new_root );
warn "File: " . Socialtext::AppConfig->instance->{file};
Socialtext::AppConfig->write;

Socialtext::Workspace->ImportFromTarball( tarball => $tarball );

{
    my $hub = new_hub('admin');
    my $admin = $hub->current_workspace;

    my $page = $hub->pages->new_from_name('Admin Wiki');
    ok( $page->exists(), 'Admin Wiki page exists' );
    like( $page->content(), qr/home page for Admin Wiki/,
          'Admin Wiki page content has expected text' );

    $page = $hub->pages()->new_from_name('Start Here');
    ok( $page->exists(), 'Start Here page exists' );
    like( $page->content(), qr/organize information/,
          'Start Here page content has expected text' );

    my $rev_id = $page->revision_id;
    my $symlink
        = File::Spec->catfile( $new_root, 'data', 'admin', 'start_here',
        'index.txt' );
    ok( -l $symlink, "$symlink is a symlink" );

    my $target = readlink $symlink;
    ok( File::Spec->file_name_is_absolute($target),
        'symlink target is an absolute path' );
    ok( -f $target, 'symlink target exists' );
}

End_block: {
    Socialtext::AppConfig->set( data_root_dir => $data_root );
    Socialtext::AppConfig->write;
    File::Path::rmtree($new_root);
}
