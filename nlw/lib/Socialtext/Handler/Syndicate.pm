# @COPYRIGHT@
package Socialtext::Handler::Syndicate;
use strict;
use warnings;

use base 'Socialtext::Handler::BasicChallenger';

use Apache::Constants qw(HTTP_UNAUTHORIZED OK NOT_FOUND);
use Socialtext::Authz;
use Socialtext::Permission 'ST_READ_PERM';
use Socialtext::User;

sub workspace_uri_regex { qr{(?:/noauth/|/)feed/workspace/([\w\-]+)$} }

sub allows_guest {
    my $class = shift;
    my $request = shift;

    # if this is true, we allow guest
    $request->uri =~ m{^/noauth};
}

sub real_handler {
    my $class = shift;
    my $r     = shift;
    my $user  = shift;

    # FIXME: change this, we don't need to find the user yet again
    # create nlw main object
    my $nlw = eval { $class->get_nlw($r, $user) };
    if ( my $e = $@ ) {
        return if Exception::Class->caught('MasonX::WebApp::Exception::Abort');
        return $class->handle_error( $r, $@ );
    }

    # know our classes
    $nlw->hub->registry->load;

    my $authz = Socialtext::Authz->new;
    return HTTP_UNAUTHORIZED
        unless $authz->user_has_permission_for_workspace(
            user       => $nlw->hub->current_user,
            permission => ST_READ_PERM,
            workspace  => $nlw->hub->current_workspace,
        );

    # create output
    # XXX uses default type and category, need to improve that
    # syndicate($type, $category)
    my $feed = eval { $nlw->hub->syndicate->syndicate };

    return NOT_FOUND
        if Exception::Class->caught('Socialtext::Exception::NoSuchPage');

    return $class->handle_error( $r, $@, $nlw )
      if $@
      and not Exception::Class->caught('MasonX::WebApp::Exception::Abort');

    my $output = $feed->as_xml;
    if ( defined $output ) {
        $nlw->hub->headers->content_type( $feed->content_type );
        $class->send_output( $r, $nlw, $output );
    }

    return OK;
}

# use our own send_output as we don't want to encode
sub send_output {
    my $class   = shift;
    my $r       = shift;
    my $nlw     = shift;
    my $content = shift;
    $nlw->hub->headers->print;
    $r->print($content);
}


1;

