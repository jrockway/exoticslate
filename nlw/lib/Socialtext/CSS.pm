# @COPYRIGHT@
package Socialtext::CSS;
use strict;
use warnings;

use base 'Socialtext::WebFile';

use List::MoreUtils ();
use Socialtext::AppConfig ();

sub class_id { 'css' }

sub RootDir       { Socialtext::AppConfig->code_base() . '/css' }
sub RootURI       { Socialtext::Helpers->static_path . '/css' }
sub LegacyPath    { 'base/css/' }
sub StandardFiles { qw[screen.css print.css print_preview.css wikiwyg_editor.css] }
sub BaseSkin      { 'st' }

sub _init {
    my $self = shift;
    my $hub = shift;

    my $skin_name = $hub->current_workspace->skin_name;

    my @skins = List::MoreUtils::uniq(
        $self->BaseSkin,
        $skin_name,
    );

    $self->add_path($_) for @skins;
    return;
}

sub uri_for_css {
    my $self = shift;
    my $css  = shift;

    for my $location ( @{$self->{locations}} ) {
        my $file = $location->catfile($css);
        return $file->uri if -f $file->path;
    }

    return '';
}

1;
