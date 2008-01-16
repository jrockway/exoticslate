#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 41;
use Test::Socialtext::Search;
fixtures( 'admin' );

use Fcntl ':flock';
use File::chdir;
use File::Path;
use Socialtext::AppConfig;
use Socialtext::EventListener::Registry;
use Socialtext::Paths;
use YAML qw(LoadFile Dump DumpFile);

Socialtext::EventListener::Registry->load(); # set up default registry

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
Readonly my %DEFAULT_REGISTRY => %Socialtext::EventListener::Registry::Listeners;

my $hub = new_hub('admin');

test_create();
test_lock_doesnt_block();
test_page_symlink();
test_attachment_symlink();
test_workspace_symlink();
test_rampup_produces_no_macguffin();
test_rampup_produces_macguffin();

sub test_create {
    remove_dir();
    turn_off_rampup(); # to make sure our environment is clean 
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
    st_admin_command_count_is( $macguffin_output, 2 );
    for my $cmd (qw(index-page send-weblog-pings send-email-notifications 
                    send-watchlist-emails)) {
        st_admin_command_present(
            $macguffin_output,
            join( "\0", $cmd, '--workspace', 'admin', '--page', $PAGE_NAME,
                '--ceqlotron' )
        );
    }

    my %separate_events = (
        Page => [
            'Socialtext::EventListener::IndexPage::IndexPage',
            'Socialtext::EventListener::IndexPage::RampupIndexPage',
            'Socialtext::EventListener::Page::SendEmailNotifications',
            'Socialtext::EventListener::Page::SendWatchlistEmails',
            'Socialtext::EventListener::Page::SendWeblogPings',
        ]
    );
    activate_handler_config( \%separate_events );
    Socialtext::ChangeEvent->Record($page);

    run_ceqlotron_with_macguffin();
    ok(
        -e $MACGUFFIN_FILE,
        "$CEQLOTRON (page symlink) called the MacGuffin"
    );

    my $macguffin_output = LoadFile($MACGUFFIN_FILE);
    unlink $MACGUFFIN_FILE or die "unlink '$MACGUFFIN_FILE': $!";

    st_admin_args_ok($macguffin_output);
    st_admin_command_count_is( $macguffin_output, 5 );
    for my $cmd (qw(index-page send-weblog-pings send-email-notifications 
                    send-watchlist-emails)) {
        st_admin_command_present(
            $macguffin_output,
            join( "\0", $cmd, '--workspace', 'admin', '--page', $PAGE_NAME,
                '--ceqlotron' )
        );
    }

    activate_handler_config( \%DEFAULT_REGISTRY );
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
    st_admin_command_count_is( $macguffin_output, 2 );
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

# this test should not create a macguffin file, since we've blown away the
# rampup.yaml search config
sub test_rampup_produces_no_macguffin {
    use_ok( "Socialtext::ChangeEvent::RampupIndexPage" );
    my $page = $hub->pages->new_from_name($PAGE_NAME);
    Socialtext::ChangeEvent::RampupIndexPage->Record($page);
    ok ( ! -e 't/tmp/etc/socialtext/search/rampup.yaml', "rampup.yaml file doesn't exist");
    run_ceqlotron_with_macguffin();
    ok(
        -e $MACGUFFIN_FILE,
        "$CEQLOTRON (rampup page symlink) created the macguffin file, but it's empty."
    );

    my $macguffin_output = LoadFile($MACGUFFIN_FILE);
    unlink $MACGUFFIN_FILE or die "unlink '$MACGUFFIN_FILE': $!";

    st_admin_args_ok($macguffin_output);
    st_admin_command_count_is( $macguffin_output, 1 );
    st_admin_command_present(
        $macguffin_output,
        ""
    );
}

# this test should create a macguffin file for a given event being generated,
# since the rampup.yaml search config will be in effect
sub test_rampup_produces_macguffin {
    turn_on_rampup();
    my $page = $hub->pages->new_from_name($PAGE_NAME);
    Socialtext::ChangeEvent::RampupIndexPage->Record($page);

    run_ceqlotron_with_macguffin();
    ok(
        -e $MACGUFFIN_FILE,
        "$CEQLOTRON (rampup page symlink) called the MacGuffin"
    );

    my $macguffin_output = LoadFile($MACGUFFIN_FILE);
    unlink $MACGUFFIN_FILE or die "unlink '$MACGUFFIN_FILE': $!";

    st_admin_args_ok($macguffin_output);
    st_admin_command_count_is( $macguffin_output, 1 );
    st_admin_command_present(
        $macguffin_output,
        "index-page\0--workspace\0admin\0--page\0$PAGE_NAME\0--search-config\0rampup\0--ceqlotron"
    );
    turn_off_rampup();
}

sub activate_handler_config {
    my $config = shift;
    my $config_file = 't/tmp/etc/socialtext/event_listeners.yaml';
    DumpFile($config_file, Dump($config));
    Socialtext::EventListener::Registry->_force_load();
}

sub st_admin_args_ok {
    my ( $macguffin_output ) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    is_deeply(
        $_->{ARGV},
        [ 'from_input' ],
        'st-admin command-line arguments are correct'
    ) for @$macguffin_output;
}

sub st_admin_command_count_is {
    my ( $macguffin_output, $expected ) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    is( scalar @$macguffin_output, $expected, "$expected commands sent to st-admin" );
}

sub st_admin_command_present {
    my ( $macguffin_output, $command ) = @_;

    my $pretty_command = $command;
    $pretty_command =~ s/\0/ /g;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    like(
        (join "\n", map { $_->{STDIN} } @$macguffin_output),
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

