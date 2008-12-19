#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 16;
use Test::Socialtext::User;
fixtures( 'admin', 'destructive' );

my $hub = new_hub('admin');

my $admin = $hub->current_workspace();
$admin->permissions->set( set_name => 'public-read-only' );
$admin->set_logo_from_uri( uri => 'http://example.com/logo.gif' );

my $user = $hub->current_user;
my $singapore = join '', map { chr($_) } 26032, 21152, 22369;
# Perl will treat a string with 0xF6 as not UTF8 unless we force it to
# "upgrade" the string to utf8.
my $dot_net = Encode::decode( 'latin-1', 'd' . chr( 0xF6 ) . 't net' );
$user->update_store(
    # Tests handling of utf8 in export/import
    first_name => $singapore,
    last_name  => $dot_net,
    # Used to test that password survives export/import
    password   => 'something or other'
);

my $page = $hub->pages->new_from_name('Admin Wiki');
$page->update(
    content          => 'This is new front page content.',
    original_page_id => $page->id(),
    revision         => $page->metadata()->Revision(),
    subject          => 'Admin Wiki',
    user             => $user,
);

my $tarball = $admin->export_to_tarball(dir => 't/tmp');

$admin->delete();

# Deleting the user is important so that we know that both user and
# workspace data is restored
Test::Socialtext::User->delete_recklessly($user);

Socialtext::Workspace->ImportFromTarball( tarball => $tarball );

# The actual tests start here ...
{
    # If this works at all we can know that the restore did something
    my $hub = new_hub('admin');
    my $admin = $hub->current_workspace;

    is( $admin->logo_uri(), 'http://example.com/logo.gif',
        'check that logo_uri survived export/import' );

    my @data_dirs = $admin->_data_dir_paths();
    ok( ( grep { -d } @data_dirs ) == @data_dirs,
        'all data dirs are present are a restore' );

    ok( $admin->user_count, 'admin workspace has users' );

    my $user = Socialtext::User->new( username => 'devnull1@socialtext.com' );
    ok( $admin->has_user( $user ), 'devnull1@socialtext.com is in admin workspace' );

    is( $user->first_name(), $singapore, 'user first name is Singapore (in Chinese)' );
    is( $user->last_name(), $dot_net, 'user last name is dot net (umlauts on o)' );
    ok( $user->password_is_correct('something or other'), 'password survived import' );

    ok( Socialtext::EmailAlias::find_alias('admin'), 'email alias exists for admin workspace' );

    ok( $admin->permissions->role_can(
            role       => Socialtext::Role->Guest(),
            permission => Socialtext::Permission->new( name => 'read' ) ),
        'guest can read workspace' );

    ok( ! $admin->permissions->role_can(
            role       => Socialtext::Role->Guest(),
            permission => Socialtext::Permission->new( name => 'edit' ) ),
        'guest cannot edit workspace' );

    my $page = $hub->pages->new_from_name('Admin Wiki');
    ok( $page->exists(), 'Admin Wiki page exists' );
    like( $page->content(), qr/new front page content/, 'Admin Wiki page content has expected text' );

    $page = $hub->pages()->new_from_name('Start Here');
    ok( $page->exists(), 'Start Here page exists' );
    like( $page->content(), qr/organize information/, 'Start Here page content has expected text' );

    eval { Socialtext::Workspace->ImportFromTarball( tarball => $tarball ) };
    like( $@, qr/cannot restore/i, 'cannot restore over an existing workspace' );

    eval { Socialtext::Workspace->ImportFromTarball( tarball => $tarball, overwrite => 1 ) };
    is( $@, '', 'can force an overwrite when restoring' );
}
