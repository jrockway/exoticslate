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

    # set max upload size
    my $apr = Apache::Request->instance( shift, POST_MAX => ( 1024 ** 2 ) * 50 );

    my $user = $class->authenticate($apr) || $class->guest($apr);

    return $class->challenge(request => $apr) unless $user;

    return $class->real_handler($apr, $user);
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

sub handle_error {
    my $class = shift;
    my $r     = shift;
    my $error = shift;
    my $nlw   = shift;

    if (ref($error) ne 'ARRAY') {
        $error = "pid: $$ -> " . $error;
        $r->log_error($error);
        $error = $nlw->html_escape($error) if $nlw;
        $error = [ $error ];
    }

    my %vars = (
        debug => Socialtext::AppConfig->debug,
        errors => $error,
    );

    return $class->render_template($r, 'errors/500.html', \%vars);
}

sub render_template {
    my $class    = shift;
    my $r        = shift;
    my $template = shift;
    my $vars     = shift || {};

    my $renderer = Socialtext::TT2::Renderer->instance;
    eval {
        $r->print(
            $renderer->render(
                template => $template,
                vars     => $vars,
            )
        );
    };
    if ($@) {
        if ($@ =~ /\.html: not found/) {
            return NOT_FOUND;
        }
        warn $@ if $@;
    }
    return OK;
}

sub r { shift->{r} }

sub session {
    my $self = shift;
    $self->{session} ||=  Socialtext::Session->new( $self->r );
    return $self->{session};
}

sub redirect {
    my $self = shift;
    $self->r->header_out(Location => shift);
    return REDIRECT;
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
