#!/usr/bin/env perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::More tests => 26;

use IO::Scalar;
use Readonly;
use Date::Format;

use Socialtext::UsageStats;

# test get_workspace_from_url
{
    my %workspace_urls = (
        '/dev-tasks/index.cgi?help_me'      => 'dev-tasks',
        '/public/index.cgi?action=destroy'  => 'public',
        '/public/index.cgi?the_hippies'     => 'public',
        '/arti/index.cgi'                   => 'arti',
    );

    my @other_urls = qw(
        /feed/workspace/dev-tasks
        /nlw/login.html
        /johnson/and/johnson/baby/shampoo
    );

    for my $url ( keys %workspace_urls ) {
        my $found_workspace
            = Socialtext::UsageStats::get_workspace_from_url($url);
        is( $found_workspace, $workspace_urls{$url},
            "$url should find $found_workspace" );
    }

    for my $url (@other_urls) {
        ok( ! Socialtext::UsageStats::get_workspace_from_url($url),
            "$url should have no workspace" );
    }

}

# test is_edit_action
{
    my @data = (
        [ 'POST', '/dev-tasks/index.cgi',         302,  1 ],
        [ 'POST', '/dev-tasks/index.cgi',         200,  0 ],
        [ 'POST', '/dev-tasks/index.cgi?help_me', 302,  0 ],
        [ 'GET',  '/dev-tasks/index.cgi',         302,  0 ],
    );

    for my $request (@data) {
        my $is_edit = Socialtext::UsageStats::is_edit_action(
            $request->[0], # method
            $request->[1], # url
            $request->[2], # status
        );

        # Compare the result with the expected result,
        # converting both to their canonical boolean forms
        # (using !!) for the comparison.
        #
        is( !! $is_edit,
            !! $request->[3],
            'correct evaluation of edit action'
        );
    }
}

# test _get_file_mtime
{
    my $file_name = "/tmp/functions.t.$$";

    system( 'touch', $file_name ) == 0
        or die "Unable to touch file [$file_name]";

    my $mtime = ( stat($file_name) )[9];

    my $calculated_mtime
        = Socialtext::UsageStats::_get_file_mtime($file_name);

    is( $mtime, $calculated_mtime, "$file_name has correct mtime" );

    # Make sure it handles files that don't exist.

    $mtime = Socialtext::UsageStats::_get_file_mtime('./not/a/real/file');

    ok( ! defined $mtime, 'mtime is undef for non-existent file');
}

# test get_user_last_login
#
# XXX - This knows far too much about the internals of get_user_last_login(),
# but doing it this way means that (a) it can be tested at all, and (b) doesn't
# require a live NLW environment.
{
    # Fake a Socialtext root and .trail file inside /tmp.
    #
    my $socialtext_root = "/tmp/st-userstats-test.$$";
    my $user_id = 'usagestats-testuser@example.com';
    my $workspace = 'usagestats-testws';
    my $file_dir  = "$socialtext_root/user/$workspace/$user_id";
    my $file_name = "$file_dir/.trail";

    # Create the chain of directories that holds .trail.
    #
    system( 'mkdir', '-p', $file_dir) == 0
        or die "Unable to create dir [$file_dir]";

    # Create the .trail file, with the proper timestamp.
    #
    system( 'touch', $file_name ) == 0
        or die "Unable to touch file [$file_name]";

    # Build a formatted timestamp, for comparison with what
    # get_user_last_login() returns.
    #
    my $mtime_formatted = Date::Format::time2str(
        '%Y-%m-%d',
        ( stat $file_name )[9]
    );

    my $last_login = Socialtext::UsageStats::get_user_last_login(
        $socialtext_root,
        $workspace,
        $user_id,
    );

    is( $mtime_formatted, $last_login, 'correct last login' );

    unlink($file_name);

    # Make sure no last login is returned for a user without
    # a .trail file.
    #
    $last_login = Socialtext::UsageStats::get_user_last_login(
        $socialtext_root,
        'admin',
        'devnull1@socialtext.com'
    );

    ok( !defined($last_login),
        'no last login for devnull1@socialtext.com in admin workspace'
    );

}


# test parse_apache_log_line
{
    my $log_line = <<'END_TEXT';
127.0.0.1 - devnull1@socialtext.com [12/Oct/2005:13:18:02 -0700] "GET /admin/index.cgi?workspace_navigation HTTP/1.1" 200 23287 "http://www.example.com/" "Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.7.10) Gecko/20050716 Firefox/1.0.6" 12918 3
END_TEXT

    my $log = Socialtext::UsageStats::parse_apache_log_line($log_line);

    is( $log->{host},       '127.0.0.1',                                'correct host' );
    is( $log->{user},       'devnull1@socialtext.com',                  'correct user' );
    is( $log->{timestamp},  '12/Oct/2005:13:18:02',                     'correct timestamp' );
    is( $log->{method},     'GET',                                      'correct method' );
    is( $log->{url},        '/admin/index.cgi?workspace_navigation',    'correct url' );
    is( $log->{status},     '200',                                      'correct status' );
    is( $log->{referer},    'http://www.example.com/',                  'correct referer' );

}

