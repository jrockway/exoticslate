package Socialtext::Rest::Lite;
# @COPYRIGHT@

use strict;
use warnings;

use base 'Socialtext::Rest';

use Socialtext::Lite;
use Socialtext::Challenger;
use Socialtext::HTTP ':codes';
use Socialtext::Events;


# basically just a dispatcher to NLW::Lite
# need some deduping

sub not_authorized {
    my $self = shift;
    eval {
        Socialtext::Challenger->Challenge(
            request  => $self->rest->query,
            redirect => $self->rest->query->url(
                -absolute => 1, -path => 1, -query => 1
            ),
        );
    };
    if ( my $e = $@ ) {
        if ( Exception::Class->caught('Socialtext::WebApp::Exception::Redirect') )
        {
            my $location = $e->message;
            $self->rest->header(
                -status   => HTTP_302_Found,
                -Location => $location,
            );
            return '';
        }
    }
    $self->rest->header(
        -status => HTTP_500_Internal_Server_Error,
    );
    return 'Challenger Did not Redirect';
}

sub changes {
    my ( $self, $rest ) = @_;

    $self->if_authorized(
        'GET',
        sub {
            my $category = $self->_category_from_uri();
            my $content = Socialtext::Lite->new( hub => $self->hub )
                ->recent_changes($category);

            $rest->header(
                -status => HTTP_200_OK,
                -type   => 'text/html' . '; charset=UTF-8'
            );
            return $content;
        }
    );
}

sub category {
    my ( $self, $rest ) = @_;

    $self->if_authorized(
        'GET',
        sub {
            my $content = Socialtext::Lite->new( hub => $self->hub )
                ->category( $self->_category_from_uri );
            $rest->header(
                -status => HTTP_200_OK,
                -type   => 'text/html' . '; charset=UTF-8'
            );
            return $content;
        }
    );
}

sub search {
    my ( $self, $rest ) = @_;

    $self->if_authorized(
        'GET',
        sub {
            my $search_term = $rest->query->param('search_term');
            my $content
                = Socialtext::Lite->new( hub => $self->hub )->search($search_term);
            $rest->header(
                -status => HTTP_200_OK,
                -type   => 'text/html' . '; charset=UTF-8'
            );
            return $content;
        }
    );
}

sub get_page {
    my ( $self, $rest ) = @_;

    $self->if_authorized(
        'GET',
        sub {

            my $action = $rest->query->param('action');

            my $page = $self->_get_page();
            my $content;

            if ( $action && $action eq 'edit' ) {
                unless ( $self->user_can('edit') ) {
                    $rest->header(
                        -Location => $self->full_url,
                        -status  => HTTP_302_Found,
                    );
                    return '';
                }

                $content
                    = Socialtext::Lite->new( hub => $self->hub )->edit_action($page);
                $rest->header(
                    -status => HTTP_200_OK,
                    -type   => 'text/html' . '; charset=UTF-8'
                );
            }
            else {
                $content = Socialtext::Lite->new( hub => $self->hub )->display($page);
                $rest->header(
                    -status        => HTTP_200_OK,
                    -type   => 'text/html' . '; charset=UTF-8',
                    -Last_Modified => $self->make_http_date(
                        $page->modified_time()
                    ),
                );

                if ($page->exists) {
                    Socialtext::Events->Record({
                        event_class => 'page',
                        action => 'view',
                        page => $page,
                    });
                }
            }
            return $content;
        }
    );
}

sub edit_page {
    my ( $self, $rest ) = @_;


    unless ( $self->user_can('edit') ) {
        $rest->header(
            -Location => $self->full_url,
            -status   => HTTP_302_Found,
        );
        return '';
    }
    my $page = $self->_get_page();
    my $content = Socialtext::Lite->new( hub => $self->hub )->edit_save(
        page        => $page,
        content     => $rest->query->param('page_body') || '',
        revision_id => $rest->query->param('revision_id') || '',
        revision    => $rest->query->param('revision') || '',
        subject     => $rest->query->param('subject') || '',
    );

    # $html contains contention info
    if ( length($content) ) {
        $rest->header(
            -status => HTTP_200_OK,
            -type   => 'text/html' . '; charset=UTF-8',
        );
        return $content;
    }
    else {
        $rest->header(
            -Location => $self->full_url,
            -status   => HTTP_302_Found,
        );
        return '';
    }
}

sub _get_page {
    my $self = shift;

    my $page;
    # XXX should be able to use $self->pname or $self->page here
    # but had some issues. come back later
    if ( $self->params->{pname} ) {
        $page = $self->hub->pages->new_from_uri( $self->params->{pname} );
    }
    else {
        $page = $self->hub->pages->new_from_uri( $self->workspace->title );
    }

    return $page;
}

sub _category_from_uri {
    my $self = shift;

    # XXX why can't i get tag from self->tag?
    return $self->params->{tag};
}

1;

1;
