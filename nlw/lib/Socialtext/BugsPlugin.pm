# @COPYRIGHT@
package Socialtext::BugsPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use Class::Field qw( const );
use File::Path ();
use Socialtext::AppConfig;
use Socialtext::EmailSender;
use Storable ();
use Sys::Hostname ();
use YAML ();

$Storable::forgive_me = 42;

sub class_id { 'bugs' }
const cgi_class => 'Socialtext::Bugs::CGI';

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(action => 'bugs_report');
    $registry->add(action => 'bugs_dump');
}

sub bugs_report {
    my $self = shift;
    return $self->save_comment if $self->cgi->Button eq 'Report Bug';
    return $self->ignore_bug if $self->cgi->Button eq 'Ignore Bug';
    my $bug_id = $self->save_report(@_);
    return $self->hub->template->process('bugs_content.html',
        bug_id => $bug_id,
    );
}

sub bugs_dump {
    my $self = shift;
    my $dump = eval { YAML::Dump($self->retrieve($self->cgi->bug_id)) } || $@;
    return $self->hub->template->process('bugs_dump.html',
       content_pane => 'bugs_dump.html',
       display_title => 'Bug Dump',
       dump => $dump,
    );
}

sub save_report {
    my $self = shift;
    no warnings 'once';
    my $error_message = shift;
    my $bug_id = "$^T$$";
    my $report = {
        _05_comment => 'SYSTEM REPORTED',
        _10_msg => $error_message,
        _15_workspace => $self->hub->current_workspace->name,
        _20_version => $Socialtext::VERSION,
        _25_tag => $Socialtext::TAG,
        _30_user_id => $self->hub->current_user->username,
        _35_url => $self->hub->cgi->full_uri_with_query,
        _37_referer => $ENV{HTTP_REFERER},
        _38_useragent => $ENV{HTTP_USER_AGENT},
        _40_cgi => {$self->cgi->all},
    };
    $self->store($report, $bug_id);
    $self->send_email($report);
    return $bug_id;
}

sub save_comment {
    my $self = shift;
    my $bug_id = $self->cgi->bug_id;
    my $report = $self->retrieve($bug_id);
    my $comment = $self->cgi->user_comment;
    $comment =~ s/\r//g;
    $report->{_05_comment} = $comment;
    $self->store($report, $bug_id);
    $self->send_email($report);
    $self->redirect('');
}

sub ignore_bug {
    my $self = shift;
    $self->delete_bug_file($self->cgi->bug_id);
    $self->redirect('');
}

sub store {
    my $self = shift;
    my ($report, $bug_id) = @_;
    my $dirpath = $self->plugin_directory;
    File::Path::mkpath( $dirpath, 0, 0755 )
        unless -d $dirpath;
    my $filepath = join '/', $dirpath, $bug_id;
    unlink $filepath;
    Storable::store($report, $filepath);
}

sub send_email {
    my $self = shift;
    return if Socialtext::AppConfig->is_appliance;
    return unless Socialtext::AppConfig->email_errors_to;

    my $report = shift;
    delete $report->{_90_hub};
    my $workspace = $report->{_15_workspace};
    my $user = eval { $self->hub->current_user };
    my $hostname = Sys::Hostname::hostname();
    my ($error) = $report->{_10_msg} =~ /([^\n]+)(?:\n|$)/;

    my $subject = "Application error";
    $subject .= " in $workspace" if defined $workspace;
    $subject .= " for " . $user->email_address if defined $user;
    $subject .= " on $hostname: $error";

    my $dump = eval { YAML::Dump($report) } || $@;

    Socialtext::EmailSender->send(
        from      => 'noreply@socialtext.com',
        to        => Socialtext::AppConfig->email_errors_to,
        subject   => $subject,
        text_body => $dump,
    );
}

sub retrieve {
    my $self = shift;
    my ($bug_id) = @_;
    my $dirpath = $self->plugin_directory;
    my $filepath = join '/', $dirpath, $bug_id;
    return Storable::retrieve($filepath);
}

sub delete_bug_file {
    my $self = shift;
    my $bug_id = shift;
    my $dirpath = $self->plugin_directory;
    my $filepath = join '/', $dirpath, $bug_id;
    unlink $filepath;
}

package Socialtext::Bugs::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'Button';
cgi 'bug_id' => '-clean_path';
cgi 'user_comment';

1;

