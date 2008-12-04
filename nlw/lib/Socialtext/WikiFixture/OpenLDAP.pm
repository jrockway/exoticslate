package Socialtext::WikiFixture::OpenLDAP;
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Socialtext::AppConfig;
use Socialtext::LDAP::Config;
use Test::More;
use base qw(Socialtext::WikiFixture::Socialtext);

sub init {
    my $self = shift;

    # bootstrap an OpenLDAP instance
    $self->{ldap} = Test::Socialtext::Bootstrap::OpenLDAP->new();
    my $ldap_cfg = $self->{ldap}->ldap_config();

    # save LDAP config
    Socialtext::LDAP::Config->save($ldap_cfg);

    # hold onto the current user_factories (we'll reset when we're done)
    my $appconfig = Socialtext::AppConfig->new();
    $self->{user_factories} = $appconfig->user_factories();

    # update the user_factories to include the LDAP directory
    $appconfig->set( 'user_factories', "LDAP:" . $ldap_cfg->id() . ";Default" );
    $appconfig->write();

    # init our base class
    $self->SUPER::init(@_);
}

sub end_hook {
    my $self = shift;

    # reset user_factories to their original state
    if ($self->{user_factories}) {
        my $appconfig = Socialtext::AppConfig->new();
        $appconfig->set( 'user_factories', $self->{user_factories} );
        $appconfig->write();
    }

    # tear down our base class
    $self->SUPER::end_hook(@_);
}

sub add_ldif_data {
    my $self = shift;
    my $ldif = shift;
    diag "add ldif data: $ldif";
    $self->{ldap}->add_ldif($ldif);
}

sub remove_ldif_data {
    my $self = shift;
    my $ldif = shift;
    diag "remove ldif data: $ldif";
    $self->{ldap}->remove_ldif($ldif);
}

1;

=head1 NAME

Socialtext::WikiFixture::OpenLDAP - OpenLDAP extensions to the WikiFixture test framework

=head1 DESCRIPTION

This module extends C<Socialtext::WikiFixture::Socialtext> and includes some
extra commands relevant for testing against an LDAP directory (in this case, OpenLDAP).

On initialization, this module automatically bootstraps an OpenLDAP server,
saves out the F<ldap.yaml> LDAP configuration file, and updates the "user
factories" configuration in the Socialtext application config so that the LDAP
directory is the B<first> known user factory.  On cleanup, the user factories
are reset back to their initial state.

=head1 METHODS

=over

=item B<init()>

Over-ridden initialization routine, which bootstraps an OpenLDAP instance,
saves out the LDAP configuration, and adds the LDAP directory as the primary
user factory.

=item B<end_hook()>

Over-ridden cleanup routine, which sets the user factories back to their
initial state.

=item B<add_ldif_data($ldif)>

Adds data in the given C<$ldif> file to the LDAP directory.

=item B<remove_ldif_data($ldif)>

Removes data in the given C<$ldif> file from the LDAP directory.

=back

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
