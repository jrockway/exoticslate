package Socialtext::Rest::Collection;
# @COPYRIGHT@

use strict;
use warnings;

use base 'Socialtext::Rest';
use JSON::XS;
use Socialtext::HTTP ':codes';

=head1 NAME

Socialtext::Rest::Collection - Base class for exposing collections via REST.

=head1 SYNOPSIS

    package Socialtext::Rest::MyCollection;

    use base 'Socialtext::Rest::Collection';

    sub get_resource {
        # Returns a listref of collection elements, each of which should be a
        # hashref containing both 'name' and 'uri' elements.
    }

    sub add_text_element {
        # Given a text/plain representation of some proposed element in the
        # collection, adds it.
    }

=cut

=head1 REQUEST METHODS

=head2 POST_text

Calls add_text_element with the text/plain representation it was given.

=cut

sub POST_text {
    my ( $self, $rest ) = @_;

    return $self->no_workspace() unless $self->workspace;
    return $self->not_authorized() unless $self->user_can('edit');

    my $location = $self->add_text_element($rest->getContent);
    $rest->header( -status    => HTTP_201_Created,
                   -type      => 'text/plain',
                   -Location  => $location );
    return "Added.";
}

=head2 GET_html, GET_json, GET_text

Returns representations of your resource in text/html, application/json, and
text/plain, respectively.

=cut

{
    no warnings 'once';
    *GET_html = _make_getter(\&resource_to_html, 'text/html');
    *GET_json = _make_getter(\&resource_to_json, 'application/json');
    *GET_text = _make_getter(\&resource_to_text, 'text/plain');
}

sub _make_getter {
    my ( $sub, $content_type ) = @_;
    return sub {
        my ( $self, $rest ) = @_;

        my $rv;
        eval {
            $rv = $self->if_authorized(
                'GET',
                sub {
                    # REVIEW: should eval this for errors
                    my $resource = $self->get_resource($rest);
                    $resource = [] unless @$resource; # protect against weird data
                    $rest->header(
                        -status        => HTTP_200_OK,
                        -type          => $content_type . '; charset=UTF-8',
                        -Last_Modified => $self->make_http_date(
                            $self->last_modified($resource)
                        )
                    );
                    $self->$sub($resource);
                }
            );
        };
        if (my $except = $@) {
            if ($except->isa('Socialtext::Exception::Auth')) {
                return $self->not_authorized;
            } elsif ($except->isa('Socialtext::Exception::NoSuchWorkspace')) {
                return $self->no_workspace;
            }
        }

        return $rv;
    };
}

sub new {
    my $proto = shift;

    my $class = ref($proto) || $proto;
    my $new_object = $class->SUPER::new(@_);

    return $new_object;
}


=head1 SUBCLASSING

The below methods may be overridden to specialize behaviour of a particular
implementation.

=cut

sub _initialize {
    my ( $self, $rest, $params ) = @_;

    $self->SUPER::_initialize($rest, $params);

    $self->{FilterParameters} = {
        'filter' => 'name',
        'name_filter' => 'name',
        'type' => 'type',
    };
}



=head3 $obj->get_resource($rest)

Returns a listref of the elements in this collection.  Each element should be a hashref containing both 'uri' and 'name' elements.

=cut
sub get_resource {
    my ($self) = @_;

    return [
        $self->_limit_collectable(
            $self->_sort_collectable(
                [ $self->_hashes_for_query ]
            )
        )
    ];
}

=head2 $obj->_hashes_for_query

Returns a list of HASHREFs corresponding to the current query.  By default,
this simply calls

    map { $obj->_entity_hash($_) } $obj->_entities_for_query

but subclasses can override this.

=cut

sub _hashes_for_query {
    my $self = shift;

    return map { $self->_entity_hash($_) } $self->_entities_for_query;
}

=head2 $obj->add_text_element($text);

POST_text calls this with a text/plain representation of an element to be
added to the collection.  If a new element was created, this should return the
URI of that new element.  If not, it should return undef.

