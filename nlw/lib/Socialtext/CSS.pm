# @COPYRIGHT@
package Socialtext::CSS;
use strict;
use warnings;

use base 'Socialtext::WebFile';

use List::MoreUtils ();
use Socialtext::AppConfig ();
use Socialtext::File;
use Class::Field 'field';

field locale_dir => '';
sub class_id { 'css' }

sub RootDir       { Socialtext::AppConfig->code_base() . '/css' }
sub RootURI       { Socialtext::Helpers->static_path . '/css' }

sub LegacyPath    { 'base/css/' }
sub StandardFiles { qw[screen.css screen.ie.css print.css print.ie.css popup.css popup.ie.css wikiwyg.css] }
sub BaseSkin      { 'st' }
sub LocalOverride { 'local' }
sub PluginCssDirectory { '_plugin' }
sub LocaleCssDirectory { '_locale' }

sub _init {
    my $self = shift;
    my $hub = shift;

    $self->{hub} = $hub;
    $self->{set_paths} = 0;
    $self->locale_dir($self->LocaleCssDirectory . '/' . $hub->display->preferences->locale->value);
}

sub _set_paths {
    my $self = shift;

    return if ($self->{set_paths});

    my $skin_name = $self->{hub}->current_workspace->skin_name;

    my @skins = List::MoreUtils::uniq(
        $self->LocalOverride,
        $self->locale_dir,
        $skin_name,
        $self->PluginCssDirectory,
        ($self->{hub}->current_workspace->cascade_css ? $self->BaseSkin : ()),
    );

    $self->add_path($_) for @skins;

    $self->add_file($_) for $self->StandardFiles();

    $self->{set_paths} = 1;
}

sub uris_for_css {
    my $self = shift;
    my $css  = shift;

    my $locations = ();

    $self->_set_paths();
    for my $location ( @{$self->{locations}} ) {
        my $file = $location->catfile($css);
        if (-f $file->path) {
            push @$locations, $file->uri;
        };
    }

    return $locations;
}

sub create_skin {
    my $self = shift;
    my $skin_name  = shift;

    mkdir $self->RootDir . "/$skin_name";
}

sub uris {
    my $self = shift;

    $self->_set_paths();

    return $self->SUPER::uris();
}

sub files {
    my $self = shift;

    $self->_set_paths();

    return $self->SUPER::files();
}


sub uri_for_common_css {
    my $self = shift;

    return $self->RootURI . '/common.css';
}

sub uris_for_plugin_css {
    my $self = shift;

    return $self->uris_for_non_default_css($self->PluginCssDirectory  );
}

sub uris_for_additional_local_css {
    my $self = shift;

    return $self->uris_for_non_default_css($self->LocalOverride );
}

sub uris_for_additional_locale_css {
    my $self = shift;

    return $self->uris_for_non_default_css($self->locale_dir );
}

sub uris_for_non_default_css {
    my $self = shift;
    my $dir = shift;

    my @css = ();
    eval {
        my @files = Socialtext::File::all_directory_files($self->RootDir . "/$dir/");
        foreach (@files) {
            next if ($_ !~ /\.css$/ || $self->is_standard_css_file($_));
            push @css, $self->RootURI . "/$dir/$_";
        }
    };
    return \@css;
}

sub is_standard_css_file {
    my $self = shift;
    my $css_file = shift;

    foreach my $standard ($self->StandardFiles) {
        return 1 if ($standard eq $css_file);
    }

    return 0;
}

1;
