# @COPYRIGHT@
package Test::Socialtext;
use strict;
use warnings;

use lib 'lib';

use Cwd ();
use Test::Base 0.52 -Base;
use Socialtext::Base;
use Test::Builder;
use Test::Socialtext::Environment;
use Test::Socialtext::User;
use YAML;
use File::Temp qw/tempdir/;
use File::Spec;

# Set this to 1 to get rid of that stupid "but matched them out of order"
# warning.
our $Order_doesnt_matter = 0;

our @EXPORT = qw(
    fixtures
    new_hub
    SSS
    run_smarter_like
    smarter_like
    smarter_unlike
    ceqlotron_run_synchronously
    setup_test_appconfig_dir
    formatted_like
    formatted_unlike
);

our @EXPORT_OK = qw(
    content_pane 
    main_hub
    run_manifest
    check_manifest
);

{
    my $builder = Test::Builder->new();
    my $fh = $builder->output();
    # Get around syntax checking warnings
    if (defined $fh) {
        binmode $fh, ':utf8';
        $builder->output($fh);
    }
}

sub fixtures () {
    $ENV{NLW_CONFIG} = Cwd::cwd . '/t/tmp/etc/socialtext/socialtext.conf';

    Test::Socialtext::Environment->CreateEnvironment( fixtures => [ @_ ] );

    # store the state of the universe "after fixtures have been created", so
    # that we can reset back to this state (as best we can) at the end of the
    # test run.
    _store_initial_state();
}

sub run_smarter_like() {
    (my ($self), @_) = find_my_self(@_);
    my $string_section = shift;
    my $regexp_section = shift;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    for my $block ($self->blocks) {
        local $SIG{__DIE__};
        smarter_like(
            $block->$string_section,
            $block->$regexp_section,
            $block->name
        );
    }
}

sub smarter_like() {
    my $str = shift;
    my $re = shift;
    my $name = shift;
    my $order_doesnt_matter = shift || 0;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my @res = split /\n/, $re;
    for my $i (0 .. $#res) {
        my $x = qr/$res[$i]/;
        unless ($str =~ $x) {
            test_more_fail(
                "The string: '$str'\n"
                . "...doesn't match $x (line $i of regexp)",
                $name
            );
            return;
        }
    }
    my $mashed = join '.*', @res;
    $mashed = qr/$mashed/sm;
    die "This looks like a crazy regexp:\n\t$mashed is a crazy regexp"
        if $mashed =~ /\.[?*]\.[?*]/;
    if (!$order_doesnt_matter) {
        unless ($str =~ $mashed) {
            test_more_fail(
                "The string: '$str'\n"
                . "...matched all the parts of $mashed\n"
                . "...but didn't match them in order.",
                $name
            );
            return;
        }
    }
    ok 1, "$name - success";
}

sub smarter_unlike() {
    my $str = shift;
    my $re = shift;
    my $name = shift;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my @res = split /\n/, $re;
    for my $i (0 .. $#res) {
        my $x = qr/$res[$i]/;
        if ($str =~ $x) {
            test_more_fail(
                "The string: '$str'\n"
                . "...matched $x (line $i of regexp)",
                $name
            );
            return;
        }
    }
    pass( "$name - success" );
}

sub formatted_like() {
    my $wikitext = shift;
    my $re       = shift;
    my $name     = shift;
    unless ($name) {
        $name = $wikitext;
        $name =~ s/\n/\\n/g;
    }
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $formatted = main_hub()->viewer->text_to_html("$wikitext\n");
    like $formatted, $re, $name;
}

sub formatted_unlike() {
    my $wikitext = shift;
    my $re       = shift;
    my $name     = shift;
    unless ($name) {
        $name = $wikitext;
        $name =~ s/\n/\\n/g;
    }
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $formatted = main_hub()->viewer->text_to_html("$wikitext\n");
    unlike $formatted, $re, $name;
}

sub ceqlotron_run_synchronously() {
    # We have to do this here because at compile time, gen-config may
    # not have yet created the appconfig file, and Socialtext::Ceqlotron uses
    # Socialtext::AppConfig.
    require Socialtext::Ceqlotron;
    import Socialtext::Ceqlotron;

    # Temporarily override ceqlotron_synchronous.
    my $prev_appconfig = $ENV{NLW_APPCONFIG} || '';
    local $ENV{NLW_APPCONFIG} = "ceqlotron_synchronous=1,$prev_appconfig";

    # Actually run the queue.
    Socialtext::Ceqlotron::run_current_queue();
}

