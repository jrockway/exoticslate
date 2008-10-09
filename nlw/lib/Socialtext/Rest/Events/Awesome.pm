package Socialtext::Rest::Events::Awesome;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Rest::Events';

use Socialtext::Events::Reporter;

sub allowed_methods { 'GET' }
sub collection_name { "Followed People Events" }

sub if_authorized {
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
