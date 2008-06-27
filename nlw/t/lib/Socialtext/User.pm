package Socialtext::User;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::MockBase';
use unmocked 'Socialtext::MultiCursor';

our $WORKSPACES = [ [ 1 ] ];

sub new {
    my $class = shift;
    my $type = shift;
    my $value = shift;
    if ($type and $type eq 'username' and $value =~ m/^bad/) {
        return undef;
    }
    my $self = { $type ? ($type => $value) : (), @_ };
    bless $self, $class;
    return $self;
}

sub confirm_email_address {}

sub confirmation_uri { 'blah/nlw/submit/confirm/foo' }

sub FormattedEmail { 'One Loser <one@foo.bar>' }

sub guess_real_name { 'One Loser' }
sub best_full_name { 'Best FullName' }

sub is_authenticated { ! $_[0]->is_guest() }

sub is_guest { $_[0]->{is_guest} }

sub user_id { $_[0]->{user_id} || 1 }

sub username { $_[0]->{username} || 'one@foo.bar' }

sub default_role { 
    return Socialtext::Role->AuthenticatedUser();
}

sub email_address { 'one@foo.bar' }

sub workspaces {
    return Socialtext::MultiCursor->new(
        iterables => [ $WORKSPACES ],
        apply => sub { 
            my $row = shift;
            return Socialtext::Workspace->new( workspace_id => $row->[0]);
        },
    );
}

1;
