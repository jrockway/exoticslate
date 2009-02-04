package Socialtext::WikiText::Parser::Signals;
use strict;
use warnings;

use base 'WikiText::Socialtext::Parser';

sub create_grammar {
    my $self = shift;
    my $grammar = $self->SUPER::create_grammar();
    my $blocks = $grammar->{_all_blocks};
    @$blocks = ('line');
    my $phrases = $grammar->{_all_phrases};
    @$phrases = ('waflphrase');
    $grammar->{line} = {
        match => qr/^(.*)$/s,
        phrases => $phrases,
        filter => sub {
            chomp;
            die "Signal text cannot contain newline:\n>$_<"
              if /\n/;
        },
    };
    return $grammar;
}

# 1: ~
# 2: link
# 3: 'admin [Foo]'
# begin: 10
# end: 29
# text: ~
# type: waflphrase

sub handle_waflphrase {
    my $self = shift;
    my $match = shift; 
    return unless $match->{type} eq 'waflphrase';
    if ($match->{2} eq 'link') {
        my $options = $match->{3};
        if ($options =~ /^\s*([\w\-]+)\s*\[(.*)\]\s*$/) {
            my ($workspace_id, $page_id) = ($1, $2);
            my $text = $match->{text} || $page_id;
            $page_id = $self->name_to_id($page_id);
            $self->{receiver}->insert({
                output =>
                    qq{<a href="/$workspace_id/index.cgi?$page_id">$text</a>}
            });
            return;
        }
    }
    return $self->unknown_wafl($match);
}

sub name_to_id {
    my $self = shift;
    my $text = shift;
    $text = lc($text);
    return $text;
}


1;
