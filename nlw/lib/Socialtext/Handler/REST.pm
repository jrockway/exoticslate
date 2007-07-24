package Socialtext::Handler::REST;
# @COPYRIGHT@

use strict;
use warnings;

use base 'REST::Application::Routes';
use base 'Socialtext::Handler::BasicChallenger';
use Socialtext::HTTP ':codes';

use Apache;
use Apache::Constants qw(OK AUTH_REQUIRED);
use Encode qw(decode_utf8);
use File::Basename;
use File::Spec;
use Readonly;
use YAML;

Readonly my $URI_MAP => 'uri_map.yaml';

my @ResourceHooks;
__PACKAGE__->_load_resource_hooks();

# FIXME: We do not want to return OK here in all cases.
sub real_handler {
    my $class = shift;
    my $r     = shift;
    my $user  = shift;

    __PACKAGE__->new( request => $r, user => $user )->run();
    return OK;
}

sub allows_guest {0}

sub setup {
    my ( $self, %args ) = @_;

    $self->{_request} = $args{request} || Apache->request;
    $self->{_user} = $args{user};
    $self->resourceHooks(@ResourceHooks);
}

# REVIEW: Overridden from REST::Application because it does
# the wrong thing and masks a die that happens within the
# eval, because the error does not result in a 500, as we
# might expect.
sub callHandler {
    my ($self, $handler, @extraArgs) = @_;
    my @args = $self->getHandlerArgs(@extraArgs);

    # Call the handler, make an error response if something goes wrong.
    my $result;
    eval {
        $self->preHandler(\@args);  # no-op by default.
        $result = $handler->(@args);
        $self->postHandler(\$result, \@args); # no-op by default.
    };
    if ($@) {
        $self->header(
            -status => HTTP_500_Internal_Server_Error,
            -type   => 'text/plain',
        );
        $result = "$@";
        $self->request->log_error($result);
    }

    # Convert the result to a scalar result if it isn't already.
    return (ref($result) eq 'scalar') ? $result : \$result;
}

# FIXME: add on cache handling hack
# If cache headers have not otherwise been dorked with, this
# makes _nothing_ cache.
# This is a stopgap. Do not let this stand! It prevents any caching,
# L A M E
sub postHandler {
    my ($self, $resultref, $args) = @_;
    my %headers = $self->header;
    unless ($headers{'-cache_control'} ||
            $headers{'-pragma'} ||
            $headers{'-Etag'} ) {
        $self->header(
            $self->header,
            -cache_control => 'no-cache',
            -pragma => 'no-cache',
        );
    }

    # If the request is a head, send back just the headers
    if ($self->getRequestMethod() eq 'HEAD') {
        ($$resultref, undef) = split(/^\r\n/, $$resultref);
    }
}

sub makeHandlerFromClass {
    my ( $self, $class, $method ) = @_;
    return sub { $class->new(@_)->$method(@_) };
}

# FIXME: This needs to come out before release, or at least be disabled by
# default.
sub defaultResourceHandler {
    no warnings 'once';
    local $YAML::SortKeys = 0;
    local $YAML::UseCode = 1;
    local $YAML::UseFold = 1;

    $_[0]->header( -status => HTTP_500_Internal_Server_Error,
                   -type   => 'text/plain' );
    # Delete Socialtext objects.  Usually noise anyway.
    delete $_[0]->{$_} for qw(_user);
    return "No method found for your request.  State is dumped below.\n\n"
        . Dump(@_);
}

# XXX: The framework should use another layer of indirection over
# bestContentType.  So we don't have to overload it here.  Or push the
# GET/POST/PUT assymmetries into the framework.
sub bct_hack {
    my $self = shift;

    $self->{_gcp_hack} = 1;
    my $mime = $self->SUPER::bestContentType(@_);
    delete $self->{_gcp_hack};

    return $mime;
}

sub getContentPrefs {
    my $self   = shift;
    my $method = $self->getRequestMethod();
    if ( not $self->{_gcp_hack} and $method =~ /^(POST|PUT)$/i ) {
        my $ct = $self->request->header_in('Content-Type');
        $ct ||= '*/*';
        return ( $ct, '*/*' );
    }
    if (my $type = $self->query->param('accept')) {
        return ($type, '*/*');
    }
    return $self->SUPER::getContentPrefs(@_);
}

sub getContent {
    my $self = shift;
    return $self->{__content} if defined $self->{__content};
    $self->{__content} = $self->_getContent();
    return $self->{__content};
}

# use CGI for POST, and read the buffer for PUT
sub _getContent {
    my $self = shift;
    # N.B.: SUPER::getRequestMethod returns the underlying HTTP request
    # method, even if we're tunneling.
    if ( $self->getRealRequestMethod() eq 'POST' ) {
        $self->query->param('POSTDATA');
    }
    else {
        # REVIEW: this is problematic for very large attachments
        my $buff;
        my $content_length = $self->request->header_in('Content-Length');
        my $result = read( \*STDIN, $buff, $content_length, 0 );
        die "unable to read buffer $!" if not defined($result);
        return $buff;
    }
}

sub user        { $_[0]->{_user} }
sub request     { $_[0]->{_request} }
sub getPathInfo { decode_utf8( $_[0]->request->uri ) }

sub do_test {
}

# Get the resource hooks from the YAML file.  Since YAML.pm can't handle
# !!omap types, we also need to munge the underlying data structure back into
# an ordered list.
sub _load_resource_hooks {
    my $class  = shift;
    my $dir   = File::Basename::dirname(__FILE__);
    my $hooks = YAML::LoadFile( File::Spec->catfile( $dir, $URI_MAP ) );

    $class->_load_resource_hook_classes($hooks);
    $class->_duplicate_gets_to_heads($hooks);
    @ResourceHooks = (map {%$_} @$hooks );
}

# Duplicate all the GET handlers into HEAD handlers as well.
# We clean them up in the postHandler
sub _duplicate_gets_to_heads {
    my ($class, $hooks) = @_;

    # REVIEW: This is the brute force way of doing this, which doesn't
    # seem right.
    foreach my $entry (@$hooks) {
        foreach my $route ( keys(%$entry) ) {
            foreach my $method ( keys(%{$entry->{$route}}) ) {
                if ( $method eq 'GET' ) {
                    $entry->{$route}->{HEAD}
                        = $entry->{$route}->{GET};
                }
            }
        }
    }
}

# Automagically require the classes used in the YAML file.
sub _load_resource_hook_classes {
    my ( $class, $hooks ) = @_;

    for my $hook (@$hooks) {
        _load_classes($hook);
    }
}

sub _load_classes {
    my $hook = shift;

    if ( ref($hook) eq 'ARRAY' ) {
        my $class = $hook->[0] || return;
        return if $class->can('new');
        eval "require $class; 0;";
        die "$@\n" if $@;
    }
    elsif ( ref($hook) eq 'HASH' ) {
        for my $key ( keys %$hook ) {
            _load_classes( $hook->{$key} );
        }
    }
}

1;
