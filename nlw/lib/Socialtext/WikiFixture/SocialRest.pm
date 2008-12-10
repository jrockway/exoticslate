# @COPYRIGHT@
package Socialtext::WikiFixture::SocialRest;
use strict;
use warnings;
use base 'Socialtext::WikiFixture::SocialBase';
use base 'Socialtext::WikiFixture';
use Test::HTTP;
use Test::More;
use Socialtext::WikiFixture::Socialtext;

=head1 NAME

Socialtext::WikiFixture::SocialRest - Test the REST API without using a browser

=cut

our $VERSION = '0.01';

=head1 DESCRIPTION

This module is a subclass of Socialtext::WikiFixture and includes
extra commands specific for testing the Socialtext REST API.

=head1 FUNCTIONS

=head2 init()

Creates the Test::HTTP object.

=cut

sub init {
    my $self = shift;

    # Set up the Test::HTTP object initially
    Socialtext::WikiFixture::SocialBase::init($self);
    Socialtext::WikiFixture::init($self);
}

=head2 handle_command( @row )

Run the command.  Subclasses can override this.

=cut

sub handle_command {
    my $self = shift;
    my ($command, @opts) = $self->_munge_command_and_opts(@_);

    # Lets (ab)use some existing test methods
    # XXX Should move these to socialbase?
    if ($command eq 'st_admin') {
        return Socialtext::WikiFixture::Socialtext::st_admin($self, @opts);
    }
    elsif ($command eq 'st_config') {
        return Socialtext::WikiFixture::Socialtext::st_config($self, @opts);
    }
    elsif ($command eq 'st_ldap') {
        return Socialtext::WikiFixture::Socialtext::st_ldap($self, @opts);
    }

    eval { $self->SUPER::_handle_command($command, @opts) };
    return unless $@;

    if ($self->can($command)) {
        return $self->$command(@opts);
    }
    die "Unknown command for the fixture: ($command)\n";

}

=head2 comment ( message )

Use the comment as a test comment

=cut

sub comment {
    my $self = shift;
    $self->{http}->name(shift);
}


sub body_unlike {
    my ($self, $expected) = @_;
    my $body = $self->{http}->response->content;
    unlike $body, $self->quote_as_regex($expected), 
        $self->{http}->name() . " checking body-unlike";
}

=head1 AUTHOR

Luke Closs, C<< <luke.closs at socialtext.com> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-socialtext-editpage at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Socialtext-WikiTest>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Socialtext::WikiFixture::SocialRest

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Socialtext-WikiTest>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Socialtext-WikiTest>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Socialtext-WikiTest>

=item * Search CPAN

L<http://search.cpan.org/dist/Socialtext-WikiTest>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2008 Luke Closs, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
