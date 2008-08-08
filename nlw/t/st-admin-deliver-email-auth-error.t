#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 4;
fixtures( 'admin' );

use IPC::Run;
use Socialtext::Permission;
use Socialtext::Role;
use Socialtext::Workspace;

my $hub = new_hub('admin');
my $ws  = $hub->current_workspace();
my $perms = $ws->permissions();
$perms->remove(
    role       => Socialtext::Role->Guest(),
    permission => Socialtext::Permission->new( name => 'email_in' ),
);

$perms->remove(
    role       => Socialtext::Role->AuthenticatedUser(),
    permission => Socialtext::Permission->new( name => 'email_in' ),
);

{
    my $in = get_email('guest-user');
    my ($out, $err);
    my @command = ('bin/st-admin', 'deliver-email', '--workspace', 'admin');

    IPC::Run::run \@command, \$in, \$out, \$err;
    my $return = $? >> 8;

    is( $return, 255, 'command returns exit code 255 on error' );
    like( $err,
          qr/You do not have permission to send email to the admin workspace\./,
          'authz error results in expected error on stderr' );
    is( $out, '', 'no stdout output with simple message' );

    my $page = $hub->pages->new_from_name('this is a test message again');
    ok( ! $page->exists(), 'page does not exist' );
}

sub get_email {
    my $name = shift;

    my $file = "t/test-data/email/$name";
    die "No such email $name" unless -f $file;

    return Socialtext::File::get_contents($file);
}
