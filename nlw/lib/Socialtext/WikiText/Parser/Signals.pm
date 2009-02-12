package Socialtext::WikiText::Parser::Signals;
use strict;
use warnings;

use base 'WikiText::Socialtext::Parser';

use Socialtext::Page;

sub create_grammar {
    my $self = shift;
    my $grammar = $self->SUPER::create_grammar();
    my $blocks = $grammar->{_all_blocks};
    @$blocks = ('line');
    my $phrases = $grammar->{_all_phrases};

    @$phrases = ('waflphrase', 'a', 'b', 'i', 'del');
    $grammar->{line} = {
        match => qr/^(.*)$/s,
        phrases => $phrases,
        filter => sub {
            chomp;
            die "Signal text cannot contain newline:\n>$_<"
              if /\n/;
        }
    };
#     $grammar->{b} = {
#         match => re_huggy(q{\*}),
#         phrases => $phrases,
#     };
    return $grammar;
}

sub re_huggy {
    my $brace1 = shift;
    my $brace2 = shift || $brace1;
    my $ALPHANUM = '\p{Letter}\p{Number}\pM';

    qr/
        (?:^|(?<=[^{$ALPHANUM}$brace1]))($brace1(?=\S)(?!$brace2)
        .*?
        $brace2)(?=[^{$ALPHANUM}$brace2]|\z)
    /x;
}

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
    $self->unknown_wafl($match);
}

sub name_to_id {
    my $self = shift;
    my $text = shift;
    return Socialtext::Page->name_to_id($text);
}

sub unknown_wafl {
    my $self = shift;
    my $match = shift; 
    my $func = $match->{2};
    my $args = $match->{3};
    my $output = "{$func";
    $output .= ": $args" if $args;
    $output .= '}';
    $self->{receiver}->insert({output => $output});
}

1;
