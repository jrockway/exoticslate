package Socialtext::Rest::Events::Awesome;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Rest::EventsBase';

use Socialtext::l10n 'loc';

sub collection_name { loc("Followed People Events") }

sub events_auth_method { 'people' };

sub get_resource {
    my ($self, $rest) = @_;

    my @in_args = ($self->extract_common_args(), 
                   $self->extract_page_args(),
                   $self->extract_people_args());
    my %args = @in_args;
    $args{followed} = 1;
    $args{contributions} = 1;

    die "user must be specified" unless defined $self->user;
    my $user = Socialtext::User->Resolve( $self->user );

    my $reporter = Socialtext::Events::Reporter->new(viewer => $user);
    my $events = $reporter->get_awesome_events(%args);

    $events ||= [];
    return $events;
}
1;
