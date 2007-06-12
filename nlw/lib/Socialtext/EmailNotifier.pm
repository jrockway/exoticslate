# @COPYRIGHT@
package Socialtext::EmailNotifier;

use strict;
use warnings;

our $VERSION = '0.01';

use Fcntl ':flock';
use Readonly;
use Socialtext::AppConfig;
use Socialtext::EmailSender;
use Socialtext::String;
use Socialtext::Validate qw( validate PLUGIN_TYPE ARRAYREF_TYPE SCALAR_TYPE HASHREF_TYPE);

=head1 SYNOPSIS

    my $email_notifier = Socialtext::EmailNotifier->new(
                    plugin => $plugin_obj,
    );

=head1 DESCRIPTION

An object used for shared email notification methods.

=cut

{
    Readonly my $spec => {
        plugin           => PLUGIN_TYPE,
        notify_frequency => SCALAR_TYPE,
    };

    sub new {
        my $class = shift;
        my %p     = validate( @_, $spec );

        return bless {
            plugin_obj              => $p{plugin},
            notify_frequency_string => $p{notify_frequency},
        };
    }
}

{
    Readonly my $spec => {
        user          => HASHREF_TYPE,
        pages         => ARRAYREF_TYPE,
        from          => SCALAR_TYPE,
        subject       => SCALAR_TYPE,
        vars          => HASHREF_TYPE,
        text_template => SCALAR_TYPE,
        html_template => SCALAR_TYPE,
    };

    sub send_notifications {
        my $self = shift;
        my %p    = validate( @_, $spec );

        my $renderer = Socialtext::TT2::Renderer->instance();

        $p{vars}{appconfig} = Socialtext::AppConfig->instance();

        my $text_body = $renderer->render(
            template => $p{text_template},
            vars     => $p{vars},
        );

        my $html_body = $renderer->render(
            template => $p{html_template},
            vars     => $p{vars},
        );

        Socialtext::EmailSender->send(
            from      => $p{from},
            to        => $p{user}->name_and_email,
            subject   => $p{subject},
            text_body => $text_body,
            html_body => $html_body,
        );

        Socialtext::File::update_mtime( $p{user}->{stamp_file} );
    }
}

{
    my %SortSubs = (
        chrono  => sub { $b->age_in_seconds <=> $a->age_in_seconds },
        reverse => sub { $a->age_in_seconds <=> $b->age_in_seconds },
        default => sub { $a->id cmp $b->id },
    );

    sub _sort_pages_for_user {
        my $self  = shift;
        my $user  = shift;
        my $pages = shift;
        my $prefs = shift;

        my $sort_order = $prefs->sort_order->value;

        my $sort_sub =
              $sort_order && $SortSubs{$sort_order}
            ? $SortSubs{$sort_order}
            : $SortSubs{default};

        return [
            sort $sort_sub grep { $_->age_in_minutes <= $user->{last_time} }
                @$pages ];
    }
}

sub try_acquire_lock {
    my $self     = shift;
    my $lockfile = $self->_maybe_create_lockfile;
    $self->{plugin_obj}->lock_handle( IO::File->new($lockfile) )
        or die "open $lockfile: $!";
    return flock $self->{plugin_obj}->lock_handle, LOCK_EX | LOCK_NB;
}

sub release_lock {
    my $self = shift;
    flock $self->{plugin_obj}->lock_handle, LOCK_UN
        or die "unlock " . $self->lockfile . ": $!";
    $self->{plugin_obj}->lock_handle->close;
    $self->{plugin_obj}->lock_handle(undef);
}

sub _maybe_create_lockfile {
    my $self     = shift;
    my $lockfile = $self->lockfile;

    unless ( -e $lockfile ) {
        my $tmp_lockfile = "$lockfile.$$";
        my $tmp_handle   = IO::File->new("> $tmp_lockfile")
            or die "create $tmp_lockfile: $!";
        $tmp_handle->close;

        # This will fail if somebody else has already created $lockfile, but
        # that's what we want.
        link $tmp_lockfile, $lockfile;
        unlink $tmp_lockfile
            or die "unlink $tmp_lockfile: $!";

        # One way or another, $lockfile should exist by now.
        die "$lockfile does not exist!" unless -e $lockfile;
    }
    return $lockfile;
}

