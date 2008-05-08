package Socialtext::Pluggable::Adapter;
# @COPYRIGHT@
use strict;
use warnings;

our @libs;
our $AUTOLOAD;
my %hooks;

use base 'Socialtext::Plugin';
use Module::Pluggable search_path => ['Socialtext::Pluggable::Plugin'],
                      search_dirs => \@libs, require => 1;
use Socialtext::Pluggable::WaflPhraseDiv;


BEGIN {
    our $code_base = Socialtext::AppConfig->code_base;
    @libs = glob("$code_base/../plugin/*/lib");
    push @INC, @libs;
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

    $self->make_hub(
        $rest_handler->user,
        Socialtext::Workspace->new( name => 'help-en' ),
    );

    $self->{_rest_handler} = $rest_handler;

    return $self->hook($hook_name, $args);
}

sub make_hub {
    my ($self,$user,$ws) = @_;
    my $main = Socialtext->new;
    $main->load_hub(
        current_user      => $user,
        current_workspace => $ws,
    );
    $main->hub->registry->load;
    $main->debug;
    $self->{made_hub} = $main->hub;
}


sub class_id { 'pluggable' };
sub class_title { 'Pluggable' };

for my $plugin (__PACKAGE__->plugins) {
    $plugin->register;
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

    for my $plugin ($self->plugins) {
        for my $hook ($plugin->hooks) {
            my ($type, @parts) = split /\./, $hook->{name};

            if ($type eq 'wafl') {
                $registry->add(
                    'wafl', $parts[0], 'Socialtext::Pluggable::WaflPhraseDiv',
                );
            }
            elsif ($type eq 'action') {
                no strict 'refs';
                my $class = ref $self;
                my $action = $parts[0];
                my $sub = "${class}::$action";

                if (my $old = $hooks{$hook->{name}}) {
                    if ($old->{class} ne $hook->{class}) {
                        die "Can't register $action for $hook->{class}! " .
                            "$old->{class} already registered this action.\n";
                    }
                }
                elsif (UNIVERSAL::can($self, $action)) {
                    die "$class already defines a subroutine named $action that is not an action!";
                }

                *{$sub} = sub { return $_[0]->hook($hook->{name}) };
                $registry->add(action => $action);
            }

            $hooks{$hook->{name}} = $hook;
        }
    }
}

sub register_rest {
    my $self = shift;
    return if $self->{_registered_rest}++;
    for my $plugin ($self->plugins) {
        for my $hook ($plugin->rest_hooks) {
            $hooks{$hook->{name}} = $hook;
        }
    }
}

sub registered {
    my ($self, $name) = @_;
    return exists $hooks{$name};
}

sub hook {
    my ( $self, $name, @args ) = @_;
    if ( my $hook = $hooks{$name} ) {
        my $method = $hook->{method};
        $hook->{obj} ||= $hook->{class}->new();
        $hook->{obj}->hub( $self->hub || $self->{made_hub});
        $hook->{obj}->rest( delete $self->{_rest_handler} );
        return $hook->{obj}->$method(@args);    # do some magic here
    }
}

return 1;
