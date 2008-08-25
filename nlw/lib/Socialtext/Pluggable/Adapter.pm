package Socialtext::Pluggable::Adapter;
# @COPYRIGHT@
use strict;
use warnings;

our @libs;
our $AUTOLOAD;
my %hooks;

use base 'Socialtext::Plugin';
use Socialtext::Workspace;
use Fcntl ':flock';
use File::chdir;
use Module::Pluggable search_path => ['Socialtext::Pluggable::Plugin'],
                      search_dirs => \@libs;
use Socialtext::Pluggable::WaflPhrase;

BEGIN {
    our $code_base = Socialtext::AppConfig->code_base;
    push @INC, glob("$code_base/plugin/*/lib");
}

sub AUTOLOAD {
    my ($self,$rest_handler,$args) = @_;
    my $type = ref($self)
        or die "$self is not an object in " . __PACKAGE__ . "\n";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;    # strip fully-qualified portion
    return if $name eq 'DESTROY';
    
    my ($hook_name) = $name =~ /_rest_hook_(.*)/;
    die "Not a REST hook call '$name'\n" unless $hook_name;

    $self->register_rest;

    $self->make_hub($rest_handler->user);

    $self->{_rest_handler} = $rest_handler;

    return $self->hook($hook_name, $args);
}

sub handler {
    my ($self, $rest) = @_;
    my $t = time;

    $self->make_hub($rest->user) unless $self->hub;

    if ($rest->query->param('action')) {
        my $res = $self->hub->process;
        $rest->header($self->hub->rest->header);
        return $res;
    }
    elsif (exists $hooks{root}) {
        my $res = $self->hook('root', $rest);
        $rest->header($self->hub->rest->header);
        return $res;
    }
    else {
        my $nowork = Socialtext::Rest::NoWorkspace->new($rest);
        return $nowork->handler($rest);
    }
}

sub make_hub {
    my ($self,$user,$ws) = @_;
    my $main = Socialtext->new;
    $main->load_hub(
        current_user => $user,
        current_workspace => $ws || Socialtext::NoWorkspace->new,
    );
    $main->hub->registry->load;
    $main->debug;
    $self->hub( $self->{made_hub} = $main->hub );
}

sub class_id { 'pluggable' };
sub class_title { 'Pluggable' };

for my $plugin (__PACKAGE__->plugins) {
    eval "require $plugin";
    die $@ if $@;
    $plugin->register;
}

sub make {
    my $class = shift;
    my $dir = Socialtext::File::catdir(
        Socialtext::AppConfig->code_base(),
        'plugin',
    );
    for my $plugin ($class->plugins) {
        my $name = $plugin->name;
        local $CWD = "$dir/$name";
        next unless -f 'Makefile';

#         my $semaphore = "$dir/build-semaphore";
#         open( my $lock, ">>", $semaphore )
#             or die "Could not open $semaphore: $!\n";
#         flock( $lock, LOCK_EX )
#             or die "Could not get lock on $semaphore: $!\n";
#         system( 'make', 'all' ) and die "Error calling make in $dir/$name: $!";
#         close($lock);
    }
}

sub rest_hooks {
    my $class = shift;
    my @rest_hooks;
    for my $plugin ($class->plugins) {
        push @rest_hooks, $plugin->rests;
    }
    return @rest_hooks;
}

sub register {
    my ($self,$registry) = @_;

    my @plugins = sort { $b->priority <=> $a->priority }
                  $self->plugins;

    for my $plugin (@plugins) {
        for my $hook ($plugin->hooks) {
            my ($type, @parts) = split /\./, $hook->{name};

            if ($type eq 'wafl') {
                $registry->add(
                    'wafl', $parts[0], 'Socialtext::Pluggable::WaflPhrase',
                );
            }
            elsif ($type eq 'action') {
                no strict 'refs';
                my $class = ref $self;
                my $action = $parts[0];
                my $sub = "${class}::$action";

                *{$sub} = sub { return $_[0]->hook($hook->{name}) };
                $registry->add(action => $action);
            }

            push @{$hooks{$hook->{name}}}, $hook;
        }
    }
}

sub register_rest {
    my $self = shift;
    return if $self->{_registered_rest}++;
    for my $plugin ($self->plugins) {
        for my $hook ($plugin->rest_hooks) {
            push @{$hooks{$hook->{name}}}, $hook;
        }
    }
}

sub registered {
    my ($self, $name) = @_;
    return exists $hooks{$name};
}

sub hook {
    my ( $self, $name, @args ) = @_;
    if ( my $hooks = $hooks{$name} ) {
        my $hook = $hooks->[0];
        return unless $hook;
        my $method = $hook->{method};
        $hook->{obj} ||= $hook->{class}->new();
        $hook->{obj}->hub( $self->hub || $self->{made_hub});
        $hook->{obj}->rest( delete $self->{_rest_handler} );
        return $hook->{obj}->$method(@args);    # do some magic here
    }
}

return 1;
