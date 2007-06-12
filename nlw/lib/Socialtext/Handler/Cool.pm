# @COPYRIGHT@
package Socialtext::Handler::Cool;
use strict;
use warnings;

=head1 NAME

Socialtext::Handler::Cool - A base class for implementing Cool URI handlers.

=head1 SYNOPSIS

    package Socialtext::Handler::Foo;
    
    use base 'Socialtext::Handler::Cool';

    sub _handle_get {
        my ( $class, $r, $nlw ) = @_;

        # ...
        
        return ( $representation, $content_type );
    }

    sub _handle_post {
        # ...
    }


=head1 DESCRIPTION

This class is intended to act as a simple base class for handling cooler
URIs than the bad old days (you know, C</page/WORKSPACE/PAGE_ID> and that
sort of thing).

The interface is still in flux and should not be relied upon.

=head1 SUBCLASSING

The class is used by subclassing.  Implementors should take care to implement
the following methods.

=head2 CLASS::workspace_uri_regex($uri)

Given a request URI, should return the workspace for that URI, if appropriate.

=head2 CLASS->_handle_FOO( $r, $nlw )

Given an L<Apache> object representing the request and a L<Socialtext> object
initialized for the correct workspace, handle the FOO request.
Implementations should return a C<( $representation, $content_type )> list.

This method can assume that the current user has permission to read the
current workspace.

B<N.B.>: FOO should be lower cased.  Thus, to handle C<GET> requests, you
write a method called C<_handle_get>.

=cut

use base 'Socialtext::Handler';

use Apache::Constants
    qw(NOT_FOUND HTTP_UNAUTHORIZED OK SERVER_ERROR HTTP_METHOD_NOT_ALLOWED);

use Apache::Request;
use Socialtext::Authz;
use Socialtext::Permission;

use constant UPLOAD_TOO_LARGE => 413;

sub real_handler  {
    my $class = shift;
    my $r = Apache::Request->instance(
        shift,
        POST_MAX        => 100 * 1024 * 1024,
        DISABLE_UPLOADS => 0,
    );
    my $user = shift;

    my $code = $r->status;

    if ($code == UPLOAD_TOO_LARGE) {
        return $code;
    }

    my $nlw   = eval {
        $class->get_cool_nlw($r, $user);
    };

    return NOT_FOUND unless $nlw;

    # REVIEW: handle_error here, not handle_cool_error. Not sure if
    # this is right or not. Don't really even know if we'll ever have
    # an error here.
    return $class->handle_error( $r, $@ ) if $@;

    return HTTP_UNAUTHORIZED
        unless $class->_user_has_permission( 'read', $nlw->hub );

    # create output
    my $output;
    my $type;

    my $request_method = $r->method;
    my $method = '_handle_' . lc($request_method);

    if ($class->can($method)) {
        eval {
            ( $output, $type ) = $class->$method( $r, $nlw );
        };
        # REVIEW: When does the mason error happen?
        return $class->handle_cool_error( $r, $@ ) if $@
            and
            not Exception::Class->caught('MasonX::WebApp::Exception::Abort');

        # If type was not set, we got back an HTTP error or
        # redirect and we want to send it right up the chain,
        # getting out of this request.
        if (! defined($type) ) {
            return $output;
        }
    }
    else {
        return $class->_handle_405($r);
    }

    $class->send_output( $r, $nlw, $output, $type );
    return OK;
}

# overridden in sub classes
sub _handle_get {
    my $class = shift;
    my $r     = shift;
    $class->_handle_405($r);
}

sub _handle_delete {
    my $class = shift;
    my $r     = shift;
    $class->_handle_405($r);
}

sub _handle_put {
    my $class = shift;
    my $r     = shift;
    $class->_handle_405($r);
}

sub _handle_post {
    my $class = shift;
    my $r     = shift;
    $class->_handle_405($r);
}

sub _handle_405 {
    my $class = shift;
    my $r     = shift;
    return HTTP_METHOD_NOT_ALLOWED;
}

sub get_cool_nlw {
    my $class = shift;
    my $r     = shift;
    my $user  = shift;

    # create nlw main object
    my $nlw = eval { $class->get_nlw($r, $user) };
    if ( my $e = $@ ) {
        return if Exception::Class->caught('MasonX::WebApp::Exception::Abort');
        return if Exception::Class->caught('Socialtext::WebApp::Exception::NotFound');
        die $@;
    }

    # know our classes
    $nlw->hub->registry->load;

    return $nlw;
}

sub _user_has_permission {
    my $class = shift;
    my $perm  = shift;
    my $hub   = shift;

    my $authz = Socialtext::Authz->new;
    return $authz->user_has_permission_for_workspace(
               user       => $hub->current_user,
               permission => Socialtext::Permission->new( name => $perm ),
               workspace  => $hub->current_workspace,
           );
}

# We use our own instead of parent class to gain CONTROL
sub send_output {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;
    my $content  = shift;
    my $type = shift;

    $nlw->hub->headers->content_type($type . '; charset=utf-8');
    $nlw->hub->headers->print;
    $r->print($content);
}

sub handle_cool_error {
    my $class = shift;
    my $r     = shift;
    my $error = shift;

    $r->log_error($error);
    $error = "pid: $$ -> " . $error;

    # REVIEW: Mason is going to hop in and make pretty error
    # messages for us now, whether we really want that or not.
    $r->pnotes( error => $error );
    return SERVER_ERROR;
}

# REVIEW: This is good enough for our purposes, but for true
# Accept header handling we need to pay attention to quality
# values in the header.

=head1 CLASS METHODS

=head2 Socialtext::Handler::Cool->type_for_accept($acceept_header);

Given the request's accept header, returns some content-type which the client
finds suitable.

=cut

# REVIEW: The POD should do a better job of explaining how it picks what it
# picks, and why.

sub type_for_accept {
    my $class = shift;
    my $accept_header_value = shift;

    # a reasonable default in the absence of the header?
    return 'text/html' if not defined($accept_header_value);

    $accept_header_value =~ s/;.*$//; # strip off less desired types
    if ( $accept_header_value =~ m{\bapplication/(?:x\.)?atom\+xml\b}) {
        return 'application/atom+xml';
    } elsif ( $accept_header_value =~ m{text/html|[*]/[*]} ) {
        return 'text/html';
    }
    return 'text/plain';
}

1;

=head1 SEE ALSO

L<Socialtext::Handler::Page> for a sample implementation,
L<Socialtext::Handler>,
L<Apache>

=cut
