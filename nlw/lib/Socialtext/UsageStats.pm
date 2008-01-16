# @COPYRIGHT@
package Socialtext::UsageStats;

use strict;
use warnings;

use Date::Format; # XXX replace with DateTime
use Email::Simple;
use Email::Send;
use Email::Send::Sendmail;
use Socialtext::User;
use Socialtext::Workspace;

# XXX - Yuck.
$Email::Send::Sendmail::SENDMAIL = '/usr/sbin/sendmail';


our $VERSION = '0.01';

# Done at this level because it's a bit easier to diddle for testing
# XXX - Also yuck.
our $Mail_this_session = 1;

sub get_workspace_from_url {
    my $url = shift;

    my ($workspace) = ($url =~ m{^/([^/]+)/index\.cgi});

    # If someone stuck weird characters in the URL it can cause sadness for
    # st-workspace-view-edit-stats. Clean them out here.
    #
    if ($workspace) {
        $workspace =~ s/[^a-z0-9\-_]//g;
    }

    return $workspace;
}

# REVIEW: This is quite fragile. There are several ways to post
# into a workspace, not all for editing a page. This attempts
# to have page edits, attachment uploads, page deletes, and
# revision restores count as edits. Other stuff not.
#
sub is_edit_action {
    my $method  = shift;
    my $url     = shift;
    my $status  = shift;
    my $referer = shift;

    return (
            $method eq 'POST'
        &&  defined $url
        &&  $url =~ m{^/[^/]+/index\.cgi$}
        &&  defined $status
        &&  $status == 302
        &&  ( ! defined $referer
            || $referer !~ /action=workspaces_unsubscribe/ )
    );
}

sub get_user_last_login {
    my $st_root = shift;
    my $ws_name = shift;
    my $user_id = shift;

    # Consider the modification time of the breadcrumbs trail file
    # to be the last time the user logged in.
    # 
    my $last_login = _get_file_mtime("$st_root/user/$ws_name/$user_id/.trail")
        or return;

    # Return the last login time in YYYY-MM-DD format.
    #
    return Date::Format::time2str( '%Y-%m-%d', $last_login );
}

