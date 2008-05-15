package Socialtext::Gadgets::Features;
# @COPYRIGHT@
use strict;
use warnings;

use JavaScript::Minifier::XS qw(minify);
use Class::Field qw(field);
use XML::LibXML;

field 'feature_dir';

sub new {
    my ($class,$api,%args) = @_;
    die "type required" unless $args{type};
    my $self = {
        _loaded => {},
        _js => '',
        %args,
    };
    bless $self, $class;
    $self->feature_dir(
        $args{feature_dir} || 
            $api->code_base . "/../plugin/gadgets/share/javascript/shindig"
    );
    $self->load('core'); # Default requirement
    $self->load('core.io'); # Default requirement
    $self->load('rpc'); # Default requirement
    return $self;
}

sub load {
    my ($self, $name) = @_;
    return if $self->{_loaded}{$name};
    $self->{_loaded}{$name} = 1;

    my $feature_dir = $self->feature_dir;

    my $xmlfile = "$feature_dir/$name/feature.xml";
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

    for my $dep ($xml->getElementsByTagName('dependency')) {
        $self->load($dep->textContent);
    }

    # Either get gadget scripts or container scripts
    my ($section) = $xml->getElementsByTagName($self->{type});
    return unless $section;

    for my $s ($section->getElementsByTagName('script')) {
        if (my $src = $s->getAttribute('src')) {
            if ($src =~ /^http/) {
                $self->{ua} ||= LWP::UserAgent->new;
                my $res = $self->{ua}->get($src);
                die "Couldn't fetch $src: " . $res->status_line
                    unless $res->is_success;
                $self->_add_js($src, $res->content);
            }
            else {
                my $file = "$feature_dir/$name/$src";
                open my $fh, $file or die "Couldn't open $file: $!";
                my $js = join "", <$fh>;
                $self->_add_js("$name/$src", $js);
            }
        }
        else {
            $self->_add_js("Inline", $s->textContent);
        }
    }
}

sub as_js {
    my $self = shift;
    return $self->{_js};
}

sub as_minified {
    my $self = shift;
    return minify($self->as_js);
}

sub _add_js {
    my ($self, $title, $js) = @_;
    $self->{_js} .= <<EOT;
/* FILE: $title */
$js

EOT
}

sub scripts {
    my $self = shift;
    return $self->{_scripts};
}

1;
