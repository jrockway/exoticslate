# @COPYRIGHT@
package Socialtext::EventListener::Registry;
use strict;
use warnings;

use Socialtext::AppConfig;
use YAML 'LoadFile';

our %Listeners;

my $config_file
    = File::Spec->catdir( Socialtext::AppConfig->config_dir, 'event_listeners.yaml' );

{
    my $loaded = 0;

    sub load {
        my $class = shift;

        return if $loaded++;

        $class->_force_load();
    }
}

sub _force_load {
    my $class = shift;

    %Listeners = %{ LoadFile($config_file) };
}

1;
