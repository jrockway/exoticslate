package Socialtext::User;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::MockBase';
use unmocked 'Socialtext::MultiCursor';

our $WORKSPACES = [ [ 1 ] ];

our %Users;

sub new {
    my $class = shift;
    my $type = shift;
    my $value = shift;
    if (defined $type) {
        if ($type eq 'username' and $value =~ m/^bad/) {
            return undef;
        }
        elsif ($type eq 'user_id') {
            if (exists $Users{$value}) {
                # warn "RETURNING cached user for $value";
                return $Users{$value};
            }
        }
    }
    my $self = { $type ? ($type => $value) : (), @_ };
    bless $self, $class;
    return $self;
}

sub create { 
    my $class = shift;
    my %opts = @_;
    die 'is not a valid email address' unless $opts{email_address} =~ m/@/;
    my $user = Socialtext::MockBase::new($class, %opts);

}

sub confirm_email_address {}

sub confirmation_uri { 'blah/nlw/submit/confirm/foo' }

sub FormattedEmail { 'One Loser <one@foo.bar>' }

sub guess_real_name { 
    my $self = shift;
    return $self->first_name . ' ' . $self->last_name;
}
sub best_full_name { 'Best FullName' }
sub first_name { $_[0]->{first_name} ||= 'Mocked First' }
sub last_name { $_[0]->{last_name} ||= 'Mocked Last' }

sub is_authenticated { ! $_[0]->is_guest() }

sub is_guest { $_[0]->{is_guest} || 0 }

sub user_id { $_[0]->{user_id} || 1 }

sub username { $_[0]->{username} || 'oneusername' }

sub default_role { 
    return Socialtext::Role->AuthenticatedUser();
}

sub email_address { $_[0]->{email_address} ||= 'one@foo.bar' }

sub can_update_store { 1 }
sub update_store {}

sub workspaces {
    return Socialtext::MultiCursor->new(
        iterables => [ $WORKSPACES ],
        apply => sub { 
            my $row = shift;
            return Socialtext::Workspace->new( workspace_id => $row->[0]);
        },
    );
}

sub Resolve {
    my $class = shift;
    my $user_id = shift;
    return Socialtext::User->new(user_id => $user_id);
}

1;
