# @COPYRIGHT@
package Socialtext::WikiText::Emitter::SearchSnippets;
use strict;
use warnings;

use base 'WikiText::Receiver';

sub content {
    my $self = shift;
    my $content = $self->{output};
    $content =~ s/\s\s+/ /g;
    $content =~ s/\s*\z//;
    return $content . "\n";
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
}

sub end_node {
    my $self = shift;
    $self->{output} .= " ";
}

sub text_node {
    my $self = shift;
    my $text = shift;
    $text =~ s/\n/ /g;
    $self->{output} .= "$text";
}

1;
