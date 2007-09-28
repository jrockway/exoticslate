# @COPYRIGHT@
package Socialtext::Search::Config;
use warnings;
use strict;

use Class::Field qw(field);
use Socialtext::Paths;
use YAML;

=head1 NAME

Socialtext::Search::Config - Representation of a configuration object controlling the behavior of search.

=head1 DESCRIPTION

This object takes a configuration file and creates a configuration object for search methods to use to drive their behavior.

=cut

field 'config_file_name';
field 'directory_pattern';
field 'field_spec';
field 'index_type';
field 'mode';
field 'query_parser_method';
field 'hits_processor_method';
field 'search_engine';
field 'settings';
field 'search_box_snippet';
field 'key_generator';
field 'search_term_decorator';
field 'version';

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    my %p = @_;

    $p{mode} ||= 'live';

    $self->mode ($p{mode});
    $self->_load_search_config;
}

sub _load_search_config {
    my $self = shift;
    my $config_file =  File::Spec->catdir(  
                                Socialtext::AppConfig->config_dir(),
                                'search',
                                $self->mode . ".yaml");
    my $config;
    eval {
        $config = YAML::LoadFile($config_file);
    };
    if ($@) {
        return undef;
    }

    $self->config_file_name($config_file);
    $self->settings($config);
    $self->field_spec($config->{field_spec});
    $self->directory_pattern($config->{directory_pattern});
    $self->search_engine($config->{search_engine});
    $self->index_type($config->{index_type});
    $self->version($config->{version});
    $self->query_parser_method($config->{query_parser_method});
    $self->hits_processor_method($config->{hits_processor_method});
    $self->key_generator($config->{key_generator});
    $self->search_term_decorator($config->{search_term_decorator});
    $self->search_box_snippet($config->{search_box_snippet});

    return $self;
}

sub index_directory {
    my $self = shift;
    my %p = @_;
    my $directory = $self->directory_pattern;
    if ( $directory =~ /\%plugin_directory\%/ ) {
        my $plugin_dir = Socialtext::Paths::plugin_directory($p{workspace});
        $directory =~ s/\%plugin_directory\%/$plugin_dir/g;
    }

    my $system_plugin_dir = Socialtext::Paths::system_plugin_directory();
    $directory =~ s/\%system_plugin_directory\%/$system_plugin_dir/g;
    
    my $search_engine = $self->search_engine;
    $directory =~ s/\%search_engine\%/$search_engine/g;

    my $version = $self->version;
    $directory =~ s/\%version\%/$version/g;

    foreach my $key ( %p ) {
        $directory =~ s/\%$key\%/$p{$key}/g;
    }
    return $directory;
}

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
