#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 9;
fixtures( 'admin_no_pages' );

use Socialtext::File;
use Test::Socialtext::Search;

my $hub = Test::Socialtext::Search::hub();

# send a dirt simple mail
{
    my $in = get_email('simple');
    my ($out, $err);
    my @command = ('bin/st-admin', 'deliver-email', '--workspace', 'admin');

    IPC::Run::run \@command, \$in, \$out, \$err;
    my $return = $? >> 8;

    is($return, 0, 'command returns proper exit code with simple message');
    is($err, '', 'no stderr output with simple message');
    is($out, '', 'no stdout output with simple message');

    my $page = $hub->pages->new_from_name('this is a test message again');
    ok($page->exists, "simple page exists");

    search_for_term("to cause some errors");
}

sub get_email {
    my $name = shift;

    my $file = "t/test-data/email/$name";
    die "No such email $name" unless -f $file;

    return Socialtext::File::get_contents($file);
}
