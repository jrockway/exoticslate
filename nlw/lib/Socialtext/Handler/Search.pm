# @COPYRIGHT@
package Socialtext::Handler::Search;
use strict;
use warnings;

use Apache;
use base 'Socialtext::Handler::Cool';

sub workspace_uri_regex { qr{(?:/lite)?/search/([^/]+)} }

sub _handle_get {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;
    return $class->_do_search( $r, $nlw );
}

# this currently only supports html
sub _do_search {
    my $class    = shift;
    my $r        = shift;
    my $nlw      = shift;
    my $apr      = Apache::Request->instance( $r );

    my $search_term = $apr->param('search_term');

    my $output = $class->_search_html( $r, $nlw, $search_term );

    # XXX blech, hate multi returns
    return $output, 'text/html';
}

sub _search_html {
}


1;

__END__

=head1 NAME

Socialtext::Handler::Changes - A Cool URI Interface to content changes in NLW

=head1 SYNOPSIS

    <Location /lite/changes/workspace>
        SetHandler  perl-script
        PerlHandler +Socialtext::Handler::Changes::Lite
    </Location>

=head1 DESCRIPTION

B<Socialtext::Handler::Changes> is intended to be a web interface to report
changes in NLW using URIs that make sense, are fairly stable, and
support multiple types of output. It is NOT DONE.

=head1 URIs

A URI for a page takes the form C</changes/workspace_id/category_id>.i
Depending on the incoming Accept header and the HTTP request method,
different things happen. See C<sub handler()> for now.

=cut

