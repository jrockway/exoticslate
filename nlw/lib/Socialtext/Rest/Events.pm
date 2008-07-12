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

our $VERSION = '0.1';

sub allowed_methods {'GET, POST'}
sub collection_name { "Events" }
sub permission { +{} }

sub if_authorized {
    my $self        = shift;
    my $method      = shift;
    my $perl_method = shift;

    my $user = $self->rest->user;
    return $self->not_authorized() unless $user;

    return $self->$perl_method(@_);
}

use constant MAX_EVENT_COUNT => 500;
use constant DEFAULT_EVENT_COUNT => 25;

sub _entities_for_query {
    my $self = shift;

    my $count = $self->rest->query->param('count') || 
                $self->rest->query->param('limit') || DEFAULT_EVENT_COUNT;
    $count = MAX_EVENT_COUNT if $count > MAX_EVENT_COUNT;

    my $offset = $self->rest->query->param('offset') || 0;
    my $action = $self->rest->query->param('action') || '';
    my $before = $self->rest->query->param('before') || ''; # datetime
    my $after = $self->rest->query->param('after') || ''; # datetime

    my $events = Socialtext::Events->Get(
        count => $count,
        action => $action,
        before => $before,
        after => $after,
        offset => $offset,
    );
    return @$events;
}

# called once for each element returned from _entities_for_query
sub _entity_hash { $_[1] }

sub POST_text {
    my ( $self, $rest ) = @_;

    return $self->if_authorized( 'POST', '_post_event' );
}

sub _post_event {
    my $self = shift;

    my $actorname = $self->rest->query->param('actor');
    unless ($actorname) {
        $self->rest->header(
            -status => HTTP_400_Bad_Request,
            -type   => 'text/plain',
        );
        return 'Missing actor parameter';
    }

    my $actor = Socialtext::User->new( username => $actorname );
    unless ($actor) {
        $self->rest->header(
            -status => HTTP_400_Bad_Request,
            -type   => 'text/plain',
        );
        return 'Invalid actor';
    }

    my $context = $self->rest->query->param('context') || '';
    eval { decode_json($context) } if $context;
    if ($@) {
        $self->rest->header(
            -status => HTTP_400_Bad_Request,
            -type   => 'text/plain',
        );
        return "Invalid event context\n$@";
    }

    my %event = (
        action => scalar( $self->rest->query->param('action') ) || '',
        actor  => $actor->user_id,
        object => scalar( $self->rest->query->param('object') ) || '',
        context => $context,
    );
    eval {
        Socialtext::Events->Record( \%event );
    };
    if ($@) {
        $self->rest->header(
            -status => HTTP_400_Bad_Request,
            -type   => 'text/plain',
        );
        return $@;
    }

    $self->rest->header(
        -status => HTTP_201_Created,
        -type => 'application/json',
        # TODO: Put a location header here once we support linking to 
        # specific events yet.  eg: /data/events/12345
    );
    return encode_json(\%event);
}

1;