sub lockfile {
    my $self = shift;
    $self->{plugin_obj}->plugin_directory . '/lock';
}

sub should_notify {
    my $self = shift;
    return if $self->_run_recently;
    my $ready_users = [ grep { $self->_user_ready($_) }
            $self->{plugin_obj}->hub->current_workspace->users->all ];
    return unless @$ready_users;

    my $all_pages = $self->_get_all_pages($ready_users);
    return unless @$all_pages;

    return ( $ready_users, $all_pages );
}

sub _run_recently {
    my $self       = shift;
    my $stamp_file = $self->run_stamp_file;

    Socialtext::File::update_mtime($stamp_file)
        unless -f $stamp_file;
    my $string             = $self->{notify_frequency_string};
    my $smallest_frequency = $self->{plugin_obj}->$string->choices->[2];
    my $last_time          = ( $self->file_age($stamp_file) / 60 );
    return 1 if $last_time < $smallest_frequency;

    Socialtext::File::update_mtime($stamp_file);
    return 0;
}

sub run_stamp_file {
    my $self = shift;
    $self->{plugin_obj}->plugin_directory . "/last_run_stamp";
}

sub _user_ready {
    my $self = shift;
    my $user = shift;
#    return unless defined $user->email_address && length $user->email_address;
    return
      unless defined $user->email_address
      && length $user->email_address
      && !$user->requires_confirmation();

    my $prefs = $self->{plugin_obj}
        ->hub->preferences->new_for_user( $user->email_address );
    my $string    = $self->{notify_frequency_string};
    my $frequency = $prefs->{$string}->value;
    return unless ($frequency);

    $user->{stamp_file} = $self->_stamp_file_for_user($user);
    $user->{last_time}  =
        -f $user->{stamp_file}
        ? ( $self->file_age( $user->{stamp_file} ) / 60 )
        : $frequency;
    $user->{last_time} >= $frequency;
}

sub _stamp_file_for_user {
    my $self = shift;
    my $user = shift;

    my $workspace = $self->{plugin_obj}->hub->current_workspace->name;
    my $class_id  = $self->{plugin_obj}->class_id;
    my $user_directory = Socialtext::Paths::user_directory(
        $workspace,
        $user->email_address,
    );
    my $check_name = Socialtext::File::catdir($user_directory, $class_id);

    my $timestamp_filename = Socialtext::File::catfile($check_name, "email_timestamp");

    # REVIEW: The first part of the following conditional will be unnecessary
    # once all of the email_notify files have been migrated to
    # email_notify/email_timestamp.  Once we are certain that this has
    # happened we can use user_plugin_directory in all cases, but for the
    # nonce that doesn't work because user_plugin_directory always tries to
    # create the directory which spawns an app error if there's already a
    # file, and we don't want to lose the information in existing email
    # timestamp files.

    if ( -f $check_name ) {
        my $inter_file = Socialtext::File::catfile($user_directory, "email_timestamp");
        rename ($check_name, $inter_file);
        File::Path::mkpath($check_name);
        rename ($inter_file, $timestamp_filename);
    }
    else {
        File::Path::mkpath ($check_name)
            unless -d $check_name;
    }
    return $timestamp_filename;
}

sub _get_all_pages {
    my $self        = shift;
    my $ready_users = shift;
    my $plugin_obj  = shift;

    my $max_time = 0;
    for my $user (@$ready_users) {
        $max_time = $user->{last_time}
            if defined $user->{last_time} && $user->{last_time} > $max_time;
    }
    return [ grep { !$_->is_system_page() }
            $self->{plugin_obj}->hub->pages->all_since( $max_time, 1 ) ];
}

sub file_age {
    my $self = shift;
    my $file = shift;
    my $mtime = ( stat($file) )[9] || 0;
    return ( time - $mtime );
}

1;
