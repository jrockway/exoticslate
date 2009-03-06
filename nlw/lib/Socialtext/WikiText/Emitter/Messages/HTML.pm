package Socialtext::WikiText::Emitter::Messages::HTML;
# @COPYRIGHT@
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
    my $output = '';

    if (not(defined($ast->{wafl_type}))) {
        $output = $ast->{output} || '';
    }
    elsif ( $ast->{wafl_type} eq 'link' ) {
        $output = qq{<a href="/$ast->{workspace_id}/index.cgi?$ast->{page_id}">$ast->{text}</a>};
    }
    elsif ( $ast->{wafl_type} eq 'user' ) {
        $output = $self->user_html($ast);
    }
    else {
        $output = qq{{$ast->{wafl_type}: not supported yet, fool}};
    }

    $self->{output} .= $output;
}

my $markup = {
    'b' => ['<b>', '</b>'],
    'i' => ['<i>', '</i>'],
    'del' => ['<del>', '</del>'],
};

sub user_html {
    my $self = shift;
    my $ast = shift;
    my $userid = $ast->{user_string};
    my $viewer = $self->{callbacks}{viewer};

    my $user = eval { Socialtext::User->Resolve($userid) };
    unless ($user) {
        return "Unknown Person";
    }

    unless ($viewer && $user->profile_is_visible_to($viewer)) {
        return $user->guess_real_name;
    }
    else {
        return '<a href="/?profile=' . $user->user_id 
            . '">' . $user->guess_real_name . '</a>';
    }
}

sub begin_node {
    my $self = shift;
    my $match = shift;

    if ($match->{type} eq 'a') {
        $self->{output} .= qq{<a href="$match->{attributes}{href}">};
    }
    elsif (exists $markup->{$match->{type}}) {
        $self->{output} .= $markup->{$match->{type}}->[0];
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

