# @COPYRIGHT@
package Socialtext::WikiText::Emitter::Messages::Canonicalize;
use strict;
use warnings;

use base 'WikiText::Receiver';
use Socialtext::l10n qw/loc/;

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
    elsif ($ast->{wafl_type} eq 'user') {
        $output = $self->user_text( $ast );
    }
    elsif ($ast->{wafl_type} eq 'link') {
        $output = qq/{link $ast->{workspace_id} [$ast->{text}]}/;
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
    my $user = eval{ Socialtext::User->Resolve( $user_string ) };

    if ( $user ) {
        my $user_id = $user->user_id;
        return "{user: $user_id}";
    }

    return loc('Unknown Person');
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
