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
my $code_base = Socialtext::AppConfig->code_base;

# Class Methods

my %hooks;
my %rest_hooks;
my %rests;

const priority => 100;
field hub => -weak;
field 'rest';

# perldoc Socialtext::URI for arguments
#    path = '' & query => {}

sub uri {
    my $self = shift;
    return $self->hub->current_workspace->uri . Socialtext::AppConfig->script_name;
}

sub make_uri {
    my ( $self, %args ) = @_;
    return Socialtext::URI::uri(%args);
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

sub hooks {
    my $self = shift;
    my $class = ref($self) || $self;
    return $hooks{$class} ? @{$hooks{$class}} : ();
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

    (my $class = ref $self || $self) =~ s{::}{/}g;

    # Here we attempt to find the lower-cased plugin name based on the
    # last part(s) of the class name.
    my $name = $class;
    if ($name =~ s{^.*?/Plugin/}{}) {
        # Turn Socialtext::Pluggable::Plugin::Foo into "foo".
        # Turn Socialtext::Pluggable::Plugin::Foo::Bar into "foo/bar".
        $name = lc($name);
    }
    else {
        # Otherwise simply take the last component from module name.
        $name =~ s{^.*/}{};
    }

    $self->{_name} = $name if ref $self;
    return $name;
}

sub plugins {
    my $self = shift;
    return $self->hub->pluggable->plugin_list;
}

sub plugin_dir {
    my $self = shift;
    my $name = shift || $self->name;
    return "$code_base/plugin/$name";
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
    push @$paths, glob("$code_base/plugin/*/template");

    my $renderer = Socialtext::TT2::Renderer->instance;
    return $renderer->render(
        template => $template,
        paths => $paths,
        vars     => {
            share => $self->share,
            workspaces => [$self->hub->current_user->workspaces->all],
            as_json => sub { encode_json(@_) },
            %template_vars,
            %args,
        },
    );
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

1;
