package Socialtext::WikiText::Emitter::Messages::Canonicalize;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::WikiText::Emitter::Messages::Base';
use Socialtext::l10n qw/loc/;
use Readonly;

Readonly my %markup => (
    asis => [ '{{', '}}' ],
    b    => [ '*',  '*' ],
    i    => [ '_',  '_' ],
    del  => [ '-',  '-' ],
    a    => [ '"',  '"<HREF>' ],
);

sub msg_markup_table { return \%markup }

sub msg_format_link {
    my $self = shift;
    my $ast = shift;
    return "{$ast->{wafl_type}: $ast->{wafl_string}}"
}

sub msg_format_user {
    my $self = shift;
    my $ast = shift;
    if ($self->{callbacks}{decanonicalize}) {
        return $self->user_as_username( $ast );
    }
    else {
        return $self->user_as_id( $ast );
    }
}

sub user_as_id {
    my $self = shift;
    my $ast  = shift;

    my $user = eval{ Socialtext::User->Resolve( $ast->{user_string} ) };
    return loc('Unknown Person') unless $user;

    my $user_id = $user->user_id;
    return "{user: $user_id}";
}

sub user_as_username {
    my $self = shift;
    my $ast  = shift;

    my $user_string = $ast->{user_string};
    my $account_id = $self->{callbacks}{account_id};
    my $user = eval{ Socialtext::User->Resolve( $user_string ) };

    return "{user: $user_string}" unless $user;

    if ($user->primary_account_id == $account_id) {
        my $username = $user->username;
        return "{user: $username}";
    }
    else {
        return $user->best_full_name;
    }
}

1;
