package Socialtext::st_admin;
# @COPYRIGHT@
use warnings;
use strict;

use Test::More;
use Socialtext::CLI;

use base qw(Exporter);
our @EXPORT = qw(&st_admin);

my $status;
{
    no warnings qw(once redefine);
    *Socialtext::CLI::_exit = sub { $status = shift };
}

# fakes runing st-admin on the command line.
sub st_admin {
    my $args = shift;
    my @args = split(/\s+/,$args);
    open my $fh, '>>t/tmp/cli.log';
    {
        local *STDERR = $fh;
        local *STDOUT = $fh;
        Socialtext::CLI->new(argv => [@args])->run();
    }
    return ok !$status, "st_admin $args";
}

END { unlink 't/tmp/cli.log' }
