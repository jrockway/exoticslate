package Socialtext::WikiText::Emitter::Messages::Base;
# @COPYRIGHT@
use strict;
use warnings;
use base 'WikiText::Receiver';

sub init {
    my $self = shift;
    $self->{output} = '';
}

sub content {
    my $self = shift;
    my $content = $self->{output};
    $content =~ s/\s\s+/ /g;
    $content =~ s/\s+\z//;
    return $content;
}

sub insert {
    my $self = shift;
    my $ast = shift;

    unless (defined $ast->{wafl_type}) {
        my $output = $ast->{output};
        $output = '' unless defined $output;
        $self->{output} .= $output;
        return;
    }

    if ($self->{callbacks}{noun_link}) {
        if ($ast->{wafl_type} eq 'link' || $ast->{wafl_type} eq 'user') {
            $self->{callbacks}{noun_link}->($ast);
        }
    }

    if ( $ast->{wafl_type} eq 'link' ) {
        $self->{output} .= $self->msg_format_link($ast);
    }
    elsif ( $ast->{wafl_type} eq 'user' ) {
        $self->{output} .= $self->msg_format_user($ast);
    }
    else {
        $self->{output} .= "{$ast->{wafl_type}: $ast->{wafl_string}}";
    }

    return;
}

sub msg_markup_table { die 'subclass must override msg_markup_table' }
sub msg_format_user { die 'subclass must override msg_format_user' }
sub msg_format_link { die 'subclass must override msg_format_link' }

sub begin_node { my $self=shift; $self->_markup_node(0,@_) }
sub end_node   { my $self=shift; $self->_markup_node(1,@_) }

sub _markup_node {
    my $self = shift;
    my $offset = shift;
    my $ast = shift;

    my $markup = $self->msg_markup_table;
    return unless exists $markup->{$ast->{type}};
    my $output = $markup->{$ast->{type}}->[$offset];
    if ($ast->{type} eq 'a') {
        $output =~ s/HREF/$ast->{attributes}{href}/;
    }
    $self->{output} .= $output;
}

sub text_node {
    my $self = shift;
    my $text = shift;
    return unless defined $text;
    $text =~ s/\n/ /g;
    $self->{output} .= $text;
}

1;