# Create a temp directory and setup an AppConfig using that directory.
sub setup_test_appconfig_dir {
    my %opts = @_;

    # We want our own dir because when we try to create files later,
    # we need to make sure we're not trying to overwrite a file
    # someone else created.
    my $dir = $opts{dir} || tempdir( CLEANUP => 1 );

    # Cannot use Socialtext::File::catfile here because it depends on
    # Socialtext::AppConfig, and we don't want it reading the wrong config
    # file.
    my $config_file = File::Spec->catfile( $dir, 'socialtext.conf' );

    open(my $config_fh, ">$config_file")
        or die "Cannot open to $config_file: $!";

    select my $old = $config_fh; 
    $| = 1;  # turn on autoflush
    select $old;
    print $config_fh YAML::Dump($opts{config_data});
    close $config_fh or die "Can't write to $config_file: $!";
    return $config_file if $opts{write_config_only};

    require Socialtext::AppConfig;
    Socialtext::AppConfig->new(
        file => $config_file,
        _singleton => 1,
    );
    return $config_file;
}

# store initial state, so we can revert back to this (as best we can) at the
# end of each test run.
sub _store_initial_state {
    _store_initial_appconfig();
    _store_initial_userids();
    _store_initial_workspaceids();
}

# revert back to the initial state (as best we can) when the test run is over.
END { _teardown_cleanup() }
sub _teardown_cleanup {
    _reset_initial_appconfig();
    _remove_all_but_initial_userids();
    _remove_all_but_initial_workspaceids();
}

{
    my %InitialAppConfig;
    sub _store_initial_appconfig {
        my $appconfig = Socialtext::AppConfig->new();
        foreach my $opt ($appconfig->Options) {
            $InitialAppConfig{$opt} = $appconfig->$opt();
        }
    }
    sub _reset_initial_appconfig {
        my $appconfig = Socialtext::AppConfig->new();
        foreach my $opt (keys %InitialAppConfig) {
            no warnings;
            if ($appconfig->$opt() ne $InitialAppConfig{$opt}) {
                Test::More::diag( "CLEANUP: resetting '$opt' AppConfig value; your test changed it" );
                $appconfig->set( $opt, $InitialAppConfig{$opt} );
                $appconfig->write();
            }
        }
    }
}

{
    my %InitialUserIds;
    sub _store_initial_userids {
        my $iterator = Socialtext::User->All();
        while (my $user = $iterator->next()) {
            my $userid = $user->user_id();
            $InitialUserIds{$userid} ++;
        }
    }
    sub _remove_all_but_initial_userids {
        # if we didn't store an initial set of users, don't do any cleanup
        return unless %InitialUserIds;

        # remove all but the initial set of users that were created and
        # available at startup.
        my $iterator = Socialtext::User->All();
        while (my $user = $iterator->next()) {
            my $userid = $user->user_id();
            unless ($InitialUserIds{$userid}) {
                my $driver   = $user->driver_name();
                my $user_id  = $user->user_id();
                my $username = $user->username();
                Test::More::diag( "CLEANUP: removing user '$driver:$user_id ($username)'; your test left it behind" );
                Test::Socialtext::User->delete_recklessly($user);
            }
        }
    }
}

{
    my %InitialWorkspaceIds;
    sub _store_initial_workspaceids {
        my $iterator = Socialtext::Workspace->All();
        while (my $ws = $iterator->next()) {
            my $ws_id = $ws->workspace_id();
            $InitialWorkspaceIds{$ws_id} ++;
        }
    }
    sub _remove_all_but_initial_workspaceids {
        # if we didn't store an initial set of workspaces, don't do any cleanup
        return unless %InitialWorkspaceIds;

        # remove all but the initial set of workspaces that were created and
        # available at startup.
        my $iterator = Socialtext::Workspace->All();
        while (my $ws = $iterator->next()) {
            my $ws_id = $ws->workspace_id();
            unless ($InitialWorkspaceIds{$ws_id}) {
                my $ws_name = $ws->name();
                Test::More::diag( "CLEANUP: removing workspace '$ws_id ($ws_name)'; your test left it behind" );
                $ws->delete();
            }
        }
    }
}

