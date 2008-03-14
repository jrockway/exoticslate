package Socialtext::Pages;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::MockBase';
use unmocked 'Data::Dumper';
use unmocked 'Class::Field', 'field';
use Socialtext::Page;

sub new_from_name {
    my $self = shift;
    my $title = shift;
    return Socialtext::Page->new(title => $title);
}

sub all_ids { }

sub show_mouseover { 1 }

field current => -init => '$self->new_page("welcome")';

sub new_page {
    my $self = shift;
    Socialtext::Page->new(hub => undef, id => shift);
}


1;
