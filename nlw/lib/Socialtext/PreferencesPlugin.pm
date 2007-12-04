# @COPYRIGHT@
package Socialtext::PreferencesPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use Class::Field qw( field );
use Socialtext::File;

sub class_id { 'preferences' }
field objects_by_class => {};

sub load {
    my $self = shift;
    my $values = shift;
    my $prefs = $self->hub->registry->lookup->preference;
    for (sort keys %$prefs) {
        my $array = $prefs->{$_};
        my $class_id = $array->[0];
        my $hash = {@{$array}[1..$#{$array}]}
          or next;
        next unless $hash->{object};
        my $object = $hash->{object}->clone;
        $object->value($values->{$_});
        $object->hub($self->hub);
        push @{$self->objects_by_class->{$class_id}}, $object;
        field($_);
        $self->$_($object);
    }
    return $self;
}

sub new_for_user {
    my $self = shift;
    my $email = shift;

    return $self->{per_user_cache}{$email} if $self->{per_user_cache}{$email};

    my $values = $self->_values_for_email($email);

    return $self->{per_user_cache}{$email} = $self->new_preferences($values);
}

sub _values_for_email {
    my $self = shift;
    my $email = shift;
    my $file = $self->_file_for_email($email);

    return {} unless -f $file and -r _;

    my $dump = Socialtext::File::get_contents($file);
    return {} unless defined $dump and length $dump;

    my $prefs = eval $dump;
    die $@ if $@;

    return +{ map %$_, values %$prefs };
}

sub _file_for_email {
    my $self = shift;
    my $email = shift;

    return Socialtext::File::catfile(
       $self->user_plugin_directory($email),
       'preferences.dd'
    );
}

sub new_preferences {
    my $self = shift;
    my $values = shift;
    my $new = bless {}, ref $self;
    $new->hub($self->hub);
    $new->load($values);
    return $new;
}

sub new_preference {
    my $self = shift;
    Socialtext::Preference->new(@_);
}

sub new_dynamic_preference {
    my $self = shift;
    Socialtext::Preference::Dynamic->new(@_);
}

sub _prefs_file_for_email {
    my $self = shift;
    Socialtext::File::catfile( $self->user_plugin_directory(@_), 'preferences.dd' );
}

sub store {
    my $self = shift;
    my ($email, $class_id, $new_prefs, $user_id) = @_;
    my $prefs = $self->_load_all($email);
    $prefs->{$class_id} = $new_prefs;
    $self->dumper_to_file($self->_prefs_file_for_email($email), $prefs);
}

sub _load_all {
    my $self = shift;
    my $prefs_file = $self->_prefs_file_for_email(@_);
    return {} unless -e $prefs_file;
    my $data = eval Socialtext::File::get_contents($prefs_file);
    die $@ if $@;

    return $data;
}

package Socialtext::Preference;

use base 'Socialtext::Base';

use Class::Field qw( field );
use Socialtext::l10n qw/loc/;

field 'id';
field 'name';
field 'description';
field 'query';
field 'type';
field 'choices';
field 'default';
field 'default_for_input';
field 'handler';
field 'owner_id';
field 'size' => 20;
field 'edit';
field 'new_value';
field 'error';
field layout_over_under => 0;

sub new {
    my $class = shift;
    my $owner = shift;
    my $self = bless {}, $class;
    my $id = shift || '';
    $self->id($id);
    my $name = $id;
    $name =~ s/_/ /g;
    $name =~ s/\b(.)/\u$1/g;
    $self->name($name);
    $self->query("$name?");
    $self->type('boolean');
    $self->default(0);
    $self->handler("${id}_handler");
    $self->owner_id($owner->class_id);
    return $self;
}

sub value {
    my $self = shift;
    return $self->{value} = shift
      if @_;
    return defined $self->{value} 
      ? $self->{value}
      : $self->default;
}

sub value_label {
    my $self = shift;
    my $choices = $self->choices
      or return '';
    return ${ {@$choices} }{$self->value} || '';
}
    
sub form_element {
    my $self = shift;
    my $type = $self->type;
    return $self->$type;
}

sub input {
    my $self = shift;
    my $name = $self->owner_id . '__' . $self->id;
    my $value = $self->value ||
      # support lazy eval...
      ( ref($self->default_for_input) eq 'CODE' ? $self->default_for_input->($self) : $self->default_for_input ) ||
      $self->value;
    my $size = $self->size;
    return <<END
<input type="text" name="$name" value="$value" size="$size" />
END
}

sub boolean {
    my $self = shift;
    my $name = $self->owner_id . '__' . $self->id;
    my $value = $self->value;
    my $checked = $value ? 'checked="checked"' : '';
    return <<END
<input type="checkbox" name="$name" value="1" $checked />
<input type="hidden" name="$name-boolean" value="0" $checked />
END
}

sub radio {
    my $self = shift;
    my $i = 1;
    my @choices = map { loc($_) } @{$self->choices};
    my @values = grep {$i++ % 2} @choices;
    my $value = $self->value;

    $self->hub->template->process('preferences_radio.html',
        name => $self->owner_id . '__' . $self->id,
        values => \@values,
        default => $value,
        labels => { @choices },
    );
}

sub pulldown {
    my $self = shift;
    my $i = 1;
    my @choices = map { loc($_) } @{$self->choices};
    my @values = grep {$i++ % 2} @choices;
    my $value = $self->value;
    $self->hub->template->process('preferences_pulldown.html',
        name => $self->owner_id . '__' . $self->id,
        values => \@values,
        default => $value,
        labels => { @choices },
    );
}

sub hidden {
    my $self = shift;
    my $name = $self->owner_id . '__' . $self->id;
    my $value = $self->value;
    return <<END
<input type="hidden" name="$name" value="$value" />
END
}

package Socialtext::Preference::Dynamic;
use base 'Socialtext::Preference';

use Class::Field qw( field );
use Socialtext::l10n qw/loc/;

field 'choices_callback';

sub choices { shift->_generic_callback("choices", @_) }

sub _generic_callback {
    my ($self, $name, @args) = @_;
    my $method = "${name}_callback";
    if ($self->$method) {
        return $self->$method->($self, @args);
    } else {
        $method = "SUPER::${name}";
        return $self->$method(@args);
    }
}

1;
