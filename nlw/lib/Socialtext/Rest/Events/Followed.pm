package Socialtext::Rest::Events::Followed;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Rest::Events';
use Socialtext::SQL qw/sql_execute/;

use Socialtext::Events::Reporter;

our $VERSION = '1.0';

sub allowed_methods { 'GET' }
sub collection_name { "Followed People Events" }

use constant MAX_EVENT_COUNT => 500;
use constant DEFAULT_EVENT_COUNT => 25;

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
    my $events = Socialtext::Events->Get($user, %args);
    $events ||= [];
    return $events;
}
1;
