package Apache;
# @COPYRIGHT@
use strict;
use warnings;

use lib 't/lib';
use Apache::Request;

sub new {
    my ($class, %opts) = @_;
    my $self = { %opts };
    bless $self, $class;
}

sub request {
    my $class = shift;
    return Apache::Request->new(@_);
}


1;
