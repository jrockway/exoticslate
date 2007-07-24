# @COPYRIGHT@
package Socialtext::WebHelpers::CGIpm;
use strict;
use warnings;

use Class::Field qw(field);

use CGI;
use CGI::Util;
use Socialtext::String;

# Headers role
field redirect => '';

sub print {
    my $self = shift;
    my $headers = $self->_get;
    $self->utf8_encode($headers);
    print $headers;
}

sub _get {
    my $self = shift;
    $self->redirect
    ? CGI::redirect($self->redirect)
    : CGI::header($self->_value);
}

# Inherited from Socialtext - not yet used outside of NLW code or tested
sub set_all {
    my $self = shift;
    my %h = @_;

    for my $k (keys %h) {
        $self->{extra}{$k} = $h{$k};
    }
}

sub _value {
    my $self = shift;
    (
        -charset => $self->charset,
        -type => $self->content_type,
        -expires => $self->expires,
        -pragma => $self->pragma,
        -cache_control => $self->cache_control,
        -last_modified => $self->last_modified,
        (defined $self->content_disposition
            ? ( -content_disposition => $self->content_disposition )
            : ()),
        %{$self->{extra} || {}},
    );
}

# CGI role
sub defined {
    my $self = shift;
    my $param = shift;
    defined CGI::param($param) or defined CGI::url_param($param);
}

sub names {
    my $self = shift;
    my %h = CGI::Vars();
    return keys %h;
}

sub full_uri {
    my $self = shift; CGI::url(-full => 1) }

sub full_uri_with_query {
    my $self = shift; CGI::url(-full => 1, -query => 1) }

sub query_string {
    my $self = shift; CGI::query_string() }

sub path_info {
    my $self = shift; CGI::path_info() }

sub _get_cgi_param {
    my $self = shift;
    my $field = shift;

    return
      defined CGI::param($field)
        ? CGI::param($field)
        : CGI::url_param($field);
}

sub _get_upload {
    my $self = shift;

    my $handle = CGI::upload($_[0])
      or return;
    {handle => $handle, filename => $handle, %{CGI::uploadInfo($handle) || {}}};
}

1;

