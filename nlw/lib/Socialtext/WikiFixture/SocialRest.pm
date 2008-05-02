# @COPYRIGHT@
package Socialtext::WikiFixture::SocialRest;
use strict;
use warnings;
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

=head2 new( %opts )

Create a new fixture object.  The same options as
Socialtext::WikiFixture are required, as well as:

=over 4

=item server

Mandatory - The server address to test.

=item username

Mandatory - username to login to the wiki with.

=item password

Mandatory - password to login to the wiki with.

=back

=head2 init()

Creates the Test::HTTP object, and logs into the Socialtext
workspace.

=cut

sub init {
    my ($self) = @_;
    for (qw(browser_url username password)) {
        die "$_ is mandatory!" unless $self->{$_};
    }

    $self->SUPER::init;

    $self->{http} = Test::HTTP->new('SocialRest fixture');
    $self->{http}->username($self->{username});
    $self->{http}->password($self->{password});
}

=head2 handle_command( @row )

Run the command.  Subclasses can override this.

=cut

sub handle_command {
    my $self = shift;
    my $command = shift;
    $command =~ s/-/_/g;
    my @opts = $self->_munge_options(@_);

    if ($command eq 'body_like') {
        $opts[0] = $self->quote_as_regex($opts[0]);
    }
    elsif ($command =~ m/_like$/) {
        $opts[1] = $self->quote_as_regex($opts[1]);
    }

    if ($self->can($command)) {
        return $self->$command(@opts);
    }
    if ($self->{http}->can($command)) {
        return $self->{http}->$command(@opts);
    }

    # Lets (ab)use some existing test methods
    if ($command eq 'st_admin') {
        return Socialtext::WikiFixture::Socialtext::st_admin($self, @opts);
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

=head2 get ( uri, accept )

GET a URI, with the specified accept type.  

accept defaults to 'text/html'.

=cut

sub get {
    my ($self, $uri, $accept) = @_;
    $accept ||= 'text/html';

    $self->_get($uri, [Accept => $accept]);
}

=head2 code_is( code [, expected_message])

Check that the return code is correct.

=cut

sub code_is {
    my ($self, $code, $msg) = @_;
    $self->{http}->status_code_is($code);
    if ($msg) {
        like $self->{http}->response->content(), $self->quote_as_regex($msg),
             "Status content matches";
    }
}

=head2 post( uri, headers, body )

Post to the specified URI

=cut

sub post { shift->_call_method('post', @_) }

=head2 put( uri, headers, body )

Put to the specified URI

=cut

sub put { shift->_call_method('put', @_) }

sub body_unlike {
    my ($self, $expected) = @_;
    my $body = $self->{http}->response->content;
    unlike $body, $self->quote_as_regex($expected), 
        $self->{http}->name() . " checking body-unlike";
}

sub _call_method {
    my ($self, $method, $uri, $headers, $body) = @_;
    if ($headers) {
        $headers = [
            map {
                s/-/_/g;
                split m/\s*=\s*/, $_
            } split m/\s*,\s*/, $headers
        ];
    }
    $self->{http}->$method($self->{browser_url} . $uri, $headers, $body);
}

sub _get {
    my ($self, $uri, $opts) = @_;
    $self->{http}->get( $self->{browser_url} . $uri, $opts );
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
