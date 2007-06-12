# @COPYRIGHT@
package Socialtext::Handler;
use strict;
use warnings;

use Apache::Constants qw(:response :common);
use Apache::SubProcess;
use Apache::URI;

use File::Find ();
use Socialtext::Apache::User;

use Socialtext;
use Socialtext::Hub; # preload all other classes
use Socialtext::AppConfig;
use Socialtext::CredentialsExtractor;
use Socialtext::RequestContext;
use Socialtext::WebApp;
use Socialtext::TT2::Renderer;
use Socialtext::User;
use Socialtext::Challenger;

# provides a way to skip this when running tests
_preload_templates()
    unless $ENV{NLW_HANDLER_NO_PRELOADS} || not $ENV{MOD_PERL};

sub allows_guest {1}

sub challenge {
    my $class = shift;
    return Socialtext::Challenger->Challenge(@_);
}

sub handler ($$) {
    my $class = shift;
    my $r     = shift;

    my $user = $class->authenticate($r) || $class->guest($r);

    return $class->challenge(request => $r) unless $user;

    return $class->real_handler($r, $user);
}

sub authenticate {
    my $class   = shift;
    my $request = shift;
    my $credential
        = Socialtext::CredentialsExtractor->ExtractCredentials($request);
    if ($credential) {
        my $user = Socialtext::User->new( username => $credential )
            || Socialtext::User->new( user_id  => $credential );
        $request->connection->user($user->username);
        return $user;
    }
    return undef;
}

sub guest {
    my $class   = shift;
    my $request = shift;
    if ( $class->allows_guest($request) ) {
        return Socialtext::User->Guest;
    }
    else {
        return undef;
    }
}

sub _preload_templates {
    my @files = Socialtext::TT2::Renderer->PreloadTemplates();

    my $server = Apache->server;
    my $uid = $server->uid;
    my $gid = $server->gid;

    my $chown =
        sub { chown $uid, $gid, $File::Find::name
                  or die "Cannot chown $File::Find::name to $uid.$gid: $!" };

    File::Find::find(
        {
            wanted   => $chown,
            no_chdir => 1,
        },
        Socialtext::AppConfig->template_compile_dir
    );
}

sub get_nlw {
    my $class = shift;
    my $r     = shift;
    my $user  = shift;

    my ( $hub, $type, $app, $workspace_title, $workspace_id );

    my $context = Socialtext::RequestContext->new(
        uri                 => $r->uri,
        user                => $user,
        workspace_uri_regex => $class->workspace_uri_regex,
        notes_callback      => sub { $r->pnotes(@_) },
    );

    $hub = $context->hub;

    Socialtext::WebApp::Exception::NotFound->throw()
        unless $hub;

    if ( !$hub->checker->check_permission('read') ) {
        $class->challenge(hub => $hub, request => $r);
    }

    return $hub->main;
}

sub send_output {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;
    my $html  = shift;

    # REVIEW: When "Invalid MAC in cookie presented for $user_data{user_id}"
    # happens in Socialtext::Apache::User::user_id(), we eventually fall
    # through to here with $nlw _not_ defined, causing upset in the error
    # logs. This 'if $nlw' adjustment below _stinks_, but cdent needs a
    # pair or other assistance (and less sickness) to get the dots connected.
    $nlw->hub->headers->print if $nlw;
    if ( defined $html ) {
        $nlw->utf8_encode($html) if $nlw;
        $r->print($html);
    }

    # REVIEW - also doesn't really belong here, but is the only
    # centralized point at the end of a handler's run.
    Socialtext::WebApp->NewForNLW()->session()->write();
}

sub handle_error {
    my $class = shift;
    my $r     = shift;
    my $error = shift;
    my $nlw   = shift;

    $error = "pid: $$ -> " . $error;

    $r->log_error($error);

    $error = $nlw->html_escape($error) if $nlw;
    $r->content_type('text/html; charset=UTF-8');
    $r->send_http_header;
    $r->print("<h1>Software Error:</h1><pre>\n$error</pre>\n");
    return OK;
}


1;

__END__

=head1 NAME

Socialtext::Handler - A base class for NLW mod_perl handlers

=head1 SYNOPSIS

  use base 'Socialtext::Handler';


  sub workspace_uri_regex => qr{/path/to/workspace/([^/]+)};

  sub foo {
      my $nlw = $class->get_nlw($r);
  }

=head1 DESCRIPTION

This module hooks NLW up to mod_perl.

=head1 ADDITIONAL

We should really use something like C<Class::Autouse>, which loads
things on demand outside mod_perl and at startup under mod_perl.

=cut
