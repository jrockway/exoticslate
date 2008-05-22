package Socialtext::Pluggable::Plugin;
# @COPYRIGHT@
use strict;
use warnings;

use Socialtext;
use Socialtext::TT2::Renderer;
use Socialtext::AppConfig;
use Class::Field qw(const field);
use Socialtext::URI;
use Socialtext::Storage::PSQL;
use Socialtext::AppConfig;
use Socialtext::JSON qw(encode_json);

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
    if ($self->rest) {
        return $self->rest->query;
    }
}

sub getContent {
    my $self = shift;
    if ($self->rest) {
        return $self->rest->getContent;
    }
}

sub getContentPrefs {
    my $self = shift;
    if ($self->rest) {
        return $self->rest->getContentPrefs;
    }
}

sub username {
    my $self = shift;
    if ($self->rest) {
        return $self->rest->user->username;
    }
    else {
        return $self->hub->current_user->username,
    }
}

sub header_out {
    my $self = shift;
    if ($self->rest) {
        return $self->rest->header(@_);
    }
    else {
        die "Not implemented!";
    }
}

sub header_in {
    my $self = shift;
    if ($self->rest) {
        if (@_) {
            return $self->rest->request->header_in(@_);
        }
        else {
            return $self->rest->request->headers_in;
        }
    }
    else {
        die "Not implemented!";
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
    return $self;
}

sub storage {
    my ($self,$id) = @_;
    die "Id is required for storage\n" unless $id;
    return Socialtext::Storage::PSQL->new($id);
}

sub name {
    my $self = shift;
    return $self->{_name} if ref $self and $self->{_name};

    (my $class = ref $self || $self) =~ s{::}{/}g;

    my $name = $INC{"$class.pm"} or die "$class.pm is not in your INC";
    $name =~ s{^$code_base/plugin/([^/]+).*$}{$1};
    $self->{_name} = $name if ref $self;
    return $name;
}

sub plugin_dir {
    my $self = shift;
    my $name = $self->name;
    return "$code_base/plugin/$name";
}

sub cgi_vars {
    my $self = shift;
    return $self->hub->cgi->vars;
}

sub redirect {
    my ($self,$target) = @_;
    unless ($target =~ /^(https?:|\/)/i or $target =~ /\?/) {
        $target = $self->hub->cgi->full_uri . '?' . $target;
    }
    $self->hub->headers->redirect($target);
}

sub template_render {
    my ($self, $template, %args) = @_;

    my %template_vars = $self->hub->main ?
                        $self->hub->helpers->global_template_vars :
                        ();

    my $name = $self->name;
    my $plugin_dir = $self->plugin_dir;
    my $share = "/nlw/plugin/$prod_ver";
    
    my $renderer = Socialtext::TT2::Renderer->instance;
    return $renderer->render(
        template => $template,
        paths => [ $self->plugin_dir . "/template" ],
        vars     => {
            share => "$share/$name",
            share_path => sub { 
                my $file = "$plugin_dir/share/$_[0]";
                if (-f $file) {
                    my $t = (stat $file)[9];
                    return "/nlw/plugin/$t/$name/$_[0]";
                }
                else {
                    return "$share/$name/$_[0]";
                }
            },
            workspaces => [$self->hub->current_user->workspaces->all],
            as_json => sub { encode_json(@_) },
            %template_vars,
            %args,
        },
    );
}

1;
