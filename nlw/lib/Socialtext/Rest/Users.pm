package Socialtext::Rest::Users;
# @COPYRIGHT@

use warnings;
use strict;

use Class::Field qw( const field );
use Socialtext::JSON;
use Socialtext::HTTP ':codes';
use Socialtext::User;
use Socialtext::Exceptions;
use Socialtext::User::Find;

use base 'Socialtext::Rest::Collection';

sub allowed_methods {'GET, POST'}

field errors        => [];

sub if_authorized {
    my $self = shift;
    my $method = shift;
    my $call = shift;

    if ($method eq 'POST') {
        return $self->not_authorized
            unless $self->_user_is_business_admin_p;
    }
    elsif ($method eq 'GET') {
        return $self->not_authorized
            if ($self->rest->user->is_guest);
    }
    else {
        return $self->bad_method;
    }

    return $self->$call(@_);
}

sub POST_json {
    my $self = shift;
    return $self->if_authorized('POST', '_POST_json', @_);
}

sub _POST_json {
    my $self = shift;
    my $rest = shift;

    my $create_request_hash = decode_json($rest->getContent());

    unless ($create_request_hash->{username} and
            $create_request_hash->{email_address}) 
    {
        $rest->header(
            -status => HTTP_400_Bad_Request,
            -type   => 'text/plain',
        );
        return "username, email_address required";
    }
    
    my ($new_user) = eval {
        Socialtext::User->create(
            %{$create_request_hash},
            creator => $self->rest->user()
        );
    };

    if (my $e = Exception::Class->caught('Socialtext::Exception::DataValidation')) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
            -type   => 'text/plain'
        );
        return join("\n", $e->messages);
    }
    elsif ($@) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
            -type   => 'text/plain'
        );
        # REVIEW: what kind of system logging should we be doing here?
        return "$@";
    }

    $rest->header(
        -status   => HTTP_201_Created,
        -type     => 'application/json',
        -Location => $self->full_url('/', $new_user->username()),
    );
    return '';
}

sub get_resource {
    my $self = shift;
    my $rest = shift;

    my $limit = $self->rest->query->param('count') ||
                $self->rest->query->param('limit') ||
                25;
    my $offset = $self->rest->query->param('offset') || 0;

    my $filter = $self->rest->query->param('filter');

    my $results = [];
    my $f = eval { 
        Socialtext::User::Find->new(
            viewer => $self->rest->user,
            limit => $limit,
            offset => $offset,
        )
    };
    if ($@) {
        warn $@;
        $rest->header(
            -status => HTTP_400_Bad_Request,
            -type   => 'text/plain'
        );
        return "Bad request or illegal filter options";
    }

    $results = eval {
        $f->typeahead_find($self->rest->query->param('filter'));
    };
    if ($@) {
        warn $@;
        $rest->header(
            -status => HTTP_400_Bad_Request,
            -type   => 'text/plain'
        );
        return "Illegal filter or query error";
    }

    return $results;
}

1;
