package Socialtext::Pluggable::Plugin;
# @COPYRIGHT@
use strict;
use warnings;

use Socialtext::Storage;
use Socialtext::AppConfig;
use Socialtext::CGI;
use unmocked 'Cwd';
use unmocked 'File::Glob';

# Class Methods

my %hooks;
my %rests;

# perldoc Socialtext::URI for arguments
#    path = '' & query => {}

sub rest_hooks {}
sub add_content_type {}

sub query {
    my $self = shift;
    return $self->{_cgi} ||= Socialtext::CGI->new;
}

sub name {
    my $self = shift;
    ( my $name = ref $self || $self ) =~ s{::}{/}g;
    $name =~ s{^.*/}{} unless $name =~ s{^.*?/Plugin/}{}; 
    return lc $name;
}

sub plugins {
    my $self = shift;
    my $code_base = $self->code_base;
    return grep { s{$code_base/plugin/}{} }
           glob("$code_base/plugin/*");
}

sub make_uri {
  my ($self,%args) = @_;
  return 0;
}

sub code_base {
    return Socialtext::AppConfig->code_base;
}

sub current_workspace {
  my $self = shift;
  return 'admin';
}

sub add_rest {
    my ($self,%rest) = @_;
    my $class = ref($self) || $self;
    push @{$rests{$class}}, \%rest;
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
    return Socialtext::Storage->new($id);
}

sub plugin_dir {
    my $self = shift;
    my $name = shift || $self->name;
    my ($dir) = grep { -d $_ }
                map { "$_/plugin/$name" }
                $self->code_base,
                't/share',
                'share';
    return $dir;
}

sub share {
    my $self = shift;
    my $name = $self->name;
    return "/nlw/plugin/3.0/$name";
}

sub username {
    my $self = shift;
    return $self->user->username;
}

sub user {
    my $self = shift;
    require Socialtext::User;
    return $self->{_user} ||= Socialtext::User->new;
}

sub cgi_vars {
    my $self = shift;
    $self->{_cgi_vars} = { @_ } if @_ or !$self->{_cgi_vars};
    return %{$self->{_cgi_vars}};
}

sub redirect {
    my ($self,$target) = @_;
    unless ($target =~ /^(https?:|\/)/i or $target =~ /\?/) {
        #$target = $self->hub->cgi->full_uri . '?' . $target;
    }
    #$self->hub->headers->redirect($target);
}

sub template_render {
    my ($self, $template, %args) = @_;

    my %template_vars = (); #$self->hub->main ?
    #$self->hub->helpers->global_template_vars :
    #                    ();

    warn "NO MAIN!!" unless %template_vars;

    #my $renderer = Socialtext::TT2::Renderer->instance;
    #return $renderer->render(
    #    template => $template,
    #    paths => [ $self->plugin_dir . "/template" ],
    #    vars     => {
    #        as_json => sub { encode_json($_[0]) },
    #        %template_vars,
    #        %args,
    #    },
    #);
}

1;
