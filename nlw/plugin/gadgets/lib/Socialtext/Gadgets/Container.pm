package Socialtext::Gadgets::Container;
# @COPYRIGHT@
use strict;
use warnings;

use Socialtext::Gadgets::Gadget;
use Carp qw(croak);
use Class::Field 'field';

field 'id';
#field 'gadgets', -init => '$self->get_gadgets';
field 'features', -init => 'Socialtext::Gadgets::Features->new($self->api,type=>"container")';
field 'api';

# $api is a reference to the Pluggable::Plugin obj that should be used to
# access all the socialtext specific settings etc.  All directories, storage
# objects etc.

sub new {
    my ($class, $api, $id) = @_;
    croak "id required" unless $id;
    my $self = {
        _gadgets => {},
    };
    bless $self, $class;
    $self->id($id);
    $self->api($api);
    return $self;
}

sub storage {
    my $self = shift;
    die "no id" unless defined $self->id;
    return $self->{_storage} if $self->{_storage};
    $self->{_storage} = $self->api->storage($self->id);
    return $self->{_storage};
}

sub install_gadget {
    my ($self, $url, $col, $gadget_id) = @_;
    my $gadgets = $self->storage->get('gadgets') || {};

    $col = 2 unless defined $col;

    # Push the others down
    for my $gadget (values %$gadgets) {
        $gadget->{pos}[1]++ if $gadget->{pos}[0] == $col;
    }

    my $gadget;
    if ($gadget_id) {
        $gadget = Socialtext::Gadgets::Gadget->install($self->api,$url,$gadget_id);
    } else {
        $gadget = Socialtext::Gadgets::Gadget->install($self->api,$url);
        $gadget_id = $gadget->id;
    }

    $self->{_gadgets}{$gadget_id} = $gadget;

    $gadgets->{$gadget_id} = {
        pos => [$col, 0],
        id => $gadget_id,
    };

    $self->storage->set('gadgets', $gadgets);
}

sub get_test_gadgets {
    my $self = shift;

    my $plugin_dir = Socialtext::Pluggable::Plugin::Gadgets->plugin_dir;
    
    # get all the test gadgets and install them
    my $gpath = "$plugin_dir/share/gadgets/t";
    my $ginstallpath = "file://$gpath";
    my @test_gadgets = sort glob ("$gpath/*.xml");
   
    my $ix = 1;
    foreach my $test_gadget (@test_gadgets) {
        my $col = ($ix % 3);
        $self->install_gadget("file://$test_gadget",  $col, $ix);
        $ix++;
    }
    # don't care about return val
}

sub delete_gadget {
    my ($self,$id) = @_;
    $self->api->storage($id)->remove;
}

sub get_gadgets {
    my $self = shift;

    my $plugin_dir = Socialtext::Pluggable::Plugin::Gadgets->plugin_dir;

    my $gadgets = $self->storage->get('gadgets');

    foreach my $id (keys %$gadgets) { 
        # XXX DPL too clever to actually work: while (my ($id, $ginfo) = each %$gadgets) {
        my $ginfo = $gadgets->{$id};
        $ginfo->{obj} = $self->{_gadgets}{$id} ||
                         Socialtext::Gadgets::Gadget->restore($self->api,$id);
    }
    return $gadgets;
}


sub test {
    my ($class,$api) = @_;
    my $self = {
        _gadgets => {},
    };
    bless $self, $class;
    $self->id('test');
    $self->api($api);
    $self->storage->set('gadgets', {});
    $self->get_test_gadgets();
    return $self;
}


sub template_vars {
    my $self = shift;
    my $gadgets = $self->get_gadgets;

    my @columns;
    for my $col ( 0 .. 3 ) {
        push @columns, [
            map { $_->{obj}->template_hash }
            sort { $a->{pos}[1] <=> $b->{pos}[1] }
            grep { $_->{pos}[0] == $col }
            values %$gadgets
        ];
    }
    return \@columns;
}

return 1;
