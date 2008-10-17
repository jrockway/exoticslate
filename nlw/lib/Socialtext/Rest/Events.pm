package Socialtext::Rest::Events;
# @COPYRIGHT@
use warnings;
use strict;
use base 'Socialtext::Rest::Collection';
use Socialtext::HTTP ':codes';
use Socialtext::Events;
use Socialtext::JSON qw/encode_json decode_json/;
use Class::Field 'field';
use Socialtext::User;
use Socialtext::Exceptions;
use Date::Parse;

our $VERSION = '1.0';

sub allowed_methods {'GET, POST'}
sub collection_name { "Events" }

field 'ws';

use constant MAX_EVENT_COUNT => 500;
use constant DEFAULT_EVENT_COUNT => 25;

sub if_authorized {
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

sub get_resource {
    my $self = shift;

    my @args = ($self->extract_common_args(), 
                $self->extract_page_args(),
                $self->extract_people_args());

    my $events = Socialtext::Events->Get($self->rest->user, @args);
    $events ||= [];

    return $events;
}

sub template_render {
    my ($self, $tmpl, $vars) = @_;
    my $renderer = Socialtext::TT2::Renderer->instance;
    return $renderer->render(
        template => $tmpl,
        vars => {
            minutes_ago => sub { int((time - str2time(shift)) / 60) },
            round => sub { int($_[0] + .5) },
            $self->hub->helpers->global_template_vars,
            %$vars,
        },
    );
}

sub resource_to_text {
    my ($self, $events) = @_;
    my $out = $self->template_render('data/events.txt', { events => $events });
    return $out;
}

sub resource_to_html {
    my ($self, $events) = @_;
    $self->template_render('data/events.html', { events => $events });
}

{
    no warnings 'once';
    *GET_html = Socialtext::Rest::Collection::_make_getter(
        \&resource_to_html, 'text/html'
    );
    *GET_text = Socialtext::Rest::Collection::_make_getter(
        \&resource_to_text, 'text/plain'
    );
}

sub POST_text {
    die "POST text?!";
}

sub POST_json {
    my ( $self, $rest ) = @_;
    return $self->if_authorized( 'POST', '_post_json' );
}

sub POST_form {
    my ( $self, $rest ) = @_;
    return $self->if_authorized( 'POST', '_post_form' );
}

sub _post_json {
    my $self = shift;
    my $json = $self->rest->getContent();
    my $data = decode_json($json);

    $data->{actor} ||= {};
    $data->{person} ||= {};
    $data->{page} ||= {};

    my %params = (
        at => $data->{at},
        event_class => $data->{event_class},
        action => $data->{action},
        'actor.id' => $data->{actor}{id},
        'actor.name' => $data->{actor}{name},
        'person.id' => $data->{person}{id},
        'person.name' => $data->{person}{name},
        'page.id' => $data->{page}{id},
        'page.workspace_name' => $data->{page}{workspace_name},
        tag_name => $data->{tag_name},
    );

    return $self->_post_an_event(\%params, $data->{context});
}

sub _post_form {
    my $self = shift;
    my $cgi = $self->{_test_cgi} || Socialtext::CGI::Scrubbed->new;
 
    my %params;
    foreach my $key (qw(event_class action actor.id person.id page.id page.workspace_name tag_name)) {
        my $value = $cgi->param($key);
        $params{$key} = $value if defined $value;
    }

    my $context = $cgi->param('context');
    if ($context) {
        $context = eval { decode_json($context) };
        if ($@) {
            $self->rest->header(
                -status => HTTP_400_Bad_Request,
                -type   => 'text/plain',
            );
            warn $@;
            return "Event recording failure; 'context' must be vaild JSON";
        }
    }

    return $self->_post_an_event(\%params, $context);
}

sub _post_an_event {
    my $self = shift;
    my $params = shift;
    my $context = shift;

    my $event_class = $params->{'event_class'};
    return $self->_missing_param('event_class')
        unless $event_class;

    my $action = $params->{'action'};
    return $self->_missing_param('action')
        unless $action;

    my $actor_id = $params->{'actor.id'};
    if (!$actor_id && $self->rest->user && !$self->rest->user->is_guest) {
        $actor_id = $self->rest->user->user_id;
        my $uname = $self->rest->user->username;
        warn "NOTICE: event actor has been set to '$uname' (id:$actor_id)";
    }
    return $self->_missing_param('actor.id')
        unless $actor_id;

    my %event = (
        event_class  => $event_class,
        action => $action,
        actor  => $actor_id,
    );

    my $at = $params->{'at'};
    $event{timestamp} = $at if $at;

    $event{context} = $context
        if defined($context) && length($context);

    my $tag_name = $params->{'tag_name'};
    $event{tag_name} = $tag_name if $tag_name;


    if ($event_class eq 'person') {
        my $person_id = $params->{'person.id'};
        return $self->_missing_param('person.id')
            unless $person_id;
        $event{person} = $person_id;
    }
    elsif ($event_class eq 'page') {
        my $page_id = $params->{'page.id'};
        return $self->_missing_param('page.id')
            unless $page_id;
        my $ws_name = $params->{'page.workspace_name'};
        return $self->_missing_param('page.workspace_name')
            unless $ws_name;

        my $ws = Socialtext::Workspace->new(name => $ws_name);
        if (!$ws) {
            $self->rest->header(
                -status => HTTP_400_Bad_Request,
                -type   => 'text/plain',
            );
            return "Invalid workspace '$ws_name'";
        }

        $event{page} = $page_id;
        $event{workspace} = $ws->workspace_id;
    }

    eval {
        Socialtext::Events->Record(\%event);
    };
    if ($@) {
        $self->rest->header(
            -status => HTTP_500_Internal_Server_Error,
            -type   => 'text/plain',
        );
        warn $@;
        return "Event recording failure";
    }

    $self->rest->header(
        -status => HTTP_201_Created,
        -type => 'text/plain',
    );
    return "Event recording success"
}

sub _missing_param {
    my $self = shift;
    my $param = shift;
    $self->rest->header(
        -status => HTTP_400_Bad_Request,
        -type   => 'text/plain',
    );
    return "Event recording failure: Missing required parameter '$param'";
}

1;
