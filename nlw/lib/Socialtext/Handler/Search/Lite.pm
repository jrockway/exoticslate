# @COPYRIGHT@
package Socialtext::Handler::Search::Lite;
use strict;
use warnings;

use Apache;
use base 'Socialtext::Handler::Search';

use Socialtext::Lite;

sub _search_html {
    my $class       = shift;
    my $r           = shift;
    my $nlw         = shift;
    my $search_term = shift;
    return Socialtext::Lite->new( hub => $nlw->hub )->search($search_term);
}

1;

__END__

=head1 NAME

Socialtext::Handler::Search::Lite - A part of a Cool URI Interface to NLW with a minimal interface

=head1 SYNOPSIS

    <Location /lite/search>
        SetHandler  perl-script
        PerlHandler +Socialtext::Handler::Search::Lite
    </Location>

=head1 DESCRIPTION

=head1 URIs

A URI for changes takes the form C</lite/search/workspace_id?search_term>.

=cut

