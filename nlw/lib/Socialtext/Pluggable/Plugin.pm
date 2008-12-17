package Socialtext::Pluggable::Plugin;
# @COPYRIGHT@
use strict;
use warnings;

use Socialtext;
use Socialtext::HTTP ':codes';
use Socialtext::TT2::Renderer;
use Socialtext::AppConfig;
use Class::Field qw(const field);
use Socialtext::URI;
use Socialtext::Storage;
use Socialtext::AppConfig;
use Socialtext::JSON qw(encode_json);
use Socialtext::User;
use URI::Escape ();
use Socialtext::Formatter::Parser;
use Socialtext::Cache;
use Socialtext::Authz::SimpleChecker;
my $prod_ver = Socialtext->product_version;

# Class Methods

my %hooks;
my %content_types;
my %rest_hooks;
my %rests;

const priority => 100;
field hub => -weak;
field 'rest';
field 'declined';

sub dependencies { }

sub scope { 'account' }

# perldoc Socialtext::URI for arguments
#    path = '' & query => {}

sub uri {
    my $self = shift;
    return $self->hub->current_workspace->uri . Socialtext::AppConfig->script_name;
}

sub base_uri {
    my $self = shift;
    return $self->{_base_uri} if $self->{_base_uri};
    ($self->{_base_uri} = $self->make_uri) =~ s{/$}{};
    return $self->{_base_uri};
}

sub make_uri {
    my $self = shift;
    return Socialtext::URI::uri(@_);
}

sub code_base {
   return Socialtext::AppConfig->code_base;
}

sub query {
    my $self = shift;
    return $self->hub->rest->query;
}

sub query_string {
    my $self = shift;
    return $self->hub->cgi->query_string;
}

sub getContent {
    my $self = shift;
    return $self->hub->rest->getContent;
}

sub getContentPrefs {
    my $self = shift;
    return $self->hub->rest->getContentPrefs;
}

sub user {
    my $self = shift;
    return $self->hub->current_user;
}

sub username {
    my $self = shift;
    return $self->user->username;
}

sub best_full_name {
    my ($self,$username) = @_;
    my $person = eval { Socialtext::User->Resolve($username) };
    return $person
        ? $person->guess_real_name()
        : $username;
}

sub header_out {
    my $self = shift;
    my $rest = $self->rest || $self->hub->rest;
    return $rest->header(@_);
}

sub header_in {
    my $self = shift;
    my $rest = $self->rest || $self->hub->rest;
    if (@_) {
        return $rest->request->header_in(@_);
    }
    else {
        return $rest->request->headers_in;
    }
}

sub current_page {
  my $self = shift;

  return $self->hub->pages->current;
}

sub current_workspace {
  my $self = shift;
  return $self->hub->current_workspace->name;
}

sub add_rest {
    my ($self,$path,$sub) = @_;
    my $class = ref($self) || $self;
    push @{$rests{$class}}, {
        $path => [ 'Socialtext::Pluggable::Adapter', "_rest_hook_$sub"],
    };
    push @{$rest_hooks{$class}}, {
        method => $sub,
        name => $sub,
        class => $class,
    };
}

sub add_hook {
    my ($self,$hook,$method) = @_;
    my $class = ref($self) || $self;
    push @{$hooks{$class}}, {
        method => $method,
        name => $hook,
        class => $class,
    };
}

sub add_content_type {
    my ($self,$name,$visible_name) = @_;
    my $class = ref($self) || $self;
    my $types = $content_types{$class};
    $visible_name ||= ucfirst $name;
    $content_types{$class}{$name} = $visible_name;
}

sub hooks {
    my $self = shift;
    my $class = ref($self) || $self;
    return $hooks{$class} ? @{$hooks{$class}} : ();
}

sub content_types {
    my $self = shift;
    my $class = ref($self) || $self;
    return $content_types{$class}
}

sub rest_hooks {
    my $self = shift;
    my $class = ref($self) || $self;
    return $rest_hooks{$class} ? @{$rest_hooks{$class}} : ();
}

sub rests {
    my $self = shift;
    my $class = ref($self) || $self;
    return $rests{$class} ? @{$rests{$class}} : ();
}

# Object Methods

sub new {
    my ($class, %args) = @_;
    # TODO: XXX: DPL, not sure what args are required but because the object
    # is actually instantiated deep inside nlw we can't just use that data
    my $self = {
#        %args,
    };
    bless $self, $class;
    $self->{Cache} = Socialtext::Cache->cache('ST::Pluggable::Plugin');
    return $self;
}

