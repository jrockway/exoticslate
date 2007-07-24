# @COPYRIGHT@
package Socialtext::Handler::Changes::Full;
use strict;
use warnings;

use base 'Socialtext::Handler::Changes';

sub _changes_html {
    my $class    = shift;
    my $r        = shift;
    my $nlw      = shift;
    my $category = shift;

    my $changes_plugin = $nlw->hub->recent_changes;

    my $result_set = $changes_plugin->get_recent_changes_in_category(
        category => $category,
    );
    $changes_plugin->result_set($result_set);
    $changes_plugin->write_result_set;
    my %sortdir = %{$changes_plugin->sortdir};

    # So the templates can know what to do
    $nlw->hub->action('recent_changes');
    use Data::Dumper;
    warn Dumper $changes_plugin->result_set;
    return $changes_plugin->display_results( \%sortdir );
}

1;

__END__

=head1 NAME

Socialtext::Handler::Changes::Full - A part of a Cool URI Interface to NLW with a complex user interface

=head1 SYNOPSIS

    <Location /changes>
        SetHandler  perl-script
        PerlHandler +Socialtext::Handler::Changes::Full
    </Location>

=head1 DESCRIPTION

=head1 URIs

A URI for changes takes the form C</changes/workspace_id/category_id>, where
category_id is optional.

=cut

