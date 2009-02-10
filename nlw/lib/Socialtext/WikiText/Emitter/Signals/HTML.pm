package Socialtext::WikiText::Emitter::Signals::HTML;
use strict;
use warnings;

use base 'WikiText::Receiver';

sub content {
    my $self = shift;
    my $content = $self->{output};
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
    $self->{output} .= $ast->{output} || '';
}

sub begin_node {
    my $self = shift;
    my $match = shift;
    return if ($match->{type} eq 'line');
    if ($match->{type} eq 'b') {
        $self->{output} .= "<b>*";
        return;
    };

    $self->{output} .= " ";
}

sub end_node {
    my $self = shift;
    my $match = shift;
    if ($match->{type} eq 'b') {
        $self->{output} .= "*</b>";
        return;
    };

    $self->{output} .= " ";
}

sub text_node {
    my $self = shift;
    my $text = shift;
    $text =~ s/\s+/ /g;
#     $text =~ s/^\s?(.*)s?/$1/g;
#     $text =~ s/\n/ /g;
    $self->{output} .= "$text";
}

1;

