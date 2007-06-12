# @COPYRIGHT@
package Socialtext::Authen;
use strict;
use warnings;

our $VERSION = 0.01;

use Socialtext::User;

use Socialtext::Validate qw( validate SCALAR_TYPE );

sub new {
    my $class = shift;
    return bless {}, $class;
}

# REVIEW: Now that the actual authen generalization is done in
# ST::User, this might need to go away entirely.
sub check_password {
    my $self = shift;
    my %p = validate @_,{ username => SCALAR_TYPE,
                          password => SCALAR_TYPE,
                        };

    my $user = Socialtext::User->new( username => $p{username} );

    return unless $user;

    return $user->password_is_correct( $p{password} );
}

1;

__END__

=head1 NAME

Socialtext::Authen - User authentication factory

=head1 SYNOPSIS

    use Socialtext::Authen;

    my $authen = Socialtext::Authen->new();
    if ( $authen->check_password( username => $u, password => $p ) ) { ... }

=head1 DESCRIPTION

This module is a factory class that returns an appropriate user

=head1 METHODS

This class has the following methods:

=head2 $authen->check_password( username => $u, password => $p );

Instantiate the user identified by username $u, and check the user's
password against supplied password $p.

=head1 AUTHOR

Socialtext, C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2006 Socialtext, Inc. All Rights Reserved.

=cut
