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

my $markup = {
    'b' => ['<b>*', '*</b>'],
    'i' => ['<i>_', '_</i>'],
    'del' => ['<del>-', '-</del>'],
};
sub begin_node {
    my $self = shift;
    my $match = shift;
    return if ($match->{type} eq 'line');
    if ($match->{type} eq 'a') {
        $self->{output} .= qq{<a href="$match->{attributes}{href}">};
    }
    elsif (exists $markup->{$match->{type}}) {
        $self->{output} .= $markup->{$match->{type}}->[0];
    }
    else {
        $self->{output} .= " ";
    }
}

sub end_node {
    my $self = shift;
    my $match = shift;
    if ($match->{type} eq 'a') {
        $self->{output} .= "</a>";
    }
    elsif (exists $markup->{$match->{type}}) {
        $self->{output} .= $markup->{$match->{type}}->[1];
    }
    else {
        $self->{output} .= " ";
    }
}

sub text_node {
    my $self = shift;
    my $text = shift;
    $text =~ s/\s+/ /g;
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
#     $text =~ s/^\s?(.*)s?/$1/g;
#     $text =~ s/\n/ /g;
    $self->{output} .= "$text";
}

1;