sub test_more_fail() {
    my $str = shift;
    my $test_name = shift || '';
    warn $str; # This doesn't get shown unless in verbose mode.
    Test::More::fail($test_name); # to get the counts right.
}

sub run_manifest() {
    (my ($self), @_) = find_my_self(@_);
    for my $block ($self->blocks) {
        $self->check_manifest($block) 
          if exists $block->{manifest};
    }
}

sub check_manifest {
    my $block = shift;
    my @manifest = $block->manifest;
    my @unfound = grep not(-e), @manifest;
    my $message = 'expected files exist';
    if (@unfound) {
        warn "$_ does not exist\n" for @unfound;
        $message = sprintf "Couldn't find %s of %s paths\n",
          scalar(@unfound),
          scalar(@manifest);
    }
    ok(0 == scalar @unfound, $message);
}

sub new_hub() {
    no warnings 'once';
    my $name = shift or die "No name provided to new_hub\n";
    my $username = shift;
    my $hub = Test::Socialtext::Environment->instance()->hub_for_workspace($name, $username);
    $Test::Socialtext::Filter::main_hub = $hub;
    return $hub;
}

my $main_hub;

sub main_hub {
    $main_hub = shift if @_;
    $main_hub ||= Test::Socialtext::new_hub('admin');
    return $main_hub;
}

sub SSS() {
    my $sh = $ENV{SHELL} || 'sh';
    system("$sh > `tty`");
    return @_;
}

package Test::Socialtext::Filter;
use strict;
use warnings;

use base 'Test::Base::Filter';

# Add Test::Base filters that are specific to NLW here. If they are really
# generic and interesting I'll move them into Test::Base

sub interpolate_global_scalars {
    map {
        s/"/\\"/g;
        s/@/\\@/g;
        $_ = eval qq{"$_"};
        die "Error interpolating '$_': $@" 
          if $@;
        $_;
    } @_;
}

sub tmp_nlwroot_path {
    map { 't/tmp/' . $_ } @_;
}

# Regexps with the '#' character seem to get messed up.
sub literal_lines_regexp {
    $self->assert_scalar(@_);
    my @lines = $self->lines(@_);
    @lines = $self->chomp(@lines);
    my $string = join '', map {
        # REVIEW: This is fragile and needs research.
        s/([\$\@\}])/\\$1/g;
        "\\Q$_\\E.*?\n";
    } @lines;
    my $flags = $Test::Base::Filter::arguments;
    $flags = 'xs' unless defined $flags;

    my $regexp = eval "qr{$string}$flags";
    die $@ if $@;
    return $regexp;
}

sub wiki_to_html {
    $self->assert_scalar(@_);
    Test::Socialtext::main_hub()->formatter->text_to_html(shift);
}

sub wrap_p_tags {
    $self->assert_scalar(@_);
    sprintf qq{<p>\n%s<\/p>\n}, shift;
}

sub wrap_wiki_div {
    $self->assert_scalar(@_);
    sprintf qq{<div class="wiki">\n%s<\/div>\n}, shift;
}

sub new_page {
    $self->assert_scalar(@_);
    my $hub = Test::Socialtext::main_hub();
    my $page = $hub->pages->new_page_from_any(shift);
    $page->metadata->update( user => $hub->current_user );
    return $page;
}

sub store_new_page {
    $self->assert_scalar(@_);
    my $page = $self->new_page(shift);
    $page->store( user => Test::Socialtext::main_hub()->current_user );
    return $page;
}

sub content_pane {
    my $html = shift;
    $html =~ s/
        .*(
        <div\ id="page-container">
        .*
        <td\ class="page-center-control-sidebar-cell"
        ).*
    /$1/xs;
    $html
}

sub _cleanerr() {
    my $output = shift;
    $output =~ s/^.*index.cgi: //gm;
    my @lines = split /\n/, $output;
    pop @lines;
    if (@lines > 15) {
        push @lines, "\n...more above\n", @lines[0..15]
    }
    join "\n", @lines;
}

1;

