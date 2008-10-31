# @COPYRIGHT@
package Socialtext::BreadCrumbsPlugin;
use strict;
use warnings;

use base 'Socialtext::Query::Plugin';

use Class::Field qw( const );
use File::Basename ();
use File::Path ();
use Socialtext::AppConfig;
use Socialtext::Pages;
use Socialtext::File;
use Socialtext::Paths;
use Socialtext::l10n qw(loc);

sub class_id { 'breadcrumbs' }
const class_title => 'Recently Viewed';
const cgi_class   => 'Socialtext::BreadCrumbs::CGI';

my $HOW_MANY = 25;

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(action => 'breadcrumbs_html');
    $registry->add(action => 'breadcrumbs_list');
}

sub display_as_box {
    my $self = shift;
    my $p = $self->new_preference('display_as_box');
    $p->query(loc('Display \"[_1]\" side pane box?',$self->class_title) );
    $p->default(1);
    return $p;
}

sub how_many {
    my $self = shift;
    my $p = $self->new_preference('how_many');
    $p->query(loc('How many pages to show in side pane box?'));
    $p->type('pulldown');
    my $choices = [
        3 => 3,
        5 => 5,
        7 => 7,
        10 => 10,
        15 => 15,
    ];
    $p->choices($choices);
    $p->default(7);
    return $p;
}

sub box_on {
    my $self = shift;
    $self->preferences->display_as_box->value;
}

sub breadcrumbs_list {
    my $self = shift;

    my %sortdir = %{ $self->sortdir };

    $self->display_results(
        \%sortdir,
        display_title => loc('Recently Viewed Pages'),
        unplug_uri    => "?action=unplug;breadcrumbs=1",
        unplug_phrase => loc('Click this button to save recently viewed pages to your computer for offline use.'),
        hide_sort_widget => 1,
    );
}

# Don't use a cached result since the set always quite small.
sub read_result_set { return $_[0]->default_result_set; }
sub write_result_set { 1 }

sub default_result_set {
    my $self = shift;
    $self->result_set($self->new_result_set);
    $self->push_result($_) for ($self->breadcrumb_pages());
    return $self->result_set;
}

sub breadcrumb_pages {
    my $self        = shift;
    my $trail_parts = $self->_load_trail;
    my @pages;
    foreach my $page_name (@$trail_parts) {
        my $page = $self->hub->pages->new_from_name($page_name);
        next unless $page->active;
        push @pages, $page;
    }
    return @pages;
}

sub new_result_set {
    my $self = shift;
    my $rs = $self->SUPER::new_result_set();
    $rs->{predicate} = 'action=breadcrumbs_list';
    return $rs;
}

sub breadcrumbs_html {
    my $self = shift;
    $self->template_process('breadcrumbs_box_filled.html',
        breadcrumbs => $self->get_crumbs,
    );
}

sub drop_crumb {
    my $self = shift;
    my $page        = shift;
    my $trail_parts = $self->_load_trail;
    my $page_id     = $page->id;

    return unless $page->exists;

    my @parts = grep { Socialtext::Page->name_to_id($_) ne $page_id } @$trail_parts;

    $self->_save_trail( [ $page->title, @parts ] );
}

sub get_crumbs {
    my $self = shift;
    my $trail_parts = $self->_load_trail;
    my $limit       = $HOW_MANY;

    splice @$trail_parts, $limit
        if @$trail_parts > $limit;

    my @crumbs;
    foreach my $page_name (@$trail_parts) {
        my $page = $self->hub->pages->new_from_name($page_name);
        my $pagehash=$page->hash_representation;
        next unless $page->active;
        push @crumbs, {
            page_title => $page->title,
            page_uri   => $page->uri,
            page_full_uri => $pagehash->{page_uri}
        };
    }

    return \@crumbs;
}

sub _load_trail {
    my $self = shift;
    my $filename = $self->_trail_filename();

    my $text = -e $filename
        ? Socialtext::File::get_contents_utf8($filename)
        : '';

    return [split /\n/, $text];
}

sub _save_trail {
    my $self = shift;
    my $trail_parts = shift;

    splice @$trail_parts, $HOW_MANY if @$trail_parts > $HOW_MANY;
    my $trail = join('',map {"$_\n"} @$trail_parts);

    my $filename = $self->_trail_filename;
    my $dir = File::Basename::dirname($filename);
    Socialtext::File::ensure_directory($dir);
    Socialtext::File::set_contents_utf8($filename, $trail);
}

sub _trail_filename {
    my $self = shift;
    return Socialtext::File::catfile(
            Socialtext::Paths::user_directory(
                $self->hub->current_workspace->name,
                $self->hub->current_user->email_address,
            ),
            '.trail'
    );
}

######################################################################
package Socialtext::BreadCrumbs::CGI;
       
use base 'Socialtext::Query::CGI';
use Socialtext::CGI qw( cgi );
1;
