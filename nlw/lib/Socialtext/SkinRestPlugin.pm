# @COPYRIGHT@
package Socialtext::SkinRestPlugin;
use strict;
use warnings;
no warnings 'redefine';

use base 'Socialtext::Plugin';

use Class::Field qw(field const);
use LWP::UserAgent;
use Socialtext::Resting;
use JSON::XS;
use YAML;
use Template;

const class_id => 'skin_rest';
const cgi_class => 'Socialtext::SkinRest::CGI';

field 'rester', -init => '$self->init_st_rest';
field 'stash';

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(action => 'skin_handler_rest');
}

sub skin_handler_rest {
    my $self = shift;

    my $config = $self->hub->skin->skin_info;

    # XXX Hardcoded defaults for now...
    my $action = $self->cgi->action || 'display';
    my $workspace = $self->cgi->workspace
        || $self->hub->current_workspace->name
        || 'admin';

    $self->rester->accept('text/html');
    $self->rester->workspace( $workspace );

    my $data = $self->stash( $config->{actions}{$action} );

    return "ERROR: can't handle $action" unless $self->can("handle_$action");

    $self->can("handle_$action")->($self);

    my $template = $data->{template};
    my $tt2 = Template->new({
        INCLUDE_PATH => $config->{skin_path} . '/template',
        WRAPPER => 'wrapper.tt',
    });

    my $output = '';
    $tt2->process(
        $template,
        {
            header_template => 'header.html',
            %{$data},
            workspace => $workspace,
        },
        \$output,
    );

    return $output;
}

sub handle_changes {
    my $self = shift;
    my $rester = $self->rester;
    my $data   = $self->stash;
    $rester->count( $self->cgi->count || 20);
    $rester->order("newest");
    $rester->accept('application/json');
    $rester->get_pages();
    $data->{pages} = decode_json($rester->response->content)
}

sub handle_display {
    my $self = shift;
    my $rester = $self->rester;
    my $data   = $self->stash;

    my $page_name = $self->cgi->page_name
        || $rester->get_homepage();

    $rester->accept('application/json');
    $rester->_get_things(
        'page',
        pname => $page_name,
    );

    unless ($rester->response->is_success) {
        $data->{title} = "$page_name not found";
        $data->{page_html} = "";
        return;
    }

    $data->{page} = decode_json($rester->response->content);
    $data->{title} = $data->{page}{name};
    
    $rester->accept('text/html');
    $rester->_get_things(
        'page',
        pname => $page_name,
        _query => { 
            'link_dictionary' => 'Skin'
        }
    );
    $data->{page_html} = $rester->response->content;
    $data->{page_name} = $page_name;
}

sub handle_edit {
    my $self = shift;
    my $rester = $self->rester;
    my $data   = $self->stash;

    my $page_name = $self->cgi->page_name
        || $rester->get_homepage();

    $rester->accept('text/x.socialtext-wiki');
    $rester->_get_things(
        'page',
        pname => $page_name,
    );
    $data->{page_wikitext} = $rester->response->content;
    $data->{title} = "Editing $page_name";
    $data->{page_name} = $page_name;
}

sub handle_edit_save {
    my $self = shift;
    my $rester = $self->rester;
    my $data   = $self->stash;

    my $page_name = $self->cgi->page_name
        || $rester->get_homepage();

    my $content = $self->cgi->content;
    $rester->put_page( $page_name, $content );

    my $workspace = $self->cgi->workspace;

    $self->redirect(
        "http:?action=display;workspace=$workspace;page_name=$page_name"
    );
}

sub handle_logout {
    my $self = shift;
    if ( Apache::Cookie->can('fetch') ) {
        my $cookies = Apache::Cookie->fetch;
        if ($cookies) {
            my $cookie = $cookies->{'NLW-user'};
            $cookie->expires("-1d");
            $cookie->bake;
        }
    }
}

sub handle_tags {
    my $self = shift;
    $self->rester->accept('application/json');
    $self->rester->get_workspace_tags;
    $self->stash->{tags} = decode_json( $self->rester->response->content );
}

sub handle_workspaces {
    my $self = shift;
    $self->rester->accept('application/json');
    $self->rester->get_workspaces;
    $self->stash->{workspaces} = decode_json($self->rester->response->content);
}

sub init_st_rest {
    my $self = shift;
    my $Rester = Socialtext::Resting->new(
        server   => $self->hub->cgi->base_uri
    );

    if ( Apache::Cookie->can('fetch') ) {
        my $cookies = Apache::Cookie->fetch;
        if ($cookies) {
            my $cookie = $cookies->{'NLW-user'};
            if ($cookie) {
                $Rester->cookie($cookie->as_string);
            }
        }
    }

    return $Rester;
}

package Socialtext::SkinRest::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'action';
cgi 'workspace';
cgi 'page_name';
cgi 'count';
cgi 'edit';
cgi 'content';

1;
