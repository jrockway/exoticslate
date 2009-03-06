# @COPYRIGHT@
package Socialtext::WikiText::Emitter::Messages::Canonical;
use strict;
use warnings;

use base 'WikiText::Receiver';

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
        $output = $ast->{output};
    }
    elsif ($ast->{wafl_type} eq 'link') {
        $output = qq{<a href="/$ast->{workspace_id}/index.cgi?$ast->{page_id}">$ast->{text}</a>};

    }
    elsif ($ast->{wafl_type} eq 'user') {
        $output = $self->user_text( $ast );
    }
    else {
        $output = qq/{$ast->{wafl_type}: not implemented}/;
    }

    $self->{output} .= $output;
}

sub user_text {
    my $self = shift;
    my $ast  = shift;

    my $user_string = $ast->{user_string};
    my $account_id = $self->{callbacks}{account_id};
    my $user = eval{ Socialtext::User->Resolve( $user_string ) };
    if ( $user ) {
        if ($user->primary_account->account_id == $account_id) {
            my $username = $user->username;
            return "{user: $username}";
        }
        else {
            return $user->best_full_name;
        }
    }

    return "{user: $user_string}";
}

sub begin_node {
    my $self = shift;
    my $ast = shift;
    if ($ast->{type} eq 'asis') {
        $self->{output} .= '{{';
    }
}

sub end_node {
    my $self = shift;
    my $ast = shift;
    if ($ast->{type} eq 'asis') {
        $self->{output} .= '}}';
        return;
    }
    $self->{output} .= " ";
}

sub text_node {
    my $self = shift;
    my $text = shift;
    $text =~ s/\n/ /g;
    $self->{output} .= "$text";
}

1;