sub storage {
    my ($self,$id) = @_;
    die "Id is required for storage\n" unless $id;
    return Socialtext::Storage->new($id, $self->user->user_id);
}

sub name {
    my $self = shift;

    return $self->{_name} if ref $self and $self->{_name};

    my $class = ref $self || $self;
    my $name = $class->_transform_classname(
        sub { lc( shift ) }
    );

    $self->{_name} = $name if ref $self;
    return $name;
}

sub title {
    my $self = shift;

    return $self->{_title} if ref $self and $self->{_title};

    my $class = ref $self || $self;
    my $title = 'Socialtext ' . $class->_transform_classname(
        sub { shift }
    );

    $self->{_title} = $title if ref $self;
    return $title;
}

sub _transform_classname {
    my $self     = shift;
    my $callback = shift;

    ( my $name = ref $self || $self ) =~ s{::}{/}g;

    # Pull off everything from the name up to and including 'Plugin/',
    # if we can't do that, we should just return everything after the last
    # '/'.
    $name =~ s{^.*/}{}
        unless $name =~ s{^.*?/Plugin/}{}; 

    return &$callback( $name );
}

sub plugins {
    my $self = shift;
    # XXX: should the list be limited like this?
    return grep { $self->user->can_use_plugin($_) }
           $self->hub->pluggable->plugin_list;
}

sub plugin_dir {
    my $self = shift;
    my $name = shift || $self->name;
    return $self->code_base . "/plugin/$name";
}

sub cgi_vars {
    my $self = shift;
    return $self->hub->cgi->vars;
}

sub full_uri {
    my $self = shift;
    return $self->hub->cgi->full_uri_with_query;
}

sub redirect {
    my ($self,$target) = @_;
    unless ($target =~ /^(https?:|\/)/i or $target =~ /\?/) {
        $target = $self->hub->cgi->full_uri . '?' . $target;
    }

    $self->header_out(
        -status => HTTP_302_Found,
        -Location => $target,
    );
    return;
}

sub logged_in {
    my $self = shift;
    return !$self->hub->current_user->is_guest()
}

sub share {
    my $self = shift;
    my $name = $self->name;
    return "/nlw/plugin/$prod_ver/$name";
}

sub template_render {
    my ($self, $template, %args) = @_;

    my %template_vars = $self->hub->helpers->global_template_vars;

    $self->header_out('Content-Type' => 'text/html; charset=utf-8');

    my $name = $self->name;
    my $plugin_dir = $self->plugin_dir;
    my $paths = $self->hub->skin->template_paths;
    push @$paths, glob($self->code_base . "/plugin/*/template");

    my $renderer = Socialtext::TT2::Renderer->instance;
    return $renderer->render(
        template => $template,
        paths => $paths,
        vars     => {
            share => $self->share,
            workspaces => [$self->hub->current_user->workspaces->all],
            as_json => sub {
                my $json = encode_json(@_);

                # hack so that json can be included in other <script> 
                # sections without breaking stuff
                $json =~ s!</script>!</scr" + "ipt>!g;

                return $json;
            },
            %template_vars,
            %args,
        },
    );
}

sub created_at {
    my $self = shift;
    my %p = (
        workspace_name => undef,
        page_name => undef,
        @_
    );

    my $page = $self->get_page(%p);
    return undef if (!defined($page));
    my $original_revision = $page->original_revision;
    return $original_revision->datetime_for_user;
}

sub created_by {
    my $self = shift;
    my %p = (
        workspace_name => undef,
        page_name => undef,
        @_
    );

    my $page = $self->get_page(%p);
    return undef if (!defined($page));
    my $original_revision = $page->original_revision;
    return $original_revision->last_edited_by;
}

