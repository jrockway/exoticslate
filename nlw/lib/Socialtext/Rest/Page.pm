package Socialtext::Rest::Page;
# @COPYRIGHT@

use strict;
use warnings;

# REVIEW: Can this be made into a Socialtext::Entity?
use base 'Socialtext::Rest';
use HTML::WikiConverter;
use JSON;
use Readonly;
use Socialtext::HTTP ':codes';

Readonly my $DEFAULT_LINK_DICTIONARY => 'REST';
Readonly my $S2_LINK_DICTIONARY      => 'S2';

$JSON::UTF8 = 1;

# REVIEW: When we get html, we're not getting <html><body> etc
# Is this good or bad?
sub make_GETter {
    my ( $content_type ) = @_;
    return sub {
        my ( $self, $rest ) = @_;

        $self->if_authorized(
            'GET',
            sub {
                if ( $self->page->content eq '' ) {
                    $rest->header(
                        -status => HTTP_404_Not_Found,
                        -type   => 'text/plain'
                    );
                    return $self->pname . ' not found';
                }
                else {
                    my @etag = ();

                    if ( $content_type eq 'text/x.socialtext-wiki' ) {
                        my $etag = $self->page->revision_id();
                        @etag = ( -Etag => $etag );

                        my $match_header
                            = $self->rest->request->header_in('If-None-Match');
                        if ($match_header && $match_header eq $etag ) {
                            $rest->header(
                                -status => HTTP_304_Not_Modified,
                                @etag,
                            );
                            return '';
                        }
                    }

                    $rest->header(
                        -status        => HTTP_200_OK,
                        -type          => $content_type . '; charset=UTF-8',
                        -Last_Modified => $self->make_http_date(
                            $self->page->modified_time()
                        ),
                        @etag,
                    );
                    return $self->page->content_as_type(
                        type => $content_type,

                        # FIXME: this should be a CGI paramter in some cases
                        link_dictionary => $self->_link_dictionary($rest),
                    );
                }
            }
        );
    };
}

{
    no warnings 'once';
    *GET_wikitext = make_GETter( 'text/x.socialtext-wiki' );
    *GET_html = make_GETter( 'text/html' );
}

# look in the link_dictionary query parameter to figure out
# how to format links
sub _link_dictionary {
    my $self = shift;
    my $rest = shift;

    # we want the default link dictionary in the REST to be REST, but in the
    # LinkDictionary system it is the one used by S2, but it has no name, so
    # do a little dance to make it work as you might want.
    my $link_dictionary = $rest->query->param('link_dictionary')
        || $DEFAULT_LINK_DICTIONARY;
    $link_dictionary = undef
        if lc($link_dictionary) eq lc($S2_LINK_DICTIONARY);

    return $link_dictionary;
}

# REVIEW: Can probably use similar Etag stuff in here
# not using the make_GETtter since we are getting different stuff here
sub GET_json {
    my $self = shift;
    my $rest = shift;


    $self->if_authorized(
        'GET',
        sub {
            my $verbose = $rest->query->param('verbose');

            my $link_dictionary = $self->_link_dictionary($rest);

            if ($self->page->active) {
                $rest->header(
                    -status => HTTP_200_OK,
                    -type   => 'application/json',
                );
                my $default_view      = sub { $self->page->hash_representation() };
                my $addtional_content = sub {
                    $self->page->content_as_type( type => $_[0],
                        link_dictionary => $_[1] );
                };

                return objToJson(
                    $verbose
                    ? {
                        %{ $default_view->() },
                        wikitext => $addtional_content->('text/x.socialtext-wiki'),
                        html     => $addtional_content->( 'text/html', $link_dictionary )
                        }
                    : $default_view->()
                );
            }
            else {
                $rest->header(
                    -status => HTTP_404_Not_Found,
                    -type   => 'text/plain',
                );
                return $self->pname . ' not found';
            }
        }
    );
}

sub DELETE {
    my ( $self, $rest ) = @_;

    return $self->no_workspace()   unless $self->workspace;

    $self->if_authorized(
        DELETE => sub {
            $self->page->delete( user => $rest->user );
            $rest->header( -status => HTTP_204_No_Content );
        }
    );
}

sub PUT_wikitext {
    my ( $self, $rest ) = @_;

    return $self->no_workspace() unless $self->workspace;
    return $self->not_authorized() unless $self->user_can('edit');

    my $existed_p = $self->page->content ne '';

    my $match_header = $self->rest->request->header_in('If-Match');
    if (   $existed_p
        && $match_header
        && ( $match_header ne $self->page->revision_id() ) ) {
        $rest->header(
            -status => HTTP_412_Precondition_Failed,
        );
        return '';
    }

    $self->page->update_from_remote(
        content => $rest->getContent(),
    );

    $rest->header(
        -status => $existed_p ? HTTP_204_No_Content : HTTP_201_Created,
        -Location => $self->full_url );
}

sub PUT_html {
    my ( $self, $rest ) = @_;

    return $self->no_workspace() unless $self->workspace;
    return $self->not_authorized() unless $self->user_can('edit');

    my $existed_p = $self->page->content ne '';

    my $html = $rest->getContent(),

    my $wc = new HTML::WikiConverter( dialect => 'Socialtext');
    my $wikitext = $wc->html2wiki( html => $html );

    $self->page->update_from_remote(
        content => $wikitext,
    );

    $rest->header(
        -status => $existed_p ? HTTP_204_No_Content : HTTP_201_Created,
        -Location => $self->full_url );
}

sub PUT_json {
    my ( $self, $rest ) = @_;

    return $self->no_workspace() unless $self->workspace;
    return $self->not_authorized() unless $self->user_can('edit');

    my $existed_p = $self->page->content ne '';

    my $content = $rest->getContent();
    my $object = jsonToObj( $content );

    $self->page->update_from_remote(
        content => $object->{content},
        from    => $object->{from},
        date    => $self->make_date_time_date($object->{date}),
        $object->{tags} ? (tags => $object->{tags}) : (),
    );

    $rest->header(
        -status => $existed_p ? HTTP_204_No_Content: HTTP_201_Created,
        -Location => $self->full_url
    );
}


sub allowed_methods { 'GET, HEAD, PUT, DELETE' }
