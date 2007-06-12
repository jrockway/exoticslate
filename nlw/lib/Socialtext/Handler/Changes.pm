# @COPYRIGHT@
package Socialtext::Handler::Changes;
use strict;
use warnings;

use Apache;
use base 'Socialtext::Handler::Cool';

use Apache::Constants qw(HTTP_UNAUTHORIZED OK);
use Socialtext::Authz;
use Socialtext::Permission;


sub workspace_uri_regex { qr{(?:/lite)?/changes/([^/]+)} }

sub _handle_get {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;
    return $class->_retrieve_changes($r, $nlw);
}

sub _retrieve_changes {
    my $class    = shift;
    my $r        = shift;
    my $nlw      = shift;
    my $category = $class->_get_category( $r, $nlw );

    my $accept =$r->header_in('Accept');

    my $output;
    my $type = $class->type_for_accept($accept);

    if ($category and $type eq 'application/atom+xml') {
        $type = 'application/atom+xml';
        $output = $class->_atom_changes($r, $nlw, $category);
    }
    else  {
        $output = $class->_changes_html( $r, $nlw, $category );
    }

    # XXX blech, hate multi returns
    return $output, $type;
}

sub _changes_html {
}

sub _get_category {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;

    # XXX this regexp will need to change
    my ($category) = ( $r->uri =~ m{/changes/[^\/]+/([^?]+)\??.*$} );
    $category ||= 'recent changes';
    return lc($category);
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

