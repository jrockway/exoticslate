package Socialtext::Template::Plugin::decorate;
# @COPYRIGHT@
use strict;
use Template::Plugin::Filter;
use base qw( Template::Plugin::Filter );

sub init {
    my $self = shift;

    $self->{ _DYNAMIC } = 1;

    # first arg can specify filter name
    $self->install_filter('decorate');

    return $self;
}


# As long as we're under the apache request, memoize the decorated results.
# This assumes that repeated calls to [% text | decorate('name') %] will
# yield the same result during one rendering of a template.
my ($ActivePluggable, %DecorateCache);

sub filter {
    my ($self, $text, $args, $config) = @_;

    my $pluggable = $self->{_CONTEXT}->stash->get('pluggable');
    my $name = $args->[0];

    my $cache_key = "$name.$text";
    if ($ActivePluggable == 0+$pluggable) {
        if (exists $DecorateCache{$cache_key}) {
            return $DecorateCache{$cache_key};
        }
    }
    else {
        $ActivePluggable = 0+$pluggable;
        %DecorateCache = ();
    }

    if ($pluggable->registered("template.$name.content")) {
        $text = $pluggable->hook("template.$name.content", $text);
    }
    my $prepend = $pluggable->hook("template.$name.prepend", $text);
    my $append  = $pluggable->hook("template.$name.append", $text);

    my $result = "${prepend}${text}${append}";
    $DecorateCache{$cache_key} = $result;

    return $result;
}

1;
