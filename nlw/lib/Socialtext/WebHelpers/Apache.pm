# @COPYRIGHT@
package Socialtext::WebHelpers::Apache;
use strict;
use warnings;

use Class::Field qw(field);

use Apache;
use Apache::Request;
use Carp ();
use Socialtext::String;
use URI::Escape ();

sub apr {
    Apache::Request->instance( Apache->request );
}

# Headers role
sub print {
    my $self = shift;
    my $content_type = $self->content_type;
    $content_type .= '; charset=' . $self->charset
      if $content_type =~ /^text/;
    $self->apr->content_type($content_type);
    for my $header qw(Content-Length Content-disposition Expires Pragma 
                      Cache-control Last-modified) {
        my $method = lc($header);
        $method =~ tr/-/_/;
        my $value = $self->$method;
        next unless defined $value;
        $self->apr->header_out( $header => $value );
    }
    $self->apr->send_http_header;
}

sub redirect {
    my $self = shift;
    if (@_) {
        $self->apr->header_out(Location => shift);
        $self->apr->status(302);
    }
    return $self->apr->header_out('Location');
}

sub set_all {
    my $self = shift;
    my %h = @_;

    $self->apr->header_out($_ => $h{$_}) for keys %h;
}

# CGI role
sub defined {
    my $self = shift;
    my $param = shift;
    defined $self->apr->param($param);
}

sub names {
    my $self = shift;
    $self->apr->param;
}

sub full_uri {
    my $self = shift;
    my $uri = $self->_full_uri;

    $uri->query(undef);

    return $uri->unparse;
}

sub base_uri {
    my $self = shift;
    my $uri  = $self->_full_uri;

    $uri->query(undef);
    $uri->path(undef);

    return $uri->unparse;
}

sub full_uri_with_query {
    my $self = shift; $self->_full_uri->unparse }

sub _full_uri {
    my $self = shift;
    my $uri = $self->apr->parsed_uri;

    $uri->hostname($self->apr->hostname);

    my $xfh = $self->apr->header_in('X-Forwarded-Host');
    if ( $xfh && ($xfh =~ /:(\d+)$/) ) {
        my $front_end_port = $1;
        if ( $front_end_port
            && ($front_end_port != 80) && ($front_end_port != 443) ) {
            $uri->port($front_end_port);
        }
    }
    $uri->scheme( $self->apr->dir_config('NLWHTTPSRedirect') ? 'https' : 'http' );

    return $uri;
}

sub query_string {
    my $self = shift;
    $self->apr->args
}

sub path_info {
    my $self = shift;
    $self->apr->path_info
}

sub _get_cgi_param {
    Carp::cluck( '_get_cgi_param called with undef as first param' )
        unless defined $_[1];
    my $self = shift; $self->apr->param(shift) }

sub _get_upload {
    my $self = shift;
    my $name = shift;

    my @handles = $self->apr->upload($name)
      or return;
    my @uploads = ();
    foreach my $handle (@handles) {
        push @uploads,
            {
                handle => $handle->fh,
                filename => $handle->filename,
                %{$handle->info},
            };
    }

    if (wantarray) {
        return @uploads;
    } else {
        return $uploads[0];
    }
}

1;

