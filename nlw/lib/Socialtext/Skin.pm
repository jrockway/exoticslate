# @COPYRIGHT@
package Socialtext::Skin;
# @COPYRIGHT@

use strict;
use warnings;
use base 'Socialtext::Plugin';
use Socialtext::URI;
use Socialtext::AppConfig;
use Socialtext;
use File::Spec;
use YAML;

our $DEFAULT_SKIN_NAME = 's2';

sub class_id { 'skin' }

sub default_skin_name { return $DEFAULT_SKIN_NAME };

sub default_skin_path {
    my $self = shift;
    $self->_path('skin', $self->default_skin_name, @_);
}

sub default_skin_uri {
    my $self = shift;
    $self->_uri('skin', $self->default_skin_name, @_);
}

sub name {
    my $self = shift;
    $self->hub->current_workspace->skin_name;
}

sub skin_info {
    my $self = shift;
    return $self->{_skin_info} if $self->{_skin_info};
    my $skin_path = $self->skin_path;
    my $info_path = File::Spec->catfile( $skin_path, 'info.yaml' );
    $self->{_skin_info} = -f $info_path ? YAML::LoadFile($info_path) : {};
    $self->{_skin_info}{skin_type} ||= $self->default_skin_name;
    $self->{_skin_info}{skin_name} = $self->name;
    $self->{_skin_info}{skin_path} = $skin_path;
    return $self->{_skin_info};
}

sub common_css {
    my $self = shift;

    return $self->skin_info->{no_common}
        ? ''
        : $self->hub->css->uri_for_common_css
}

sub css_info {
    my ($self) = @_;
    return {
        common    => $self->common_css,
        screen    => $self->hub->css->uris_for_css('screen.css'),
        screen_ie => $self->hub->css->uris_for_css('screen.ie.css'),
        print     => $self->hub->css->uris_for_css('print.css'),
        wikiwyg   => $self->hub->css->uris_for_css('wikiwyg.css'),
        print_ie  => $self->hub->css->uris_for_css('print.ie.css'),
        popup     => $self->hub->css->uris_for_css('popup.css'),
        popup_ie  => $self->hub->css->uris_for_css('popup.ie.css'),
        plugin    => $self->hub->css->uris_for_plugin_css,
        local     => $self->hub->css->uris_for_additional_local_css,
        locale    => $self->hub->css->uris_for_additional_locale_css,
    };
}


sub skin_dir {
    my $self = shift;
    if ($self->hub->current_workspace->uploaded_skin) {
        my $ws = $self->hub->current_workspace->name;
        return "uploaded-skin/$ws";
    }
    else {
        my $skin = $self->name;
        return "skin/$skin";
    }
}

sub skin_upload_path {
    my $self = shift;
    my $ws = $self->hub->current_workspace->name;
    return $self->_path("uploaded-skin/$ws");
}

sub skin_path {
    my $self = shift;
    if (my $skin = shift) {
        return $self->_path('skin', $skin);
    }
    else {
        return $self->_path($self->skin_dir);
    }
}

sub skin_uri {
    my $self = shift;

    if (my $skin = shift) {
        return $self->_uri('skin', $skin);
    }
    else {
        return $self->_uri($self->skin_dir);
    }
}

sub customjs {
    my $self = shift;
    my ($uri, $name);

    # Ignore customjs_name and customjs_uri if we're using an uploaded skin
    unless ($self->hub->current_workspace->uploaded_skin) {
        $uri = $self->hub->current_workspace->customjs_uri;
        $name = $self->customjs_name;
    }

    return $uri if $uri;

    my $path = $self->skin_path($name);
    if (-f "$path/javascript/custom.js") {
        my $uri = $self->skin_uri($name);
        return "$uri/javascript/custom.js";
    }
}

sub skin_name {
    my $self = shift;
    require Apache::Cookie;
    return $self->{skin_name}
        if defined $self->{skin_name};
    my $skin_name;
    my $self_uri = Socialtext::URI::uri();
    if ( Apache::Cookie->can('fetch') ) {
        my $cookies = Apache::Cookie->fetch;
        if ($cookies) {
            my $cookie = $cookies->{'socialtext-skin'};
            if ($cookie) {
                $skin_name = $cookie->value;
            }
        }
    }
    return $skin_name ||
        $self->hub->current_workspace->skin_name;
}

sub cascade_css {
    my $self = shift;
    my $cascade = $self->skin_info->{cascade_css};
    return defined $cascade ? $cascade : 
                              $self->hub->current_workspace->cascade_css;
}

sub customjs_name {
    my $self = shift;
    return $self->skin_info->{customjs_name} ||
        $self->hub->current_workspace->customjs_name;
}

sub header_logo_image_uri {
    my $self = shift;

    my $logo_file = Socialtext::File::catfile(
        Socialtext::AppConfig->code_base(), 'images',
        $self->skin_name, 'logo-bar-12.gif' );

    if ( -f $logo_file ) {
        return join '/',
            Socialtext::Helpers->static_path,
            'images',
            $self->skin_name,
            'logo-bar-12.gif';
    }

    return join '/',
        Socialtext::Helpers->static_path,
        'images',
        'logo-bar-12.gif';
}


sub _path {
    my $self = shift;
    return File::Spec->catdir( Socialtext::AppConfig->code_base, @_ );
}

sub _uri {
    my $self = shift;
    return join('/', '', 'static', Socialtext->product_version(), @_);
}

1;
