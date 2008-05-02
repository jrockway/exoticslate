package Socialtext::Pluggable::Adapter;
# @COPYRIGHT@
use strict;
use warnings;

use base 'Socialtext::Plugin';

our @libs;
BEGIN {
    our $code_base = Socialtext::AppConfig->code_base;
    @libs = glob("$code_base/../plugin/*/lib");
    push @INC, @libs;
}

use Module::Pluggable search_path => ['Socialtext::Pluggable::Plugin'],
                      search_dirs => \@libs, require => 1;
use Socialtext::Pluggable::WaflPhraseDiv;

sub class_id { 'pluggable' };
sub class_title { 'Pluggable' };

for my $plugin (__PACKAGE__->plugins) {
    $plugin->register;
}

my %hooks;

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
                if (UNIVERSAL::can($self, $parts[0])) {
                    die "An action or sub named $parts[0] already exists";
                }
                my $sub = "${class}::$parts[0]";
                *{$sub} = sub {
                    return $_[0]->hook($hook->{name});
                };
                $registry->add( 'action' => $parts[0] );
            }

            $hooks{$hook->{name}} = $hook;
        }
    }
}

sub registered {
    my ($self, $name) = @_;
    return exists $hooks{$name};
}

sub hook {
   my ($self,$name,@args) = @_;
   if (my $hook = $hooks{$name}) {
       my $method = $hook->{method};
       $hook->{obj} ||= $hook->{class}->new();
       $hook->{obj}->hub($self->hub);
       return $hook->{obj}->$method(@args)
   }
   return ""
}

return 1;
