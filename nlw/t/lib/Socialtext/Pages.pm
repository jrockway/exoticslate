package Socialtext::Pages;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::MockBase';
use mocked 'Socialtext::Page';

sub new_from_name {
    my $self = shift;
    my $title = shift;
    return Socialtext::Page->new(title => $title);
}

sub all_ids { }

sub show_mouseover { 1 }


1;
