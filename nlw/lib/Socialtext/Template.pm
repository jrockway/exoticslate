# @COPYRIGHT@
package Socialtext::Template;
use strict;
use warnings;

use base 'Socialtext::Base';

use Socialtext::BrowserDetect ();
use Socialtext::AppConfig;
use Socialtext::Helpers;
use Socialtext::TT2::Renderer;

sub class_id { 'template' }

sub process {
    my $self = shift;
    my $template = shift;

    my @vars = (
        detected_ie => Socialtext::BrowserDetect::ie(),
        detected_safari => Socialtext::BrowserDetect::safari(),
        hub         => $self->hub,
        static_path => Socialtext::Helpers->static_path,
        appconfig   => Socialtext::AppConfig->instance(),
        script_name => Socialtext::AppConfig->script_name,
        @_,
    );
    $self->hub->preferences->init;

    my @templates = (ref $template eq 'ARRAY')
      ? @$template
      : $template;

    return join '', map {
        $self->render($_, @vars)
    } @templates;
}

sub render {
    my $self = shift;
    my $template = shift;
    my %vars = @_;

    my $renderer = Socialtext::TT2::Renderer->instance;

    return $renderer->render(
        template => $template,
        vars     => \%vars,
        paths    => $self->hub->current_workspace->skin_name,
    );
}

1;

