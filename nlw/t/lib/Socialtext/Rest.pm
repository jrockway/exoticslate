package Socialtext::Rest;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::MockBase';
use mocked 'Socialtext::User';
use mocked 'Socialtext::Hub';

# This class is mocking both Socialtext::Rest, and the Rest::Application
# object.  So $self->rest == $self.

sub new {
    my $class = shift;
    my $rest = shift;
    my $cgi = shift;
    my $self = {
        rest => $rest,
        query => $cgi,
        @_,
    };
    bless $self, $class;
    $self->_initialize( $rest, $cgi );
    return $self;
}

sub _initialize {}

sub rest { shift->{rest} }

our @HUB_ARGS;
sub hub { Socialtext::Hub->new(@HUB_ARGS) }

sub make_http_date { 'fake_date' }

sub header { 
    my $self = shift;
    $self->{header} = { @_ };
}

sub user {
    my $self = shift;
    if (exists $self->{user}) {
        return $self->{user};
    }
    return Socialtext::User->new;
}

sub query { $_[0]->{query} }

sub if_authorized { 
    my ( $self, $method, $perl_method, @args ) = @_;
    return $self->$perl_method(@args);
}

sub not_authorized { 'not authorized' }

1;
