#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 14;
fixtures('workspaces');

use Socialtext::Pages;
use File::Path ();
use File::Spec;
use File::Temp ();
use Storable ();
use Socialtext::Formatter::Parser;

my $cache_dir = Socialtext::AppConfig->formatter_cache_dir;
my $page_name = 'cache page';

if ( -e $cache_dir ) {
    diag("removing $cache_dir");
    File::Path::rmtree($cache_dir);
}

my $hub = new_hub('admin');
my $page = Socialtext::Page->new( hub => $hub )->create(
    title   => $page_name,
    content => <<'EOF',
This is the page.

{link public [welcome]}

{link foobar [welcome]}

EOF
    creator => $hub->current_user,
);

FIRST_PARSE: {
    check_with_user( user => 'devnull1@socialtext.com' );
}

SECOND_PARSE_USES_CACHE: {

    # the cache is only used if its last mod time is _greater_ than the
    # page file (not if they're the same)
    my $cache_file
        = File::Spec->catfile( $cache_dir, $hub->current_workspace->workspace_id,
        $page->id );

    my $parser = Socialtext::Formatter::Parser->new(
        table      => $hub->formatter->table,
        wafl_table => $hub->formatter->wafl_table,
    );
    my $parsed = $parser->text_to_parsed( <<'EOF' );
Coming from the cache.

{link public [welcome]}

{link foobar [welcome]}
EOF
    Storable::nstore( $parsed, $cache_file );

    my $future = time + 5;
    utime $future, $future, $cache_file
        or die "Cannot call utime on $cache_file: $!";
    check_with_user(
        user       => 'devnull1@socialtext.com',
        from_cache => 1,
    );

    ok( -e $cache_dir, 'cache directory exists' );
}

OTHER_USER_NO_ACCESS: {
    my $user = Socialtext::User->create(
        username      => 'toobad@example.com',
        email_address => 'toobad@example.com',
        password      => 'password'
    );
    $hub->current_workspace->add_user(
        user => $user,
        role => Socialtext::Role->Member(),
    );
    check_with_user(
        user        => 'toobad@example.com',
        should_fail => 1,
    );

    open my $fh, '>', $page->current_revision_file
        or die "Cannot write to ", $page->current_revision_file, ": $!";
    print $fh $page->headers, <<'EOF';

a brand new page!

{link public [welcome]}

{link foobar [welcome]}

EOF
    close $fh;

    my $future = time + 10;
    utime $future, $future, $page->current_revision_file
        or die "Cannot call utime on ", $page->current_revision_file, ": $!";

    check_with_user(
        user             => 'devnull1@socialtext.com',
        new_page_content => 1,
    );

    ok( -e $cache_dir, 'cache directory exists' );
}

CACHE_DIR_UNWRITEABLE: {
    my $dir = File::Temp::tempdir( CLEANUP => 1 );

    my $cache_subdir = File::Spec->catdir( $dir,
        $hub->current_workspace()->workspace_id() );
    mkdir $cache_subdir
        or die "Cannot make $cache_subdir: $!";

    chmod 0400, $cache_subdir or die "Cannot chmod $cache_subdir to 0400: $!";

    # Without this it won't get cleaned up because of the chmod
    END { chmod 0700, $cache_subdir }

    Socialtext::AppConfig->set( formatter_cache_dir => $dir );

    check_with_user( user => 'devnull1@socialtext.com' );
}


sub check_with_user {
    my %p = @_;

    my $hub = new_hub('admin');
    my $user = Socialtext::User->new( username => $p{user} );
    $hub->current_user($user);
    my $output = $hub->pages->new_from_name($page_name)->to_html_or_default;

    if ( $p{should_fail} ) {
        unlike(
            $output,
            qr{\Qhref="/foobar/index.cgi?welcome"},
            'foobar link not present'
        );
        like(
            $output,
            qr{wafl_permission_error},
            'permission error'
        );
    }
    else {
        like(
            $output,
            qr{a brand new page},
            'new content present'
        )
            if $p{new_page_content};
        like(
            $output,
            qr{Coming from the cache},
            'content is from the cache'
        )
            if $p{from_cache};
        like(
            $output,
            qr{\Qhref="/public/index.cgi?welcome"},
            'public link present'
        );
        like(
            $output,
            qr{\Qhref="/foobar/index.cgi?welcome"},
            'foobar link present'
        );
    }
}
