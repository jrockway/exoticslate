# @COPYRIGHT@
package Socialtext::HTMLArchive;
use strict;
use warnings;

use File::Basename ();
use File::Copy     ();
use File::Path;
use File::Temp ();
use Socialtext::File;
use Socialtext::Formatter::Parser;
use Socialtext::Validate qw( validate validate_pos SCALAR_TYPE );
use Socialtext::String ();
use Time::Local ();

sub new {
    my $class = shift;
    my %p     = validate( @_, { hub => { can => ['main'] } } );

    return bless \%p, $class;
}

sub create_zip {
    my $self = shift;
    my ($zip_file) = validate_pos( @_, SCALAR_TYPE );

    my $dir = File::Temp::tempdir();

    my $formatter = Socialtext::HTMLArchive::Formatter->new( hub => $self->{hub} );
    $self->{hub}->formatter($formatter);
    my $parser = Socialtext::Formatter::Parser->new(
        table      => $formatter->table,
        wafl_table => $formatter->wafl_table,
    );
    my $viewer = Socialtext::Formatter::Viewer->new(
        hub => $self->{hub},
        parser => $parser,
    );
    $self->{hub}->viewer($viewer);

    for my $page_id ( $self->{hub}->pages->all_ids ) {
        my $page = $self->{hub}->pages->new_page($page_id);
        $page->load;

        # XXX - for the benefit of attachments (why can't we just ask
        # a page what attachments it has?)
        $self->{hub}->pages->current($page);

        my $metadata = $page->metadata;
        my $title    = $metadata->Subject;

        # XXX Is this impervious to revisions (regarding caching)
        my $html = $viewer->process( $page->content );

        # XXX - calling this on display is a hack, but we cannot call
        # it on the hub directly
        my $formatted_page = $self->{hub}->display->template_process(
            'html_archive_page.html',
            html         => $html,
            title        => $title,
            html_archive => $self,
        );

        my $raw_date = $metadata->Date;
        my ( $year, $mon, $mday, $hour, $min, $sec ) =
          ( $raw_date =~ /(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/ );
        my $unix_time =
          Time::Local::timegm( $sec, $min, $hour, $mday, $mon - 1, $year );

        my $file = Socialtext::File::catfile( $dir, "$page_id.htm" );
        open my $fh, '>:utf8', $file
          or die "Cannot write to $file: $!";
        print $fh $formatted_page
          or die "Cannot write to $file: $!";
        close $fh
          or die "Cannot write to $file: $!";
        utime $unix_time, $unix_time, $file
          or die "Cannot run utime on $file: $!";

        for my $att ( @{ $self->{hub}->attachments->all } ) {
            File::Copy::copy(
                $att->full_path => Socialtext::File::catfile( $dir, $att->filename )
            );
        }
    }

    for my $css ( $self->{hub}->skin->css_files ) {
        my $file = Socialtext::File::catfile( $dir, File::Basename::basename($css) );
        File::Copy::copy( $css => $file );
    }

    $zip_file .= '.zip' unless $zip_file =~ /\.zip$/;

    system( 'zip', '-q', '-r', '-j', $zip_file, $dir )
        and die "zip of $dir into $zip_file failed: $!";

    File::Path::rmtree( $dir, 0 );

    return $zip_file;
}

sub css_uris {
    my $self = shift;

    return map { File::Basename::basename($_) } $self->{hub}->skin->css_files;
}

################################################################################
package Socialtext::HTMLArchive::Formatter;

use base 'Socialtext::Formatter';

sub formatter_classes {
    my $self = shift;

    map {
        s/^FreeLink$/Socialtext::HTMLArchive::Formatter::FreeLink/;
        $_
    } $self->SUPER::formatter_classes(@_);
}

sub wafl_classes {
    my $self = shift;

    map {
        s/^File$/Socialtext::HTMLArchive::Formatter::File/;
        s/^Image$/Socialtext::HTMLArchive::Formatter::Image/;
        $_
    } $self->SUPER::wafl_classes(@_);
}

# contains Socialtext::Formatter::FreeLink
use Socialtext::Formatter::Phrase;
# contains Socialtext::Formatter::File
use Socialtext::Formatter::WaflPhrase;

################################################################################
package Socialtext::HTMLArchive::Formatter::FreeLink;

use base 'Socialtext::Formatter::FreeLink';

sub html {
    my $self = shift;

    my $page_title = $self->title;
    my ( $page_disposition, $page_link, $edit_it ) =
      $self->hub->pages->title_to_disposition($page_title);
    $page_link  = $self->uri_escape($page_link);
    $page_title = $self->html_escape($page_title);
    return '<a href="' . qq{$page_link.htm" $page_disposition>$page_title</a>};
}

################################################################################
package Socialtext::HTMLArchive::Formatter::File;

use base 'Socialtext::Formatter::File';

sub html {
    my $self = shift;

    my ( $workspace_name, $page_title, $file_name, $page_id, $page_uri ) =
      $self->parse_wafl_reference;
    return $self->syntax_error unless $file_name;
    my $label = $file_name;
    $label = "[$page_title] $label"
      if $page_title
      and ( $self->hub->pages->current->id ne
        Socialtext::String::title_to_id($page_title) );
    $label = "$workspace_name:$label"
      if $workspace_name
      and ( $self->hub->current_workspace->name ne $workspace_name );
    return qq{<a href="$file_name">$label</a>};
}

################################################################################
package Socialtext::HTMLArchive::Formatter::Image;

use base 'Socialtext::Formatter::Image';

sub html {
    my $self = shift;

    my ( $workspace_name, $page_title, $image_name, $page_id, $page_uri ) =
      $self->parse_wafl_reference;
    return $self->syntax_error unless $image_name;
    return qq{<img src="$image_name" />};
}

1;