=head2 $obj->last_modified($resource)

Returns a timestamp identifying when the current resource was last modified.
The default implementation just returns the current time.

=cut

sub last_modified { time }

=head2 $obj->collection_name

Returns a suitable name for this collection, such as "Tags for Admin wiki".

=cut

sub collection_name { 'Collection' }

=head2 $obj->element_list_item($element)

Returns an HTML representation of a single list item.  The passed in $element
is a hashref containing both values for both the 'uri' and 'name' keys.

=cut

# REVIEW: Does name need to be html escaped?
sub element_list_item { "<li><a href='$_[1]->{uri}'>$_[1]->{name}</a></li>\n" }

# FIXME: Add conversion of 'is_*' slots to 'true'/'false' values.
sub resource_to_html {
    my ( $self, $resource ) = @_;

    my $name = $self->collection_name;
    my $body = join '', map { $self->element_list_item($_) } @$resource;
    return (<< "END_OF_HEADER" . $body . << "END_OF_TRAILER");
<html>
<head>
<title>$name</title>
</head>
<body>
<h1>$name</h1>
<ul>
END_OF_HEADER
</ul>
</body>
</html>
END_OF_TRAILER
}

sub resource_to_json { encode_json($_[1]) }
sub resource_to_text { $_[0]->_resource_to_text($_[1]) }
sub _resource_to_text { join '', map { "$_->{name}\n" } @{$_[1]} }

sub allowed_methods { 'GET, HEAD, POST' }

sub filter_spec { return $_[0]->{FilterParameters}; }

sub create_filter {
    my $self = shift;

    my $filter_sub = sub { @_ };
    my %filter_field = %{ $self->filter_spec };
    while (my( $param, $field ) = each %filter_field) {
        my $param_value = $self->rest->query->param($param);
        if ($param_value) {
            my $old_filter_sub = $filter_sub;
            $filter_sub = sub {
                grep {$_->{$field} =~ /$param_value/i}
                &$old_filter_sub
            };
        }
    }

    return $filter_sub;
}

# Limit the results based on the count query parameter
sub _limit_collectable {
    my $self = shift;
    my $count = $self->rest->query->param('count');
    #my $filter = $self->rest->query->param('filter');
    #my $filter_sub = $filter
    #    ? sub {grep {$_->{name} =~ /$filter/i} @_}
    #    : sub { @_ };

    my $filter_sub = sub { @_ };
    my %filter_field = %{ $self->filter_spec };
    while (my( $param, $field ) = each %filter_field) {
        my $param_value = $self->rest->query->param($param);
        if ($param_value) {
            my $old_filter_sub = $filter_sub;
            $filter_sub = sub {
                grep {$_->{$field} =~ /$param_value/i}
                &$old_filter_sub
            };
        }
    }


    my $count_sub = $count
        ? sub {
        my $limit = $count - 1;
        $limit = ( $#_ < $limit ) ? $#_ : $limit;
        @_[ 0 .. $limit ];
        }
        : sub {@_};
    return &$count_sub( &$filter_sub(@_) );
}

# The default sorts available for the 'order' parameter.
# See _sort_collectable
sub SORTS {
    return +{
        alpha => sub {
            $Socialtext::Rest::Collection::a->{name}
                cmp $Socialtext::Rest::Collection::b->{name};
        },
        newest => sub {
            $Socialtext::Rest::Collection::b->{modified_time} <=>
                $Socialtext::Rest::Collection::a->{modified_time};
        },
    };
}

# Given a list of entities, orders them based on the 'order' query param.
sub _sort_collectable {
    my $self         = shift;
    my $entities_ref = shift;
    my $order        = $self->rest->query->param('order');

    my $sub = $self->SORTS->{$order} if $order;

    return $sub
        ? sort $sub @$entities_ref
        : @$entities_ref;
}

=head2 Sorting

In addition, each class has a constant hash SORT which contains
sort types paired with sort methods for that sort in the class using it.
If SORT is not defined in the class, the defaults described in
the parent class are used.

=cut

1;

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
