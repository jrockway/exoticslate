package Socialtext::Rest::EventsBase;
# @COPYRIGHT@
use warnings;
use strict;
use base qw(Socialtext::Rest::Collection);

use Class::Field 'field';
use Date::Parse qw/str2time/;

use Socialtext::Events;
use Socialtext::Events::Reporter;
use Socialtext::User;
use Socialtext::Workspace;
use Socialtext::Exceptions;
use Socialtext::AppConfig;
use Socialtext::TT2::Renderer;
use Socialtext::URI;
use Socialtext::JSON qw/encode_json/;

use constant MAX_EVENT_COUNT => 500;
use constant DEFAULT_EVENT_COUNT => 25;

sub allowed_methods { 'GET' }
sub collection_name { loc('Events') }
sub events_auth_method { 'default' }

sub default_if_authorized {
    my $self = shift;
    my $method = shift;
    my $perl_method = shift;

    my $user = $self->rest->user;
    return $self->not_authorized 
        unless ($user && $user->is_authenticated());

    my $event_class = $self->rest->query->param('event_class');
    if (defined $event_class && $event_class eq 'person') {
        return $self->not_authorized 
            unless $user->can_use_plugin('people');
    }

    return $self->$perl_method(@_);
}

sub people_if_authorized {
    my $self = shift;
    my $method = shift;
    my $perl_method = shift;

    my $user = $self->rest->user;
    return $self->not_authorized 
        unless ($user && $user->is_authenticated());

    return $self->not_authorized
        unless $user->can_use_plugin('people');

    return $self->$perl_method(@_);
}

sub if_authorized {
    my $self = shift;
    my $method = $self->events_auth_method;
    if ($method eq 'people') {
        return $self->people_if_authorized(@_);
    }
    elsif ($method eq 'page') {
        return $self->SUPER::if_authorized(@_);
    }
    else {
        return $self->default_if_authorized(@_);
    }
}

sub extract_common_args {
    my $self = shift;

    my @args;

    my $count = $self->rest->query->param('count') || 
                $self->rest->query->param('limit') || DEFAULT_EVENT_COUNT;
    $count = DEFAULT_EVENT_COUNT unless $count =~ /^\d+$/;
    $count = MAX_EVENT_COUNT if ($count > MAX_EVENT_COUNT);
    push @args, count => $count if ($count > 0);

    my $offset = $self->rest->query->param('offset') || 0;
    $offset = 0 unless $offset =~ /^\d+$/;
    push @args, offset => $offset if ($offset > 0);

    my $before = $self->rest->query->param('before') || ''; # datetime
    push @args, before => $before if $before;
    my $after = $self->rest->query->param('after') || ''; # datetime
    push @args, after => $after if $after;

    my $event_class = $self->rest->query->param('event_class');
    push @args, event_class => lc $event_class if $event_class;
    my $action = $self->rest->query->param('action');
    push @args, action => lc $action if $action;

    my $tag_name = $self->rest->query->param('tag_name');
    push @args, tag_name => $tag_name if $tag_name;

    my $actor_id = $self->rest->query->param('actor.id');
    push @args, actor_id => $actor_id if $actor_id;

    return @args
}

sub extract_page_args {
    my $self = shift;

    my @args;
    my $workspace_id = $self->rest->query->param('page.workspace_id');
    if (!$workspace_id || $workspace_id !~ /^\d+$/) {
        my $workspace_name = $self->rest->query->param('page.workspace_name');
        if ($workspace_name) {
            my $ws = Socialtext::Workspace->new(name => $workspace_name);
            unless ($ws) {
                Socialtext::Exception::NoSuchWorkspace->throw(
                    name => $workspace_name );
            }
            $workspace_id = $ws->workspace_id if $ws;
        }
    }
    push @args, page_workspace_id => $workspace_id if $workspace_id;

    my $page_id = $self->rest->query->param('page.id');
    push @args, page_id => $page_id if $page_id;

    my $contributions = $self->rest->query->param('contributions');
    push @args, contributions => $contributions if $contributions;

    return @args;
}

sub extract_people_args {
    my $self = shift;
    my @args;

    my $followed = $self->rest->query->param('followed');
    push @args, followed => 1 if $followed;

    my $person_id = $self->rest->query->param('person.id');
    push @args, person_id => $person_id if $person_id;

    return @args;
}

sub code_base {
   return Socialtext::AppConfig->code_base;
}

sub template_render {
    my ($self, $tmpl, $vars) = @_;
    my $renderer = Socialtext::TT2::Renderer->instance;
    my $paths = $self->hub->skin->template_paths;
    push @$paths, glob($self->code_base . "/plugin/*/template");
    return $renderer->render(
        template => $tmpl,
        paths => $paths,
        vars => {
            collection_name => $self->collection_name,
            link => Socialtext::URI::uri(path => $self->rest->request->uri),
            minutes_ago => sub { int((time - str2time(shift)) / 60) },
            round => sub { int($_[0] + .5) },
            $self->hub->helpers->global_template_vars,
            %$vars,
        },
    );
}

sub resource_to_text {
    my ($self, $events) = @_;
    my $out
        = $self->template_render('data/events.txt', { events => $events });
    return $out;
}

sub resource_to_html {
    my ($self, $events) = @_;
    $self->template_render('data/events.html', { events => $events });
}

sub resource_to_atom {
    my ($self, $events) = @_;

    # Format dates for atom
    $_->{at} =~ s{^(\d+-\d+-\d+) (\d+:\d+:\d+).\d+Z$}{$1T$2+0} for @$events;
    $self->template_render('data/events.atom.xml', { events => $events });
}

sub htmlize_event {
    my ($self, $event) = @_;
    my $renderized = $self->template_render(
        'data/event',
        { event => $event, out => 'html' }
    );
    $event->{html} = $renderized;
    return $event;
}

sub resource_to_json {
    my ($self, $events) = @_;
    my @htmlevents = map { $self->htmlize_event($_) } @$events;
    encode_json(\@htmlevents);
}

{
    no warnings 'once';
    *GET_html = Socialtext::Rest::Collection::_make_getter(\&resource_to_html,
        'text/html');
    *GET_text = Socialtext::Rest::Collection::_make_getter(\&resource_to_text,
        'text/plain');
    *GET_atom = Socialtext::Rest::Collection::_make_getter(\&resource_to_atom,
        'application/atom+xml');
    *GET_json = Socialtext::Rest::Collection::_make_getter(\&resource_to_json,
        'application/json');
}

1;