sub get_revision {
    my $self = shift;
    my %p = (
        workspace_name => undef,
        page_name => undef,
        revision_id => undef,
        @_
    );

    return undef if (!$p{workspace_name} || !$p{revision_id} || !$p{page_name});

    my $page_id = $self->name_to_id($p{page_name});
    my $cache_key = "page $p{workspace_name} $page_id revision $p{revision_id}";
    my $revision = $self->value_from_cache($cache_key);
    return $revision if ($revision);

    my $workspace = Socialtext::Workspace->new( name => $p{workspace_name} );
    return undef if (!defined($workspace));
    my $auth_check = Socialtext::Authz::SimpleChecker->new(
        user => $self->hub->current_user,
        workspace => $workspace,
    );
    my $hub = $self->_hub_for_workspace($workspace);
    return undef unless defined($hub);
    if ($auth_check->check_permission('read')) {
        $revision = $hub->pages->new_page($page_id);
        $revision->revision_id($p{revision_id});
        $self->cache_value(
            key => $cache_key,
            value => $revision,
        );
    }
    else {
        return undef;
    }
    return $revision;
}

sub get_page {
    my $self = shift;
    my %p = (
        workspace_name => undef,
        page_name => undef,
        @_
    );

    return undef if (!$p{workspace_name} || !$p{page_name});

    my $page_id = $self->name_to_id($p{page_name});
    my $cache_key = "page $p{workspace_name} $page_id";
    my $page = $self->value_from_cache($cache_key);
    return $page if ($page);

    my $workspace = Socialtext::Workspace->new( name => $p{workspace_name} );
    return undef if (!defined($workspace));
    my $auth_check = Socialtext::Authz::SimpleChecker->new(
        user => $self->hub->current_user,
        workspace => $workspace,
    );
    my $hub = $self->_hub_for_workspace($workspace);
    return undef unless defined($hub);
    if ($auth_check->check_permission('read')) {
        $page = $hub->pages->new_page($page_id);
        $self->cache_value(
            key => $cache_key,
            value => $page,
        );
    }
    else {
        return undef;
    }
    return $page;
}

sub name_to_id {
    my $self = shift;
    my $id = shift;

    $id = '' if not defined $id;
    $id =~ s/[^\p{Letter}\p{Number}\p{ConnectorPunctuation}\pM]+/_/g;
    $id =~ s/_+/_/g;
    $id =~ s/^_(?=.)//;
    $id =~ s/(?<=.)_$//;
    $id =~ s/^0$/_/;
    $id = lc($id);
    return URI::Escape::uri_escape_utf8($id);
}

sub _hub_for_workspace {
    my ( $self, $workspace ) = @_;

    my $hub = $self->hub;
    if ( $workspace->name ne $self->hub->current_workspace->name ) {
        $hub = $self->value_from_cache('hub ' . $workspace->name);
        if (!$hub) {
            my $main = Socialtext->new();
            $main->load_hub(
                current_user      => $self->hub->current_user,
                current_workspace => $workspace
            );
            $main->hub->registry->load;

            $hub = $main->hub;
            $self->cache_value(
                key => 'hub ' . $workspace->name,
                value => $hub,
            );
        }
    }

    return $hub;
}

sub cache_value {
    my $self = shift;
    my %p = (
        key => undef,
        value => undef,
        @_
    );

    $self->{Cache}->set($p{key}, $p{value});
}

sub value_from_cache {
    my $self = shift;
    my $key = shift;

    return $self->{Cache}->get($key);
}

sub tags_for_page {
    my $self = shift;
    my %p = (
        page_name => undef,
        workspace_name => undef,
        @_
    );

    my @tags = ();
    my $page = $self->get_page(%p);
    if (defined($page)) {
        push @tags, @{$page->metadata->Category};
    }
    return ( grep { lc($_) ne 'recent changes' } @tags );
}

sub search {
    my $self = shift;
    my $term = shift;

    $self->hub->search->search_for_term(search_term => $term);
    return $self->hub->search->result_set;
}

sub is_hook_enabled {
    my $self = shift;
    my $hook_name = shift; # throw away here
    if ($self->scope eq 'always') {
        return 1;
    }
    elsif ($self->scope eq 'workspace') {
        my $ws = $self->hub ? $self->hub->current_workspace : undef;
        return 1 if $ws and  $ws->real and $ws->is_plugin_enabled($self->name);
    }
    elsif ($self->scope eq 'account') {
        my $user;
        eval {
            $user = $self->hub ? $self->hub->current_user : $self->rest->user;
        };
        return $user->can_use_plugin($self->name) if $user;
    }
    else {
        die 'Unknown scope: ' . $self->scope;
    }
}

sub format_link {
    my ($self, $link, %args) = @_;
    return $self->hub->viewer->link_dictionary->format_link(
        link => $link,
        url_prefix => $self->base_uri,
        %args,
    );
}

1;
