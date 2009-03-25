package Socialtext::WikiText::Emitter::Messages::HTML;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::WikiText::Emitter::Messages::Base';
use Socialtext::l10n qw/loc/;
use Readonly;

Readonly my %markup => (
    asis => [ '',                '' ],
    b    => [ '<b>',             '</b>' ],
    i    => [ '<i>',             '</i>' ],
    del  => [ '<del>',           '</del>' ],
    a    => [ '<a href="HREF">', '</a>' ],
);

sub msg_markup_table { return \%markup }

sub msg_format_link {
    my $self = shift;
    my $ast = shift;
    return qq{<a href="/$ast->{workspace_id}/index.cgi?$ast->{page_id}">$ast->{text}</a>};
}

sub msg_format_user {
    my $self = shift;
    my $ast = shift;
    my $userid = $ast->{user_string};
    my $viewer = $self->{callbacks}{viewer};

    my $user = eval { Socialtext::User->Resolve($userid) };
    unless ($user) {
        return loc("Unknown Person");
    }

    unless ($viewer && $user->profile_is_visible_to($viewer)) {
        return $user->guess_real_name;
    }
    else {
        return '<a href="/?profile/' . $user->user_id 
            . '">' . $user->guess_real_name . '</a>';
    }
}

sub text_node {
    my $self = shift;
    my $text = shift;
    return unless defined $text;
    $text =~ s/\s{2,}/ /g;
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $self->{output} .= $text;
}

1;

