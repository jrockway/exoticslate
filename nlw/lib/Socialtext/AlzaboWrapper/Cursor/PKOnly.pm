# @COPYRIGHT@
package Socialtext::AlzaboWrapper::Cursor::PKOnly;

use strict;
use warnings;

use base qw(Class::AlzaboWrapper::Cursor);


sub new {
    my $class = shift;
    my %p = @_;

    my $self = $class->SUPER::new(%p);

    $self->{tables} = $p{tables};

    return $self;
}

sub next {
    my $self = shift;

    my @vals = $self->{cursor}->next;

    return unless @vals;

    my @objects;
    for my $table ( @{ $self->{tables} } ) {
        my %p;
        for my $pk ( map { $_->name } $table->primary_key() ) {
            $p{$pk} = shift @vals;
        }

        my $class = Class::AlzaboWrapper->TableToClass($table);
        push @objects, $class->new(%p);
    }

    return wantarray ? @objects : $objects[0];
}


1;
