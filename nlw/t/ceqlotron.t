#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 19;
fixtures( 'admin' );

use Fcntl ':flock';
use File::chdir;
use File::Path;
use Socialtext::Paths;
use YAML 'LoadFile';

use Readonly;

Readonly my $ATTACHMENT_PAGE => 'formattingtest';
Readonly my $ATTACHMENT_ID   => '20060321153600-0';
Readonly my $CEQLOTRON       => 'bin/ceqlotron';
Readonly my $CEQ_DIR         => Socialtext::Paths::change_event_queue_dir;
Readonly my $LOCK_FILE       => Socialtext::Paths::change_event_queue_lock;
Readonly my $LOCK_EXIT_CODE  => 1;
Readonly my $MACGUFFIN_FILE => "/tmp/macguffin-$<.yaml";    # XXX dedup
Readonly my $PAGE_NAME      => 'click_links';
Readonly my $SLEEP_SECONDS  => 1;
Readonly my $WORKSPACE      => 'admin';

my $hub = new_hub('admin');

test_create();
test_lock_doesnt_block();
test_page_symlink();
test_attachment_symlink();
test_workspace_symlink();

sub test_create {
    remove_dir();
    system($^X, $CEQLOTRON, '--once', '--foreground');
    ok( -e $CEQ_DIR, "$CEQLOTRON creates $CEQ_DIR" );
    ok( -f $LOCK_FILE, "$CEQLOTRON creates $LOCK_FILE" );
}

# This test ensures that ceqlotron exits w/ $LOCK_EXIT_CODE if somebody else
# has the lock.
sub test_lock_doesnt_block {
    open my $lock, '<', $LOCK_FILE or die "open $LOCK_FILE: $!";
    flock $lock, LOCK_EX|LOCK_NB or die "flock $LOCK_FILE: $!";
    my $wait_code = system($^X, $CEQLOTRON, '--once', '--foreground');
    flock $lock, LOCK_UN or die "unlock '$LOCK_FILE': $!";
    close $lock or die "close '$LOCK_FILE': $!";
    is(
        $wait_code >> 8,
        $LOCK_EXIT_CODE,
        "$CEQLOTRON exits $LOCK_EXIT_CODE with lock held"
    );
}

# This test uses dev-bin/macguffin to figure out how 'st-admin' would
# be called and verify that it gets the right input and arguments.
sub test_page_symlink {
    my $page = $hub->pages->new_from_name($PAGE_NAME);
    Socialtext::ChangeEvent->Record($page);

    run_ceqlotron_with_macguffin();

    ok( -e $MACGUFFIN_FILE, "$CEQLOTRON (page symlink) called the MacGuffin" );

    my $macguffin_output = LoadFile($MACGUFFIN_FILE);
    unlink $MACGUFFIN_FILE or die "unlink '$MACGUFFIN_FILE': $!";

    st_admin_args_ok($macguffin_output);
    st_admin_command_count_is( $macguffin_output, 4 );
    for my $cmd (qw(index-page send-weblog-pings send-email-notifications 
                    send-watchlist-emails)) {
        st_admin_command_present(
            $macguffin_output,
            join( "\0", $cmd, '--workspace', 'admin', '--page', $PAGE_NAME,
                '--ceqlotron' )
        );
    }
    my @commands = split /\n/, $macguffin_output->{STDIN};
    like( $commands[-1], qr/index-page/m,
          'index-page is the last command sent to from_input' );
}

# This test uses dev-bin/macguffin to figure out how st-admin would be called and
# verify that it gets the right input and arguments.
sub test_attachment_symlink {
    my $attachment = Socialtext::Attachments->new( hub => $hub )
        ->new_attachment( page_id => $ATTACHMENT_PAGE, id => $ATTACHMENT_ID,
        filename => 'thefilename' );
    Socialtext::ChangeEvent->Record($attachment);

    run_ceqlotron_with_macguffin();

    ok(
        -e $MACGUFFIN_FILE,
        "$CEQLOTRON (attachment symlink) called the MacGuffin"
    );

    my $macguffin_output = LoadFile($MACGUFFIN_FILE);
    unlink $MACGUFFIN_FILE or die "unlink '$MACGUFFIN_FILE': $!";

    st_admin_args_ok($macguffin_output);
    st_admin_command_count_is( $macguffin_output, 1 );
    st_admin_command_present(
        $macguffin_output,
        join( "\0", 'index-attachment', '--attachment', $ATTACHMENT_ID,
            '--page', $ATTACHMENT_PAGE, '--workspace', 'admin',
            '--ceqlotron' )
    );
}

# This test uses dev-bin/macguffin to figure out how st-admin would be called and
# verify that it gets the right input and arguments.
sub test_workspace_symlink {
    my $workspace = $hub->current_workspace();
    Socialtext::ChangeEvent->Record($workspace);

    run_ceqlotron_with_macguffin();

    ok(
        -e $MACGUFFIN_FILE,
        "$CEQLOTRON (workspace symlink) called the MacGuffin"
    );

    my $macguffin_output = LoadFile($MACGUFFIN_FILE);
    unlink $MACGUFFIN_FILE or die "unlink '$MACGUFFIN_FILE': $!";

    st_admin_args_ok($macguffin_output);
    st_admin_command_count_is( $macguffin_output, 1 );
    st_admin_command_present(
        $macguffin_output,
        "index-workspace\0--workspace\0admin\0--ceqlotron"
    );
}

sub st_admin_args_ok {
    my ( $macguffin_output ) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    use Data::Dumper;
    is_deeply(
        $macguffin_output->{ARGV},
        [ 'from_input' ],
        'st-admin command-line arguments are correct'
    ) or diag(Dumper($macguffin_output->{ARGV}));
}

sub st_admin_command_count_is {
    my ( $macguffin_output, $expected ) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my @lines = split /\n/, $macguffin_output->{STDIN};
    is( scalar @lines, $expected, "$expected commands sent to st-admin" );
}

sub st_admin_command_present {
    my ( $macguffin_output, $command ) = @_;

    my $pretty_command = $command;
    $pretty_command =~ s/\0/ /g;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    like(
        $macguffin_output->{STDIN},
        qr/^\Q$command\E\s*$/m,
        "'$pretty_command' sent to st-admin"
    );
}

sub run_ceqlotron_with_macguffin {
    unlink $MACGUFFIN_FILE;
    die "Could not unlink $MACGUFFIN_FILE: $!" if -e $MACGUFFIN_FILE;
    local $ENV{NLW_APPCONFIG} = "admin_script=$CWD/dev-bin/macguffin";
    system( $^X, $CEQLOTRON , '--once', '--foreground' );
    sleep $SLEEP_SECONDS; # Isn't asynchronous testing fun?
}

sub remove_dir {
    if (-e $CEQ_DIR) {
        rmtree([$CEQ_DIR], 0, 1);
    }
    die "Unable to clear out $CEQ_DIR" if -e $CEQ_DIR;
}
