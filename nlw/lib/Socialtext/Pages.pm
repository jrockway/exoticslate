# @COPYRIGHT@
package Socialtext::Pages;
use strict;
use warnings;

use base 'Socialtext::Base';

use Class::Field qw( const field );
use Email::Valid;
use Socialtext::File;
use Socialtext::Page;
use Socialtext::Paths;
use Socialtext::WeblogUpdates;
use Readonly;
use Socialtext::User;
use Socialtext::Validate qw( validate DIR_TYPE );
use Socialtext::Workspace;

sub class_id { 'pages' }
const class_title => 'NLW Pages';

field current => 
      -init => '$self->new_page($self->current_id)';

=head2 $page->all()

Returns a list of all page objects that exist in the current workspace.
This includes deleted pages.

=cut
sub all {
    my $self = shift;
    map {$self->new_page($_)} $self->all_ids;
}

=head2 $pages->all_active()

Returns a list of all active page objects that exist in the current
workspace and are active (not deleted).

=cut
sub all_active {
    my $self = shift;
    grep {$_->active} $self->all();
}

sub all_ids {
    my $self = shift;
    grep { not /^\./ } Socialtext::File::all_directory_directories(
        Socialtext::Paths::page_data_directory(
            $self->hub->current_workspace->name
        )
    );
}

=head2 $pages->all_ids_newest_first()

Returns a list of all the directories in page_data_directory,
sorted in reverse date order. Skips symlinks.

=cut

sub all_ids_newest_first {
    my $self = shift;
    my $path = Socialtext::Paths::page_data_directory(
        $self->hub->current_workspace->name );

    my @files;
    foreach my $page_id ( $self->all_ids ) {
        my $file = Socialtext::File::catfile( $path, $page_id, 'index.txt' );
        next unless -f $file;
        push @files, [ $page_id, ( stat _ )[9] ];
    }

    return map { $_->[0] } sort { $b->[1] <=> $a->[1] } @files;
}

sub all_newest_first {
    my $self = shift;
    map {$self->new_page($_)} 
      $self->all_ids_newest_first;
}

sub all_since {
    my $self = shift;
    my ($minutes, $active_only) = @_;
    my @pages_since;
    for my $page_id ($self->all_ids_newest_first) {
        my $page = $self->new_page($page_id);
        next if $active_only && ! $page->active;
        last if $page->age_in_minutes > $minutes;
        push @pages_since, $page;
    }
    return @pages_since;
}

sub random_page {
    my $self = shift;
    my @page_ids = $self->all_ids;
    my $random_page;

    while (@page_ids) {
        my $index = int( rand(@page_ids) );
        my $id    = $page_ids[$index];
        my $page  = $self->new_page($id);

        # Don't repeat inactive pages
        if ( $page->active ) {
            $random_page = $page;
            last;
        }
        splice @page_ids, $index, 1;
    }

    return $random_page;
}


sub name_to_title { $_[1] }

sub id_to_uri { $_[1] }

# REVIEW: Probably a class Method
sub title_to_uri {
    my $self = shift;
    $self->uri_escape(shift);
}

sub show_mouseover {
    my $self = shift;
    return $self->{show_mouseover} if defined $self->{show_mouseover};
    $self->{show_mouseover} = 
      $self->hub->preferences->new_for_user( $self->hub->current_user->email_address )->mouseover_length->value;
}

sub title_to_disposition {
    my $self = shift;
    my $page_name = shift;
    my $page = $self->new_from_name($page_name);

    return unless $page;

    return ('title="[click to create page]" class="incipient"', 
            $self->uri_escape($page_name),
           ) unless $page->active;

    my $disposition = '';
    if ( $self->show_mouseover && $self->hub->action eq 'display' ) {
        my $preview = $page->preview_text;
        $disposition = qq|title="$preview"|;
    }

    return ($disposition, $page->uri);
}

sub current_id {
    my $self = shift;
    my $page_name = 
      $self->hub->cgi->page_name ||
      $self->hub->current_workspace->title;
    Socialtext::Page->name_to_id($page_name);
}

sub unset_current {
    my $self = shift;
    $self->{current} = undef;
}

sub new_page {
    my $self = shift;
    Socialtext::Page->new(hub => $self->hub, id => shift);
}

sub new_from_name {
    my $self = shift;
    my $page_name = shift;
    my $id = Socialtext::Page->name_to_id($page_name);
    my $page = $self->new_page($id);
    return unless $page;
    $page->title($self->name_to_title($page_name));
    return $page;
}

# This avoids problems in new_from_name wherein the title gets
# set to the URI, not the Subject of the page, even if the page
# already exists.
sub new_from_uri {
    my $self = shift;
    my $uri  = shift;

    my $page = Socialtext::Page->new(
        hub => $self->hub,
        id  => Socialtext::Page->name_to_id($uri),
    );

    die("Invalid page id: $uri") unless $page;

    my $return_id = Socialtext::Page->name_to_id($page->title);
    $page->title( $uri ) unless $return_id eq $uri;

    return $page;
}

sub new_page_from_any {
    my $self = shift;
    my $any = shift;
    my $page = Socialtext::Page->new(hub => $self->hub, id => '_');
    $page->metadata($page->new_metadata('_'));
    $page->load($any);
    $page->id(Socialtext::Page->name_to_id($page->metadata->Subject));
    return $page;
}

