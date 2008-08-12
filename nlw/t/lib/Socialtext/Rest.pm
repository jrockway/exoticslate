package Socialtext::Rest;
# @COPYRIGHT@
use strict;
use warnings;
use unmocked 'Exporter';
use unmocked 'Exporter::Heavy';
use unmocked 'Test::More';
use base 'Socialtext::MockBase', 'Exporter';
use mocked 'Socialtext::User';
use mocked 'Socialtext::Hub';
use unmocked 'Socialtext::HTTP', ':codes';

our $VERSION = 0.01;
our @EXPORT = ();
our @EXPORT_OK = qw(&is_status);

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

sub rest { $_[0] }

our @HUB_ARGS;
sub hub { Socialtext::Hub->new(@HUB_ARGS) }

sub make_http_date { 'fake_date' }

my $_header;
sub header { 
    my $self = shift;
    if (@_) { $_header = { @_ }; }
    return %$_header;
}

sub user {
    my $self = shift;
    if (exists $self->{user}) {
        return $self->{user};
    }
    return Socialtext::User->new;
}

sub query { $_[0]->{query} }
sub params { $_[0]->{params} || +{} }

sub if_authorized { 
    my ( $self, $method, $perl_method, @args ) = @_;
    return $self->$perl_method(@args);
}

sub not_authorized {
    my $self = shift;

    if ($self->rest->user->is_guest) {
        $self->rest->header(
            -status => HTTP_401_Unauthorized,
            -WWW_Authenticate => 'Basic realm="Socialtext"',
        )
    }
    else {
        $self->rest->header(
            -status => HTTP_403_Forbidden,
            -type   => 'text/plain',
        );
    }
    return 'User not authorized';
}

sub getContent { return $_[0]->{_content} }

our $AUTOLOAD;

# Automatic getters for query parameters.
# copied from the real ST::Rest
sub AUTOLOAD {
    my $self = shift;
    my $type = ref $self or die "$self is not an object.\n";

    $AUTOLOAD =~ s/.*://;
    return if $AUTOLOAD eq 'DESTROY';

    if (exists $self->params->{$AUTOLOAD}) {
        croak("Cannot set the value of '$AUTOLOAD'") if @_;
        return $self->params->{$AUTOLOAD};
    }
    croak("No such method '$AUTOLOAD' for type '$type'.");
}

sub is_status($$$) {
    my $rest = shift;
    my $expected = shift;
    my $name = shift;
    my %headers = $rest->header;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is $headers{-status}, $expected, $name;
}

1;
