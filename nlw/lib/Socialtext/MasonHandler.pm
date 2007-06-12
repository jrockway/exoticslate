# @COPYRIGHT@
package Socialtext::MasonHandler;
use strict;
use warnings;

use Apache::Constants qw( OK REDIRECT SERVER_ERROR );
use Apache::Request;
use Apache::URI;

use Socialtext::AppConfig;
use Socialtext::WebApp;

use Socialtext::FillInFormBridge;
use Socialtext::UI;

{
    package Socialtext::MasonComponent;

    use URI::FromHash qw(uri);
}


# The parameters here should be coming from app config
my $ah =
    MasonX::WebApp::ApacheHandler->new
        ( comp_root     => $ENV{MASON_COMP_ROOT},
          data_dir      => Socialtext::AppConfig->mason_data_dir(),

          decline_dirs  => 0,

          in_package    => 'Socialtext::MasonComponent',

          # XXX - should switch to 'fatal' for production use
          error_mode    => 'output',

          allow_globals => [ '$App' ],

          escape_flags  => { js_quote => sub { ${ $_[0] } =~ s/\'/\\\'/g; } },
        );

sub handler
{
    # 20MB max upload size
    my $apr = Apache::Request->instance( shift, POST_MAX => ( 1024 ** 2 ) * 20 );

    $apr->no_cache(1);

    my $args = $ah->request_args($apr);

    my $comp_root =
        $ah->interp->resolver->can('comp_root')
          ? $ah->interp->resolver->comp_root
          : $ah->interp->comp_root;

    my $app = eval {
        Socialtext::WebApp->new(
            apache_req => $apr,
            args       => $args,
            comp_root  => $comp_root,
        );
    };

    return _handle_error( $apr, $@ ) if $@;

    return REDIRECT if $app->redirected;

    return $app->abort_status if $app->aborted;

    # Cannot use interp->set_global because we want to make sure the
    # webapp object goes out of scope.
    local $Socialtext::MasonComponent::App = $app;
    my $return = eval { $ah->handle_request($apr) };

    return $app->abort_status if $app->aborted;

    return _handle_error( $apr, $@, $app ) if $@;

    # We only want to clean the session if we displayed HTML via a
    # Mason component, because that means it saw the session and got
    # what it needed from it.
    $app->session()->clean();

    return $return;
}

sub _handle_error
{
    my $apr = shift;
    my $err = shift;
    my $app = shift;

    my $error_text = "URL is " . $apr->parsed_uri->unparse . "\n\n";

    $error_text .= UNIVERSAL::can( $err, 'as_text' ) ? $err->as_text : $err;

    $apr->log_error($error_text);

    $apr->pnotes( error => $error_text );

    # XXX - error logging should be done through some shared log object

    return SERVER_ERROR;
}


1;
