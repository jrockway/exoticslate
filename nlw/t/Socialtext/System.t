#!perl
# @COPYRIGHT@

use warnings;
use strict;

use Test::Socialtext tests => 12;
use Socialtext::System;
use Socialtext::File qw/set_contents/;

my $in = "obase=16\n912559\n65261\n";
my $expected = "DECAF\nFEED\n";

Ipc_run: {
    my $out;
    ipc_run([qw(bc)], \$in, \$out, \$out);
    is($out, $expected, 'ipc_run');
}

Backtick: {
    backtick("uggle");
    like($@, qr{uggle.*not found}, 'backtick admits when the command isn\'t found');

    backtick(qw(cat /asdf/asdf/asd/f/asdf/));
    like($@, qr{asdf/: No such file}, 'backtick should die on command failures');

    my $temp = "t/run.t-$$";
    set_contents($temp, $in);
    my $output = backtick('bc', $temp);
    unlink $temp or die "Can't unlink $temp: $!";

    is($@, '', 'backtick should not emit errors if nothing went wrong');
    is($output, $expected, 'backtick output correct');
}

Quote_args: {
    my @tests = (
        [[ 'foo' ]              => q{foo} ],
        [[ 'foo bar' ]          => q{"foo bar"} ],
        [[ 'foo bar', 'baz' ]   => q{"foo bar" baz} ],
        [[ 'a', '', 'c' ]       => q{a "" c} ],
        [[ q{ab'cd"df$gh\\} ]    => q{ab\\'cd\\"df\\$gh\\\\} ],
    );
    for (@tests) {
        is quote_args(@{$_->[0]}), $_->[1], $_->[1];
    }
}

Run: {
    eval { shell_run('/bin/date > /dev/null') };
    is $@, '', 'single arg';

    eval { shell_run('-/bin/false') };
    is $@, '', 'prevented die';
}
