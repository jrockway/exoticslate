# @COPYRIGHT@
package Socialtext::Handler::Search::Full;
use strict;
use warnings;

use base 'Socialtext::Handler::Search';

# XXX _completely_ untested

sub _search_html {
    my $class       = shift;
    my $r           = shift;
    my $nlw         = shift;
    my $search_term = shift;

    my $search_plugin = $nlw->hub->search;

    $nlw->hub->action('search');
    my %sortdir = %{$search_plugin->sortdir};
    $search_plugin->search_for_term($search_term);
    $search_plugin->result_set($search_plugin->sorted_result_set(\%sortdir));
    return $search_plugin->display_results(\%sortdir);
}

1;

__END__

=head1 NAME

Socialtext::Handler::Search::Full - A part of a Cool URI Interface to NLW with a complex user interface

=head1 SYNOPSIS

    <Location /changes>
        SetHandler  perl-script
        PerlHandler +Socialtext::Handler::Search::Full
    </Location>

=head1 DESCRIPTION

=head1 URIs

A URI for search takes the form C</search/workspace_id?search_term=<search_term>.

=cut

