# @COPYRIGHT@
package Socialtext::EmailNotifyPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use Class::Field qw( const field );
use Fcntl ':flock';
use Socialtext::AppConfig;
use Socialtext::File;
use Socialtext::Paths;
use Socialtext::EmailNotifier;
use Socialtext::l10n qw( loc loc_lang system_locale );

sub class_id { 'email_notify' }
const class_title => loc('Email Notification');
field abstracts => [];
field 'lock_handle';
field notify_requested => 0;

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(preference => $self->notify_frequency);
    $registry->add(preference => $self->sort_order);
    $registry->add(preference => $self->links_only);
}

sub notify_frequency {
    my $self = shift;
    my $p = $self->new_preference('notify_frequency');
    $p->query(loc('How often would you like to receive email updates?'));
    $p->type('pulldown');
    my $choices = [
        0 => loc('Never'),
        1 => loc('Every Minute'),
        5 => loc('Every 5 Minutes'),
        15 => loc('Every 15 Minutes'),
        60 => loc('Every Hour'),
        360 => loc('Every 6 Hours'),
        1440 => loc('Every Day'),
        4320 => loc('Every 3 Days'),
        10080 => loc('Every Week'),
    ];
    $p->choices($choices);
    $p->default(1440);
    return $p;
}

sub sort_order {
    my $self = shift;
    my $p = $self->new_preference('sort_order');
    $p->query(loc('What order would you like the updates to be sorted?'));
    $p->type('radio');
    my $choices = [
        chrono => loc('Chronologically (Oldest First)'),
        reverse => loc('Reverse Chronologically'),
        name => loc('Page Name'),
    ];
    $p->choices($choices);
    $p->default('chrono');
    return $p;
}

sub links_only {
    my $self = shift;
    my $p = $self->new_preference('links_only');
    $p->query(loc('What information about changed pages do you want in email digests?'));
    $p->type('radio');
    my $choices = [
        condensed => loc('Page name and link only'),
        expanded => loc('Page name and link, plus author and date'),
    ];
    $p->choices($choices);
    $p->default('expanded');
    return $p;
}

#------------------------------------------------------------------------------#
sub maybe_send_notifications {
    my $self = shift;
    my $page_id = shift;

    return unless $self->hub->current_workspace->email_notify_is_enabled;

    loc_lang(system_locale());

    my $notifier = Socialtext::EmailNotifier->new(plugin => $self,
                                    notify_frequency => 'notify_frequency');
    return unless $notifier->try_acquire_lock;
    # Don't send any notifications if the triggering page is 
    # a "system" page or if the page hasn't changed within
    # the last hour
    if ($page_id) {
        my $page = $self->hub->pages->new_page($page_id);
        return if $page->is_system_page;
        return unless $page->is_recently_modified;
    }

    my ( $ready_users, $all_pages ) =  $notifier->should_notify;

    $self->hub->log->info( "sending recent changes notifications from "
                        . $self->hub->current_workspace->name );
                    
    my ($from, $subject, $text_template, $html_template) =
                  $self->get_notification_vars;

    for my $user (@$ready_users) {
        my $prefs = $self->hub->preferences->new_for_user(
                $user->email_address);
        my $pages = $notifier->_sort_pages_for_user( $user, $all_pages, $prefs );

        next unless @$pages;
        
        my $include_editor
              = $prefs->links_only->value eq 'condensed' ? 0 : 1;

         my %vars = (
                  user           => $user,
                  workspace      => $self->hub()->current_workspace(),
                  pages          => $pages,
                  include_editor => $include_editor,
                  preference_uri => $self->preference_uri(),
        );

        $notifier->send_notifications( user      => $user, 
                                   pages         => $pages,
                                   from          => $from,
                                   subject       => $subject,
                                   vars          => \%vars,
                                   text_template => $text_template,
                                   html_template => $html_template) if $ready_users;
    }
    $notifier->release_lock;

    # make this testable
    return 1;
}

sub get_notification_vars {
    my $self = shift;
    my $from =
      $self->hub->current_workspace->formatted_email_notification_from_address;

    my $subject =
        loc('Recent Changes In [_1] Workspace', $self->hub->current_workspace->title);

    my $text_template = 'email/recent-changes.txt';
    my $html_template = 'email/recent-changes.html';

    return ($from, $subject, $text_template, $html_template);
}

sub preference_uri {
    my $self = shift;
    return
        $self->hub->current_workspace->uri . 'emailprefs';
}

1;

