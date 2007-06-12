# @COPYRIGHT@
package Socialtext::Handler::Category;
use strict;
use warnings;

use Apache;
use base 'Socialtext::Handler::Cool';

sub workspace_uri_regex { qr{(?:/lite)?/category/([^/]+)} }

sub _handle_get {
    my $class = shift;
    my $r = shift;
    my $nlw = shift;
    return $class->_handle_category($r, $nlw);
}

# doesn't yet do content negotiation
sub _handle_category {
    my $class    = shift;
    my $r        = shift;
    my $nlw      = shift;
    my $category = $class->_get_category( $r, $nlw );

    my $accept =$r->header_in('Accept');

    my $output = $class->_category_html( $r, $nlw, $category );

    return $output, 'text/html';
}

sub _category_html {
}

sub _get_category {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;

    # REVIEW: this regexp will need to change
    my ($category) = ( $r->uri =~ m{/category/[^\/]+/([^?]+)\??.*$} );
    return $category;
}

1;

__END__

=head1 NAME

Socialtext::Handler::Category - A Cool URI Interface to list categories in NLW

=head1 SYNOPSIS

    <Location /lite/category>
        SetHandler  perl-script
        PerlHandler +Socialtext::Handler::Category::Lite
    </Location>

=head1 DESCRIPTION

B<Socialtext::Handler::Category> is intended to be a web interface to report
categories and their contents in NLW using URIs that make sense, are
fairly stable, and support multiple types of output. It is NOT DONE.

=head1 URIs

A URI for a page takes the form C</category/workspace_id/category_id>.
Depending on the incoming Accept header and the HTTP request method,
different things happen. See C<sub handler()> for now.

=cut