sub new_page_from_file {
    my $self = shift;
    $self->new_page_from_any(shift);
}

sub new_page_title {
    my $self = shift;
    my @months = qw(January February March April May June
        July August September October November December
    );

    my ($sec, $min, $hour, $mday, $mon) = 
      gmtime(time + $self->hub->timezone->timezone_seconds);

    my $ampm = 'am';
    $ampm = 'pm'  if ($hour > 11);
    $hour -= 12 if ($hour > 12);
    $hour = 12 if ($hour == 0);

    my $user = $self->hub->current_user;

    my $title =
        sprintf("%s, %s %s, %d:%02d$ampm", 
                $user->best_full_name,
                $months[$mon], $mday, $hour, $min
               );

    my $current_workspace = $self->hub->current_workspace->name;

    my $x = 2;
    while ( $self->page_exists_in_workspace( $title, $current_workspace ) ) {
        $title =~ s/(?: - \d+)|\z$/ - $x/;
        $x++;
    }

    return $title;
}

=head2 create_new_page

Create a "new page". That is, a page with a title that is automaticall
generated. A scabrous thing, but necessary in the current UI.

Returns a L<Socialtext::Page> object.

=cut
sub create_new_page {
    my $self = shift;

    # See comment in display() about using this error_type.
    $self->hub->require_permission(
        permission_name => 'edit',
        error_type      => 'login_to_edit',
    );

    my $page = $self->new_from_name( $self->new_page_title );

    return $page;
}

sub page_exists_in_workspace {
    my $self = shift;
    my $page_title     = shift;
    my $workspace_name = shift;

    my $main = Socialtext->new();
    $main->load_hub(
        current_user      => Socialtext::User->SystemUser(),
        current_workspace => Socialtext::Workspace->new( name => $workspace_name ),
    );
    $main->hub()->registry()->load();

    my $target_page = $main->hub->pages->new_from_name($page_title);
    return ($target_page->metadata->Revision and $target_page->active);
}

my $semaphore = {}; # for loop prevention
sub html_for_page_in_workspace {
    my $self = shift;
    my $page_id        = shift;
    my $workspace_name = shift;
    my $hub = $self->hub;

    if ( $workspace_name ne $self->hub->current_workspace->name ) {
        my $main = Socialtext->new();
        $main->load_hub(
            current_user      => Socialtext::User->SystemUser(),
            current_workspace =>
                Socialtext::Workspace->new( name => $workspace_name ),
        );
        my $original_hub = $hub;
        $hub = $main->hub();
        $hub->registry()->load();

        my $link_dictionary = $original_hub->viewer->link_dictionary->clone;
        $link_dictionary->free($link_dictionary->interwiki);
        $hub->viewer->link_dictionary($link_dictionary);
    }

    $hub->current_user( $self->hub->current_user );

    my $semaphore_string = $hub->current_workspace->workspace_id . ":$page_id";
    return '' if ( exists $semaphore->{$semaphore_string} );
    $semaphore->{$semaphore_string}++;

    my $target_page = $hub->pages->new_page($page_id);
    my $html = $target_page->to_html_or_default;

    delete $semaphore->{$semaphore_string};

    return $html;
}

{
    Readonly my $spec => {
        directory => DIR_TYPE,
        hub       => { isa => 'Socialtext::Hub' },
    };

    sub AddPagesFromDirectory {
        my $class = shift;
        my %p = validate( @_, $spec );

        my $hub = $p{hub};

        opendir PAGE_FILES, $p{directory}
            or die "Couldn't open directory $p{directory}:\n$!";

        while ( my $page_file = readdir PAGE_FILES ) {
            my $page_path = Socialtext::File::catfile( $p{directory}, $page_file );

            next unless -f $page_path;

            my $source_page = $hub->pages->new_page_from_file($page_path);
            my $subject     = $source_page->metadata->Subject;
            $subject = $hub->current_workspace->title
                if $subject eq 'Top page';
            my $category          = $source_page->metadata->Category;
            my $content           = $source_page->content;
            my $content_formatted = $hub->template->process(
                \$content,
                workspace_title => $hub->current_workspace->title,
            );

            my $page = $hub->pages->new_from_name($subject);
            $page->content($content_formatted);
            my $metadata = $page->new_metadata($subject);
            $metadata->Subject($subject);
            $metadata->Category($category);
            $metadata->Revision(0);
            $page->metadata($metadata);
            $page->metadata->update( user => $hub->current_user );
            $page->store( user => $hub->current_user );

            $hub->category->save(@$category);
            $hub->category->index->update(    #XXX refactor
                $page->id, $metadata->Date,
                [],        $category,
            );
        }
    }
}

################################################################################
package Socialtext::Pages::Formatter;

use base 'Socialtext::Formatter';

sub wafl_classes {
    my $self = shift;
    map {
        s/^File$/Socialtext::Pages::Formatter::File/;
        s/^Image$/Socialtext::Pages::Formatter::Image/;
        $_
    } $self->SUPER::wafl_classes(@_);
}

################################################################################
package Socialtext::Pages::Formatter::Image;

use Socialtext::Formatter::WaflPhrase;
use base 'Socialtext::Formatter::Image';

sub html {
    my $self = shift;
    my ($workspace_name, $page_title, $image_name, $page_id, $page_uri) = 
      $self->parse_wafl_reference;
    return $self->syntax_error unless $image_name;
    return qq{<img src="cid:$image_name" />};
}

1;