# REVIEW: There's probably a module to do this for us.
#
sub parse_apache_log_line {
    my $line = shift;

    chomp $line;
    
    my %log_data;
    my @log = split(' ', $line);

    # Load the hash with the appropriate positional fields.
    #
    @log_data{ qw(  host  user  timestamp  method  url  status  referer  )}
        = @log[qw(  0     2     3          5       6    8       10       )];

    # Clean up the fields that need it.
    #
    $log_data{timestamp} =~ s/^\[//; # timestamp and tz offset are bracketed
    $log_data{method}    =~ s/^"//;  # method, url, and protocol are double-quoted
    $log_data{referer}   =~ s/"//g;  # referer is double-quoted

    return \%log_data;
}

# Not using Socialtext::EmailSend because it is a plugin
#
# XXX - not sure what "because it is a plugin" keeps Socialtext::EmailSender
# from being used here. See if the comment is out of date. Note that the comment
# refers to Socialtext::EmailSend (vs. ::EmailSender).
#
sub send_email {
    # REVIEW: Should validate input parameters
    my %p = @_;

    my $email = Email::Simple->create(
        header => [
            From    => $p{from},
            To      => $p{to},
            Subject => $p{subject},
        ],
        body => $p{body},
    );

    if ($Mail_this_session) {
        Email::Send->new( { mailer => 'Sendmail' } )->send($email)
            or warn "unable to send mail to $p{to}: $!\n";
    }
    else {
        print $email->as_string;
    }
}

sub _send_appliance_report_emails {
    # REVIEW: Consider validation here
    my %p = @_;
    $p{date} = Date::Format::time2str( '%Y-%m-%d', time );

    if (@{$p{detail_to}}) {
        _send_detail_report(%p);
    }

    _send_summary_report(%p);
}

sub _send_detail_report {
    my %p = @_;

    my $body = <<"EOF";
Category: usage report blog - detailed

Total user count for $p{hostname}: $p{user_count}
Active user count for $p{hostname}: $p{active_user_count}

| *User Name* | *Workspace* | *Last Login* | *Active?* |
$p{user_details}

Socialtext $p{product_version}
EOF
    send_email(
        from    => 'appliance@' . $p{hostname},
        to      => ( join ', ', @{ $p{detail_to} } ),
        subject => "Socialtext detailed use report: $p{hostname}, $p{date}",
        body    => $body,
    );
}

# XXX duplication with _send_detail_report
sub _send_summary_report {
    my %p = @_;

    my $body = <<"EOF";
Category: usage report blog - summary

Total user count for $p{hostname}: $p{user_count}
Active user count for $p{hostname}: $p{active_user_count}

Socialtext $p{product_version}
EOF
    send_email(
        from    => 'appliance@' . $p{hostname},
        to      => ( join ', ', @{ $p{summary_to} } ),
        subject => "Socialtext summary use report: $p{hostname}, $p{date}",
        body    => $body,
    );
}

sub _get_user_login_details {
    my $socialtext_root = shift;
    my $active_ref      = shift;

    my $user_count  = 0;
    my $detail      = '';

    my $users = Socialtext::User->All();

    # Count the total users, and accumulate details
    # for each user across all workspaces.
    # 
    while ( my $user = $users->next() ) {

        # Count this user in the total user count.
        $user_count++;

        my $username    = $user->username();
        my $workspaces  = $user->workspaces();

        while ( my $ws = $workspaces->next() ) {
            my $ws_name = $ws->name();

            my $last_login = get_user_last_login(
                $socialtext_root,
                $ws_name,
                $user->email_address,
            )
                || 'never';

            my $active = $active_ref->{$username} ? 'yes' : 'no';

            # XXX gather data not strings!
            $detail .= "| $username | $ws_name | $last_login | $active |\n";
        }
    }

    return ($user_count, $detail);
}

sub get_active_users_from_logs {
    my $log_fh = shift;
    
    my $active_users_ref = {}; 

    # parse up the log
    while (my $log_line = <$log_fh>) {
        my $log_ref = parse_apache_log_line($log_line);

        # Skip this line if the request is not successful and 
        # does not have a socialtext user_id (email address).
        #
        # XXX - the user check allows far more than just an email address --
        #       a "word" character anywhere in the string is enough
        #       to pass this check.
        #
        # XXX - Will this cause trouble as we move to non-email-address
        #       user_ids?
        #
        next unless $log_ref->{status} =~ /^[23]/;
        next unless $log_ref->{user} =~ /\w/;

        my $workspace = get_workspace_from_url($log_ref->{url});
        next unless defined($workspace);

        my $action = 'view';
        if ( is_edit_action(
                $log_ref->{method},
                $log_ref->{url},
                $log_ref->{status},
                $log_ref->{referer},
            ) ) {
            $action = 'edit';
        }

        if ( $action eq 'edit' ) {
            $active_users_ref->{ $log_ref->{user} }++;
        }
    }

    return $active_users_ref;
}

sub _get_file_mtime {
    my $file = shift;

    return unless -e $file;

    return ( stat _ )[9];
}

=head1 NAME

Socialtext::UsageStats - A container module for doing statistics in Socialtext

=head1 SYNOPSIS

    use Socialtext::UsageStats;

    my $workspace = Socialtext::UsageStats::get_workspace_from_url($url);
    ...

=head1 DESCRIPTION

This is a starter class that is expected to change. It contains useful
methods for doing statistics on counting users, math on Apache log files,
and things like that. It's a place to lump things until better places
are discovered.

=head1 FUNCTIONS

=head2 appliance_user_report

    appliance_user_report(
        detail_to       => \@detail_to,
        summary_to      => \@summary_to,
        hostname        => $HOSTNAME,
        product_version => $VERSION,
        user_db_file    => $USER_DB_FILE,
    );

Calculate and mail detail and summary reports for appliance usage.

=head2 get_workspace_from_url($url)

Given the path part of a url, return the workspace named in the path,
if any. Return undef otherwise.

=head2 is_edit_action($method, $url, $status, $referer)

Given the method, url response status, and referer of a request, determine if
it was a request that in some way edits a page.

=head2 get_user_last_login($socialtext_root, $workspace, $user_id)

Use the breadcrumbs trail file modification time to determine the
last time a user visited a workspace. Returns time in YYYY-MM-DD
format (as that's how it was used before pulling in here). Should
perhaps do something more generic.

=head2 parse_apache_log_line($log_line)

Takes one line from an Apache log and returns a reference to a
hash of the relevant pieces of data.

=head2 send_email( from => $from, to => $to, subject => $subject, body => $body )

Very simple emailer. As yet, no error handling or validation.
Coming soon to a theater near you.

=head1 AUTHOR

Socialtext, Inc., C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2005 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
