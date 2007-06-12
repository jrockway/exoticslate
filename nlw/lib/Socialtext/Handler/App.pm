# @COPYRIGHT@
package Socialtext::Handler::App;
use strict;
use warnings;

use base 'Socialtext::Handler';

use Apache::Constants qw( OK FORBIDDEN NOT_FOUND );

sub workspace_uri_regex { qr{/([\w\-]+)/index\.cgi} }

sub real_handler {
    my $class = shift;
    my $r     = shift;
    my $user  = shift;

    my ( $nlw, $html );
    eval {
        $nlw  = $class->get_nlw($r, $user);
        $html = $nlw->process;
    };

    if ( my $e = $@ ) {
        return OK
            if Exception::Class->caught('Socialtext::WebApp::Exception::ContentSent');
        return FORBIDDEN
            if Exception::Class->caught('Socialtext::WebApp::Exception::Forbidden');
        return NOT_FOUND
            if Exception::Class->caught('Socialtext::WebApp::Exception::NotFound');
        return $class->handle_error( $r, $e )
            unless Exception::Class->caught('MasonX::WebApp::Exception::Abort');
    }

    $class->send_output( $r, $nlw, $html );

    return OK;
}

1;

__END__

=head1 NAME

Socialtext::Handler::App - Provides a handler() sub for (most of) the NLW app under mod_perl

=head1 SYNOPSIS

  <LocationMatch "/[^/]+/.*">
      RewriteEngine On
      RewriteRule   (.+)/index.cgi(.+)  $1$2  [NE]

      # above workspace dir
      PerlHandler  +Socialtext::Handler::App
  </LocationMatch>

=head1 DESCRIPTION

This module hooks NLW up to mod_perl.

=cut
