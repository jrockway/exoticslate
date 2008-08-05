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

    return $self->$perl_method(@_);
}

sub get_resource {
    my $self = shift;

    my @args;

    my $count = $self->rest->query->param('count') || 
                $self->rest->query->param('limit') || DEFAULT_EVENT_COUNT;
    $count = MAX_EVENT_COUNT if $count > MAX_EVENT_COUNT;
    push @args, count => $count;

    my $offset = $self->rest->query->param('offset') || 0;
    push @args, offset => $offset if $offset;

    my $before = $self->rest->query->param('before') || ''; # datetime
    push @args, before => $before if $before;
    my $after = $self->rest->query->param('after') || ''; # datetime
    push @args, after => $after if $after;

    my $event_class = $self->rest->query->param('event_class');
    push @args, event_class => lc $event_class if $event_class;
    my $action = $self->rest->query->param('action');
    push @args, action => lc $action if $action;

    my $actor_id = $self->rest->query->param('actor.id');
    push @args, 'actor_id' => $actor_id if $actor_id;
    # TODO: resolve actor.name to a user
    my $person_id = $self->rest->query->param('person.id');
    push @args, 'person_id' => $person_id if $person_id;
    # TODO: resolve person.name to a user

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

    my $tag_name = $self->rest->query->param('tag_name');
    push @args, tag_name => $tag_name if $tag_name;

    my $events = Socialtext::Events->Get(@args);
    $events ||= [];

    return $events;
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
    my $cgi = Socialtext::CGI::Scrubbed->new;
 
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
    return $self->_missing_param('actor.id')
        unless $actor_id;

    my %event = (
        class  => $event_class,
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
