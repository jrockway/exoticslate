# @COPYRIGHT@
package Socialtext::HitCounterPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use Class::Field qw( const );
use File::CounterFile;
use Socialtext::AppConfig;
use Socialtext::Exceptions qw( data_validation_error );
use Socialtext::File;
use Socialtext::LogParser;
use Socialtext::Paths;
use Socialtext::Helpers;
use Socialtext::l10n qw(loc);

const class_title      => 'Page Statistics';
const cgi_class        => 'Socialtext::PageStats::CGI';

sub class_id { 'hit_counter' }

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(action => 'page_stats');
    $registry->add(action => 'page_stats_index');
}

sub get_page_counter_value {
    my $self = shift;
    my $page = shift;

    my $counter_file = Socialtext::File::catfile(
        $self->_page_counter_dir(
            $self->hub->current_workspace->name, $page
        ),
        'COUNTER'
    );

    return 0 unless -e $counter_file;

    return File::CounterFile->new($counter_file)->value;
}

sub page_stats {
    my $self = shift;

    my $page_id = $self->cgi->page_id;
    my $page = $self->hub->pages->new_page($page_id)
        if defined $page_id && length $page_id;

    unless ( $page && $page->active ) {
        my $error;
        if ( defined $page_id && length $page_id ) {
            $error = loc("The page id you specified ([_1]) was invalid.", $page_id);
        }
        else {
            $error = loc('This action requires a page to be specified.');
        }
        data_validation_error errors => [$error];
    }

    my $title = $page->title;

    my ( $stats, $date ) = $self->_get_page_stats( $page, $self->cgi->date || 'LATEST' );

    $self->screen_template('view/page/stats');

    if ( $stats =~ /No statistics/ ) {
        return $self->render_screen(
            page_id      => $self->hub->pages->current->id,
            display_date => $self->_pretty_date($date),
            error        => loc('No stats for this page yet'),
        );
    }

    return $self->render_screen(
        page_id              => $self->hub->pages->current->id,
        display_date         => $self->_pretty_date($date),
        page_views           => $self->_page_view_stats($stats),
        page_edits           => $self->_page_edit_stats($stats),
        attachment_uploads   => $self->_attachment_upload_stats($stats),
        attachment_downloads => $self->_attachment_download_stats($stats),

        # This has to come _last_ because it depends on previous
        # methods adding entries for totals to the $stats hashref.
        summary_stats => $stats->{TOTAL},
        display_title => $page->title,
    );
}

sub page_stats_index {
    my $self = shift;

    my $page = $self->hub->pages->new_page( $self->cgi->page_id );

    my $counter_dir = $self->_page_counter_dir(
        $self->hub->current_workspace->name,
        $page
    );

    my $title = $page->title;

    unless ( -d $counter_dir ) {
        return $self->render_screen(
            page_id       => $page->id,
            display_title => $title,
            error         => loc('No stats dir for this page'),
        );
    }

    opendir my $dir, $counter_dir
        or die "Cannot read $counter_dir: $!";

    my @reports
        = map { { date => $_, pretty_date => $self->_pretty_date($_) } }
        reverse sort
        grep { !/^\.+$|LATEST|COUNTER/ } readdir $dir;

    unless (@reports) {
        return $self->render_screen(
            page_id       => $page->id,
            display_title => $title,
            error         => loc('No stats for this page'),
        );
    }

    $self->screen_template('view/page/stats_index');
    return $self->render_screen(
        page_id                 => $page->id,
        display_title           => $title,
        page_reports            => \@reports,
    );
}

sub page_has_stats {
    my $self = shift;
    my $page = shift;

    my $counter_dir = $self->_page_counter_dir(
        $self->hub->current_workspace->name,
        $page
    );

    return 0 unless -d $counter_dir;

    opendir my $dir, $counter_dir
        or die "Couldn't open $counter_dir";

    return 1 if grep { !/^\.+$|LATEST|COUNTER/ } readdir $dir;
}

sub _page_counter_dir {
    my $self    = shift;
    my $ws_name = shift;
    my $page    = shift;

    return Socialtext::File::catdir( Socialtext::Paths::plugin_directory($ws_name),
        'counter', $page->id );
}

sub _pretty_date {
    my $self = shift;
    my $date = shift;
    return '' unless defined $date;

    my ($year,$month,$day,$hour,$min,$sec) = $date =~
        m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;

    # REVIEW - this is kind of lame, obviously.
    return $self->hub->timezone->date_local("$year-$month-$day $hour:$min:$sec");
}

