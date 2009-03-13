# @COPYRIGHT@
package Socialtext::WikiText::Emitter::Messages::Canonicalize;
use strict;
use warnings;

use base 'WikiText::Receiver';
use Socialtext::l10n qw/loc/;

my $markup = {
    asis => [ '{{', '}}' ],
    b    => [ '*',  '*'  ],
    i    => [ '_',  '_'  ],
    del  => [ '-',  '-'  ],
    a    => [ '',   ''   ], # Handled as a special case below
};

sub content {
    my $self = shift;
    my $content = $self->{output};
    $content =~ s/\s\s+/ /g;
    $content =~ s/\s*\z//;
    return $content;
}

sub init {
    my $self = shift;
    $self->{output} = '';
}

sub insert {
    my $self = shift;
    my $ast = shift;
    my $output = '';

    if (not(defined($ast->{wafl_type}))) {
        $output = $ast->{output} || '';
    }
    elsif ($ast->{wafl_type} eq 'user') {
        if ($self->{callbacks}{decanonicalize}) {
            $output = $self->user_as_username( $ast );
        }
        else {
            $output = $self->user_as_id( $ast );
        }
    }
    else {
        $output = "{$ast->{wafl_type}: $ast->{wafl_string}}";
    }

    $self->{output} .= $output;
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

sub begin_node {
    my $self = shift;
    my $ast = shift;

    if ($ast->{type} eq 'a') {
        $self->{output} .= '"';
    }
    elsif (exists $markup->{$ast->{type}}) {
        $self->{output} .= $markup->{$ast->{type}}->[0];
    }
}

sub end_node {
    my $self = shift;
    my $ast = shift;
    if ($ast->{type} eq 'a') {
        $self->{output} .= '"<' . $ast->{attributes}{href}. '>';
    }
    elsif (exists $markup->{$ast->{type}}) {
        $self->{output} .= $markup->{$ast->{type}}->[1];
    }
}

sub text_node {
    my $self = shift;
    my $text = shift;
    $text =~ s/\n/ /g;
    $self->{output} .= "$text";
}

1;
