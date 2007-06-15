package Socialtext::Challenger::OpenId;
# @COPYRIGHT@

use strict;
use warnings;


use Net::OpenID::Consumer;
use Apache;
use Apache::Request;
use Apache::Cookie;
use Socialtext::User;
use Socialtext::WebHelpers::Apache;
use LWP::UserAgent;
use Socialtext::WebApp;
use URI::Escape qw (uri_unescape);

=head1 NAME

Socialtext::Challenger::OpenId - Challenge with the default login screen

=head1 SYNOPSIS

    Do not instantiate this class directly. Use L<Socialtext::Challenger>

=head1 DESCRIPTION

When configured for use, this Challenger will redirect a request
to the OpenId login system.

=cut

# Send this request to the NLW challenge screen
sub challenge {
    my $class    = shift;
    my %p        = @_;
    my $hub      = $p{hub};
    my $request  = $p{request};
    my $redirect = $p{redirect};
    my $type;
 my $app = Socialtext::WebApp->NewForNLW;
    $request = Apache::Request->instance( Apache->request );

    my $claimed_identity =
          $request->param('openid.identity')
        ? $request->param('openid.identity')
        : $request->param('identity');

    if ( !$claimed_identity ) {
        return undef;
    }

    $claimed_identity = uri_unescape($claimed_identity);
    if ( $claimed_identity =~ /^http/ ) {
        $claimed_identity =~ s#^http(s)?://##g;
        $claimed_identity =~ s#/$##g;
    }
    $claimed_identity =~ s/\s//g;

    my $csr = Net::OpenID::Consumer->new(
        ua              => LWP::UserAgent->new,
        args            => $request,
        consumer_secret => 'THIS IS MY SECRET!',
    );

    if ( !$request->param('openid.mode') ) {
        my $FULL_URI = Socialtext::WebHelpers::Apache->full_uri_with_query;
        my $BASE_URI = Socialtext::WebHelpers::Apache->base_uri;

        $claimed_identity = $csr->claimed_identity($claimed_identity);

        if ( !$claimed_identity && !$request->param('openid.identity') ) {
            warn "RETURNING UNDEF HERE\n";
            return undef;
        }
        my $check_url = $claimed_identity->check_url(
            return_to  => "$FULL_URI",
            trust_root => "$BASE_URI"
        );
        $app->redirect( $check_url );
    }
    else {
        if ( my $setup_url = $csr->user_setup_url ) {
            $app->redirect( $setup_url);
        }
        elsif ( $csr->user_cancel ) {
            $app->redirect( $ENV{HTTP_REFERER} );
        }
        elsif ( my $vident = $csr->verified_identity ) {
            my $verified_url = $vident->url;
            if ( !_set_cookie($claimed_identity) ) {
                return undef;
            }
        }
        $app->redirect ( "/" );
    }
}

sub _set_cookie {
    my $identity = shift;
    my $user = Socialtext::User->new( username => $identity );
    if ( !$user ) { return undef; }
    my $user_id = $user->user_id;
    my $value   = {
        user_id => $user_id,
        MAC     => _MAC_for_user_id($user_id),
    };
    my $request = Apache::Request->instance( Apache->request );
    my $cookie  = Apache::Cookie->new(
        $request,
        -name    => 'NLW-user',
        -value   => $value,
        -expires => '+12M',
        -path    => '/',
    )->bake;
    return $user_id;
}

sub _MAC_for_user_id {
            return Digest::SHA1::sha1_base64( $_[0], Socialtext::AppConfig->MAC_secret );
                }

1;
=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Socialtext, Inc., All Rights Reserved.

=cut