sub _get_page_stats {
    my $self = shift;
    my $page = shift;
    my $date = shift;

    my $counter_dir
        = $self->_page_counter_dir( $self->hub->current_workspace->name,
        $page );

    my $stats_file = Socialtext::File::catfile( $counter_dir, $date );

    if ( $date eq 'LATEST' and -l $stats_file ) {
        $date = readlink $stats_file;
    }

    if ( not -e $stats_file ) {
        # We haven't done any stats on this page
        return loc("No statistics yet available for [_1]", $page);
    }
    else {
        my $stats = $self->_read_stats_from_file("$stats_file");
        return ($stats, $date);
    }
}

sub _read_stats_from_file {
    my $self = shift;
    my $file = shift;

    open my $fh, '<', $file
        or die "Cannot read $file: $!";

    my %stats;
    while (<$fh>) {
        my %parsed = Socialtext::LogParser->parse_log_line($_);

        if ( $parsed{action} =~ /PAGE/ ) {
            $stats{ $parsed{action} }{ $parsed{user_id} }{ $parsed{date} }++;
        }
        else {
            $stats{ $parsed{action} }{ $parsed{attachment_id} }{ $parsed{user_id} }{ $parsed{date} }++;
        }
    }

    return \%stats;
}

sub _page_view_stats {
    my $self = shift;
    my $stats = shift;

    return $self->_add_page_info(
        $stats,
        "DISPLAY_PAGE",
        "View",
    );
}

sub _page_edit_stats {
    my $self = shift;
    my $stats = shift;

    return $self->_add_page_info(
        $stats,
        "EDIT_PAGE",
        "Edit",
    );
}

sub _attachment_download_stats {
    my $self = shift;
    my $stats = shift;

    return $self->_add_attachment_info(
        $stats,
        "DOWNLOAD_ATTACHMENT",
        "Download",
    );
}

sub _attachment_upload_stats {
    my $self = shift;
    my $stats = shift;

    return $self->_add_attachment_info(
        $stats,
        "UPLOAD_ATTACHMENT",
        "Upload",
    );
}

sub _add_page_info {
    my $self = shift;
    my $stats      = shift;
    my $type       = shift;
    my $action     = shift;

    my @users = $self->_users_for_stat( $stats->{$type} );

    if ( @users == 0 ) {
        $stats->{TOTAL}{$type} = 0;
        return [];
    }

    my @rows;
    foreach my $user ( sort { lc $a->{name} cmp lc $b->{name} } @users ) {
        my @dates = sort ( keys %{ $stats->{$type}{ $user->{key} } } );
        my $total = $#dates + 1;
        my $last  = $dates[$#dates];

        push @rows, { user => $user->{name}, date => $last, total => $total };

        $stats->{TOTAL}{$type} += $total;
    }

    return \@rows;
}

sub _add_attachment_info {
    my $self = shift;
    my $stats            = shift;
    my $type             = shift;
    my $action           = shift;

    my @attachments = keys %{ $stats->{$type} };
    unless (@attachments) {
        $stats->{TOTAL}{$type} = 0;
        return [];
    }

    my @rows;
    foreach my $attachment (@attachments) {
        my $print            = $attachment;
        my $total_for_attach = 0;

        my @users = $self->_users_for_stat( $stats->{$type}{$attachment} );
        foreach my $user ( sort { lc $a->{name} cmp lc $b->{name} } @users ) {
            my @dates = sort
                keys %{ $stats->{$type}{$attachment}{ $user->{key} } };
            my $total = $#dates + 1;
            my $last  = $dates[$#dates];

            push @rows, {
                attachment => $print,
                user       => $user->{name},
                date       => $last,
                total      => $total
            };

            $print = '';
            $stats->{TOTAL}{$type} += $total;
            $total_for_attach     += $total;
        }

        push @rows, { subtotal => $total_for_attach };
    }

    return \@rows;
}

sub _users_for_stat {
    my $self = shift;
    my $stat = shift;

    my $ws = $self->hub->current_workspace;
    return map {

        # old stats data has email addresses but new data has user ids
        my $user = /^\d+$/
            ? Socialtext::User->new( user_id       => $_ )
            : Socialtext::User->new( email_address => $_ );

        {
            name => ( $user ? $user->best_full_name( workspace => $ws ) : $_ ),
            key => $_
        };
    } keys %$stat;
}

sub hit_counter_increment {
    my $self = shift;

    return
        unless $self->hub->action eq 'display'
        or $self->hub->action     eq 'display_page';

    my $counter_dir = $self->_page_counter_dir(
        $self->hub->current_workspace->name,
        $self->hub->pages->current
    );

    Socialtext::File::ensure_directory($counter_dir);

    my $c = File::CounterFile->new(
        Socialtext::File::catfile( $counter_dir, 'COUNTER' ) );

    $c->inc;
}

#------------------------------------------------------------------------------#
package Socialtext::PageStats::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'direction';
cgi 'page_id';
cgi 'date';
cgi 'title';

1;

