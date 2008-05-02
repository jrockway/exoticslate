package Socialtext::Template::Plugin::decorate;
# @COPYRIGHT@
use Template::Plugin::Filter;
use base qw( Template::Plugin::Filter );

sub init {
    my $self = shift;

    $self->{ _DYNAMIC } = 1;

    # first arg can specify filter name
    $self->install_filter('decorate');

    return $self;
}


sub filter {
    my ($self, $text, $args, $config) = @_;

    my $pluggable = $self->{_CONTEXT}->stash->get('pluggable');
    my $name = $args->[0];

    if ($pluggable->registered("template.$name.content")) {
        $text = $pluggable->hook("template.$name.content", $text);
    }
    my $prepend = $pluggable->hook("template.$name.prepend", $text);
    my $append  = $pluggable->hook("template.$name.append", $text);
    return "${prepend}${text}${append}";
}

1;