# test _read_log_files_for_active_users
# 
# (I'm doing these together, since they depend on similar setup.)
{
    # Create a fake logfile that can be fed to get_active_users_from_logs().
    # The "file" contains mostly edit lines, with a couple of non-edit lines at
    # the top and bottom.
    #
    my $fh = IO::Scalar->new( \ <<'END_TEXT' );
127.0.0.1 - devnull1@socialtext.com [12/Oct/2005:13:18:02 -0700] "GET /admin/index.cgi?workspace_navigation HTTP/1.1" 200 23287 "http://www.example.com/" "Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.7.10) Gecko/20050716 Firefox/1.0.6" 12918 3
127.0.0.1 - devnull1@socialtext.com [12/Oct/2005:13:18:02 -0700] "GET /admin/index.cgi?workspace_navigation HTTP/1.1" 200 23287 "http://www.example.com/" "Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.7.10) Gecko/20050716 Firefox/1.0.6" 12918 3
127.0.0.1 - one@socialtext.com [12/Oct/2005:13:18:02 -0700] "POST /admin/index.cgi HTTP/1.1" 302 23287 "http://www.example.com/" "Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.7.10) Gecko/20050716 Firefox/1.0.6" 12918 3
127.0.0.1 - one@socialtext.com [12/Oct/2005:13:18:02 -0700] "POST /admin/index.cgi HTTP/1.1" 302 23287 "http://www.example.com/" "Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.7.10) Gecko/20050716 Firefox/1.0.6" 12918 3
127.0.0.1 - two@socialtext.com [12/Oct/2005:13:18:02 -0700] "POST /admin/index.cgi HTTP/1.1" 302 23287 "http://www.example.com/" "Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.7.10) Gecko/20050716 Firefox/1.0.6" 12918 3
127.0.0.1 - two@socialtext.com [12/Oct/2005:13:18:02 -0700] "POST /admin/index.cgi HTTP/1.1" 302 23287 "http://www.example.com/" "Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.7.10) Gecko/20050716 Firefox/1.0.6" 12918 3
127.0.0.1 - three@socialtext.com [12/Oct/2005:13:18:02 -0700] "POST /admin/index.cgi HTTP/1.1" 302 23287 "http://www.example.com/" "Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.7.10) Gecko/20050716 Firefox/1.0.6" 12918 3
127.0.0.1 - three@socialtext.com [12/Oct/2005:13:18:02 -0700] "POST /admin/index.cgi HTTP/1.1" 302 23287 "http://www.example.com/" "Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.7.10) Gecko/20050716 Firefox/1.0.6" 12918 3
127.0.0.1 - three@socialtext.com [12/Oct/2005:13:18:02 -0700] "POST /admin/index.cgi HTTP/1.1" 302 23287 "http://www.example.com/" "Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.7.10) Gecko/20050716 Firefox/1.0.6" 12918 3
127.0.0.1 - four@socialtext.com [12/Oct/2005:13:18:02 -0700] "POST /admin/index.cgi HTTP/1.1" 302 23287 "http://www.example.com/" "Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.7.10) Gecko/20050716 Firefox/1.0.6" 12918 3
127.0.0.1 - devnull1@socialtext.com [12/Oct/2005:13:18:02 -0700] "GET /admin/index.cgi?workspace_navigation HTTP/1.1" 200 23287 "http://www.example.com/" "Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.7.10) Gecko/20050716 Firefox/1.0.6" 12918 3
127.0.0.1 - devnull1@socialtext.com [12/Oct/2005:13:18:02 -0700] "GET /admin/index.cgi?workspace_navigation HTTP/1.1" 200 23287 "http://www.example.com/" "Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.7.10) Gecko/20050716 Firefox/1.0.6" 12918 3
END_TEXT

    my $active_users_ref = Socialtext::UsageStats::get_active_users_from_logs($fh);

    is_deeply(
        $active_users_ref, {
            'one@socialtext.com'    => 2,
            'two@socialtext.com'    => 2,
            'three@socialtext.com'  => 3,
            'four@socialtext.com'   => 1,
        },
        'got correct counts for active users'
    );
}

# test _get_user_login_details
#
# XXX:
# - Should these be live tests, since they depend on an NLW environment?
# - The exact number of users and their details depend on the configuration
#   of the test NLW environment.
{
    # Mock some active users.
    #
    my $active_users_ref = {
        'devnull1@socialtext.com' => 123,
    };

    # The current implementation of _get_user_login_details() doesn't depend on
    # a defined socialtext root, although this does mean that
    # get_user_last_login (called within _get_user_login_details) won't return
    # anything worthwhile.
    #
    my $socialtext_root = '';

    my ($user_count, $detail) = Socialtext::UsageStats::_get_user_login_details(
        '', # socialtext root
        $active_users_ref
    );
    
    # XXX - Don't like this. I'd rather check for a specific count...
    # but see comment above re: live tests.
    #
    ok($user_count > 0, 'at least one user account exists');

    like($detail,
        qr{
            ^                          # start of line within string
            \|\s+                      # delimiter and whitespace
            devnull1\@socialtext\.com  # expected user_id
            \s+\|\s+                   # whitespace and delimiter
            [^|]+                      # any workspace name
            \s+\|\s+                   # whitespace and delimiter
            [^|]+                      # any last login (or "never")
            \s+\|\s+                   # whitespace and delimiter
            yes                        # active is "yes"
            \s+\|                      # whitespace and delimiter
            $                          # end of line within string
        }imsx,
        'user login detail contains expected detail line'
    );

    unlike($detail,
        qr{
            ^                          # start of line within string
            \|\s+                      # delimiter and whitespace
            devnull2\@socialtext\.com  # expected user_id
            \s+\|\s+                   # whitespace and delimiter
            [^|]+                      # any workspace name
            \s+\|\s+                   # whitespace and delimiter
            [^|]+                      # any last login (or "never")
            \s+\|\s+                   # whitespace and delimiter
            yes                        # active is "yes"
            \s+\|                      # whitespace and delimiter
            $                          # end of line within string
        }imsx,
        'user login detail does not contain unexpected detail line'
    );
}


