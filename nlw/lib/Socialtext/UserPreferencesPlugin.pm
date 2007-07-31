# @COPYRIGHT@
package Socialtext::UserPreferencesPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';
use Socialtext::l10n qw( loc loc_lang valid_code );

use Class::Field qw( const field );
use Socialtext::Exceptions qw( data_validation_error );

sub class_id { 'user_preferences' }
const class_title => 'User Preferences';
const cgi_class => 'Socialtext::UserPreferences::CGI';
field 'user_id';
field preference_list => [];

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add( action => 'preferences_settings' );
}

sub preferences_settings {
    my $self = shift;
    if ( $self->hub()->current_user()->is_guest() ) {
        Socialtext::Challenger->Challenge(
            type => 'settings_requires_account' );

    }

    my $class_id = $self->cgi->preferences_class_id;
    if ( $class_id eq '' ) {
        my $message = loc("Preferences Class ID is missing");
        data_validation_error errors => [$message];
    }

    my $list
        = $self->hub->registry->lookup->add_order->{$class_id}{preference}
        or die "No preference key for $class_id in add_order";

    my $object = $self->hub->$class_id;

    if ( $self->cgi->Button ) {
        $self->save($object);
        $self->message(loc('Preferences saved'));
    }

    my $prefs = $self->preferences->new_for_user(
        $self->hub->current_user->email_address );

    my @pref_list = map { $prefs->$_ } @$list;
    my $settings_section = $self->template_process(
        'element/settings/preferences_settings_section',
        preference_list => \@pref_list,
        $self->status_messages_for_template,
    );

    $self->screen_template('view/settings');
    return $self->render_screen(
        settings_table_id => 'settings-table',
        settings_section  => $settings_section,
        hub               => $self->hub,
        display_title     => loc('Preferences: [_1]',loc($object->class_title)),
        pref_list         => $self->_get_pref_list,
    );
}

# XXX this method may not have test coverage
sub save {
    my $self = shift;
    my $object = shift;

    my %cgi = $self->cgi->vars;

    my $settings = {};
    my $class_id = $object->class_id;
    for (sort keys %cgi) {
        if (/^${class_id}__(.*)/) {
            my $pref = $1;
            $pref =~ s/-boolean$//;

            # immediately show the new locale if it is changed
            if ($pref eq 'locale') {
                if (valid_code($cgi{$_})) {
                    loc_lang($cgi{$_});
                }
                else {
                    # Find the old locale to re-save from pkg name
                    ($cgi{$_} = ref(loc_lang)) =~ s/.+:://;
                }
            }

            $settings->{$pref} = $cgi{$_}
              unless exists $settings->{$pref};
        }
    }
    if (keys %$settings) {
        $self->preferences->store( $self->hub->current_user->email_address, $class_id, $settings );
    }
}

package Socialtext::UserPreferences::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'Button';
cgi 'preferences_class_id';

1;

