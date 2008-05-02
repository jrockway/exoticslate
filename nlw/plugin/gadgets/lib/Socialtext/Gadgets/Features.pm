package Socialtext::Gadgets::Features;
use strict;
use warnings;

use Class::Field qw(field);
use XML::LibXML;

my $feature_url = "/nlw/plugin/gadgets/javascript/shindig";

field 'code_base';
field 'feature_dir', -init => '$self->code_base . "/../plugin/gadgets/share/javascript/shindig"';

sub new {
    my ($class,$api,%args) = @_;
    die "type required" unless $args{type};
    my $self = {
        _scripts => [],
        %args,
    };
    bless $self, $class;
    $self->code_base($api->code_base);
    $self->load('core'); # Default requirement
    $self->load('core.io'); # Default requirement
    $self->load('rpc'); # Default requirement
    return $self;
}

# XXX: this sub sucks
sub error {
    my ($self, $error) = @_;
    $self->{_error} = $error;
}

sub load_gadget_features {
    my ($self, $gadget) = @_;
    for my $feature ($gadget->requires) {
        $self->load($feature);
        if ($self->{_error}) {
            # TODO XXX it is fine to have features that you don't support, it's not a
            # fatal error
        }
    }
}

sub load {
    my ($self, $name, $type) = @_;
    $type ||= $self->{type};
    return if $self->{_loaded}{$name};
    $self->{_loaded}{$name} = 1;

    my $xmlfile = $self->feature_dir . "/$name/feature.xml";
    unless (-f $xmlfile) {
        warn "No feature named $name exists\n";
        return;
    }
    
    my $xml;
    eval { $xml = XML::LibXML->new->parse_file($xmlfile) };
    if ($@) {
        warn "Error parsing feature '$name': $@\n";
        return;
    }

    #return $self->error("Error parsing feature: $name") if $@;

    for my $dep ($xml->getElementsByTagName('dependency')) {
        $self->load($dep->textContent);
    }

    # Either get gadget scripts or container scripts
    my ($section) = $xml->getElementsByTagName($type);
    return unless $section;

    for my $s ($section->getElementsByTagName('script')) {
        if (my $src = $s->getAttribute('src')) {
            if ($src =~ /^http/) {
                push @{$self->{_scripts}}, {
                    src => $src,
                };
            }
            else {
                push @{$self->{_scripts}}, {
                    src => "$feature_url/$name/$src",
                };
            }
        }
        else {
            push @{$self->{_scripts}}, {
                content => $s->textContent,
            };
        }
    }
}

sub scripts {
    my $self = shift;
    return $self->{_scripts};
}

1;
