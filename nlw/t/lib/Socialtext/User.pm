package Socialtext::User;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::MockBase';
use unmocked 'Socialtext::MultiCursor';
use unmocked 'Socialtext::Exceptions', qw/data_validation_error/;
use unmocked 'Socialtext::Account';

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

    unless ($opts{email_address} =~ m/@/) {
        data_validation_error(
            errors => ["$opts{email_address} is not a valid email address"]);
    }
    if ($opts{email_address} =~ m/^duplicate/) {
        data_validation_error(
            errors => ["The email address you provided ($opts{email_address}) "
                      . "is already in use."],
        );
    }
    if (exists $opts{password} and length($opts{password}) < 6) {
        die "Passwords must be at least 6 characters long.\n";
    }

    return Socialtext::MockBase::new($class, %opts);
}

sub confirm_email_address {}

sub confirmation_uri { 'blah/nlw/submit/confirm/foo' }

sub FormattedEmail { 'One Loser <one@foo.bar>' }

sub guess_real_name { 
    my $self = shift;
    return $self->first_name . ' ' . $self->last_name;
}

sub guess_sortable_name { 
    my $self = shift;
    return $self->last_name . ' ' . $self->first_name;
}

sub best_full_name { 'Best FullName' }
sub first_name { $_[0]->{first_name} ||= 'Mocked First' }
sub last_name { $_[0]->{last_name} ||= 'Mocked Last' }

sub is_authenticated { ! $_[0]->is_guest() }

sub is_guest { $_[0]->{is_guest} || 0 }

sub user_id { $_[0]->{user_id} || 1 }

sub username { $_[0]->{username} || 'oneusername' }
sub password { $_[0]->{password} || 'default-pass' }
sub password_is_correct {
    my $self = shift;
    return ($self->{password} || '') eq shift;
}

sub can_update_store { 1 }
sub update_store {
    my $self = shift;
    my $field = shift;
    my $value = shift;
    $self->{$field} = $value;
}

sub default_role { 
    return Socialtext::Role->AuthenticatedUser();
}

sub email_address { $_[0]->{email_address} ||= 'one@foo.bar' }

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
    my $user = Socialtext::User->new(user_id => $user_id);
    unless ($user) {
        die "Couldn't find user $user_id";
    }
    return $user;
}

our %Confirmation_info;
sub set_confirmation_info {
    my ($self, undef, $pw_change) = @_;
    $Confirmation_info{$self->{username}} = $pw_change;
}

our %Sent_email;
sub send_confirmation_email {
    my $self = shift;
    $Sent_email{$self->{username}} = 1;
}

sub has_valid_password {
    my $self = shift;
    return $self->{password};
}

sub ValidatePassword {
    my ($class, undef, $pass) = @_;
    if ( length($pass) < 6 ) {
        return "Passwords must be at least 6 characters long.";
    }
    return;
}

our $MASK_EMAILS = 0;
sub MaskEmailAddress {
    my ($class, $addr, $ws) = @_;
    $addr =~ s/@.+$/\@masked/ if $MASK_EMAILS;
    return $addr;
}

sub primary_account {
    my $self = shift;
    return $self->{primary_account} || Socialtext::Account->Default;
}

1;
