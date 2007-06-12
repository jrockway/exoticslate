# @COPYRIGHT@
package Socialtext::WebApp;
use strict;
use warnings;

use base 'MasonX::WebApp';

use Apache::Constants qw(FORBIDDEN);
use Apache::URI;

# XXX - MasonX::WebApp::Exception::Abort should have a status field
# instead of having the status in the webapp object, because the
# exception is always accessible, even if the webapp object is not.
use Exception::Class (
    'Socialtext::WebApp::Exception::ContentSent' =>
      { description => 'content has already been sent to the browser, handler is done ' },
    'Socialtext::WebApp::Exception::Forbidden' =>
      { description => 'return a FORBIDDEN status' },
    'Socialtext::WebApp::Exception::NotFound' =>
      { description => 'return a NOT_FOUND status' },
);

use Socialtext::Helpers;

use Socialtext::Session;
use Socialtext::UniqueArray;
use Socialtext::Validate
  qw( validate validate_with SCALAR ARRAYREF HASHREF OBJECT );

# XXX - this attributes stuff should probably be moved to
# MasonX::WebApp if it's the right way to go.
use attributes;

my %ValidActions;

sub MODIFY_CODE_ATTRIBUTES {
    my ( $package, $ref, @attr ) = @_;

    my %attr = map { $_ => 1 } @attr;

    if ( delete $attr{Action} ) {
        $ValidActions{$ref} = 1;
    }

    return keys %attr;
}

BEGIN { __PACKAGE__->_LoadActions }

__PACKAGE__->UseSession(0);

sub session {
    my $self = shift;

    $self->{session} ||=  Socialtext::Session->new( $self->apache_req );

    return $self->{session};
}

# XXX - hack so we can make a WebApp object for "old"-style NLW code.
sub NewForNLW {
    my $class = shift;

    return $class->new(
        apache_req => Apache::Request->instance( Apache->request ),

        # XXX - try to set these?
        args      => {},
        comp_root => '',
    );
}

sub _init {
    my $self = shift;
    my %p    = validate( @_, { comp_root => { type => SCALAR }, }, );

    $self->{comp_root} = $p{comp_root};

    $self->_decode_args;
}

sub _decode_args {
    my $self = shift;

    my $args = $self->args;

    while ( my ( $k, $val ) = each %$args ) {
        next unless grep { defined && length } $val;
        next if ref $val && !UNIVERSAL::isa( $val, 'ARRAY' );

        if ( ref $val ) {
            $args->{$k} =
              [ map { Encode::is_utf8($_) ? $_ : Encode::decode_utf8($_) }
                  @$val ];
        }
        else {
            $args->{$k} = Encode::decode_utf8($val)
              unless Encode::is_utf8($val);
        }
    }
}

sub _require_args {
    my $self = shift;

    my $args = $self->args;

    foreach my $p (@_) {
        $self->redirect( uri => '/' )
          unless exists $args->{$p} && length $args->{$p};
    }
}

sub _arg_as_array {
    my $self = shift;
    my $key  = shift;

    my $value = $self->args->{$key};

    return unless defined $value;

    return ref $value ? @$value : $value;
}

sub _handle_action {
    my $self = shift;

    my ($action) = $self->apache_req->uri =~ m{^/nlw/submit/([\w\.]+)};

    return unless defined $action && length $action;

    return if $action =~ /^_/;

    $action =~ s/\./_/g;

    MasonX::WebApp::Exception::Params->throw(
        error => "Invalid action: $action" )
      unless $self->_is_valid_action($action);

    $self->$action();

    # This code is unlikely to be executed, as issuing a redirect
    # causes an exception
    MasonX::WebApp::Exception->throw(
        error => "No redirect was issued after the $action action." )
      unless $self->redirected;
}

sub _is_valid_action {
    my $self   = shift;
    my $action = shift;

    my $globref = $Socialtext::WebApp::{$action};

    return unless $globref;

    my $coderef = *{$globref}{CODE};

    return unless $coderef;

    return $ValidActions{$coderef};
}

# XXX - copied from MasonX::WebApp to allow accepting a hashref param
# - should probably look into changing this API in MasonX::WebApp.
sub _handle_error {
    my $self = shift;

    my %p = validate_with(
        params => \@_,
        spec   => {
            error     => { type => SCALAR | ARRAYREF | HASHREF | OBJECT },
            save_args => { type => HASHREF, default => {} },
        },
        allow_extra => 1,
    );

    if ( UNIVERSAL::can( $p{error}, 'messages' ) && $p{error}->messages ) {
        $self->session->add_error($_) for $p{error}->messages;
    }
    elsif ( UNIVERSAL::can( $p{error}, 'message' ) ) {
        $self->session->add_error( $p{error}->message );
    }
    elsif ( ref $p{error} eq 'ARRAY' ) {
        $self->session->add_error($_) for @{ $p{error} };
    }
    else {
        $self->session->add_error( $p{error} );
    }

    $self->session->save_args( %{ $p{save_args} } );

    delete @p{ 'error', 'save_args' };

    $self->redirect(%p);
}

sub redirect {
    my $self = shift;

    $self->session->write();

    $self->SUPER::redirect(@_);
}

sub abort_forbidden {
    my $self = shift;

    my $r = $self->apache_req;

    $r->method('GET');
    $r->headers_in->unset('Content-length');
    $r->status(FORBIDDEN);

    Socialtext::WebApp::Exception::Forbidden->throw();
}

sub css {
    my $self = shift;

    $self->{css} ||= Socialtext::UniqueArray->new();

    return $self->{css};
}

sub javascript {
    my $self = shift;

    $self->{javascript} ||= Socialtext::UniqueArray->new();

    return $self->{javascript};
}

sub static_path { Socialtext::Helpers->static_path }

sub username_label {
    return Socialtext::AppConfig->is_default('user_factories')
        ? 'Email Address'
        : 'Username';
}

1;
