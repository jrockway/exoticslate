#!perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Socialtext tests => 32;
fixtures( 'admin', 'foobar' );

use IPC::Run;

SIMPLE_EMAIL: {
    my $in = get_email('simple');
    my ($out, $err);
    my @command = ('bin/st-admin', 'deliver-email', '--workspace', 'admin');

    IPC::Run::run \@command, \$in, \$out, \$err;
    my $return = $? >> 8;
    
    is($return, 0, 'command returns proper exit code with simple message');
    is($err, '', 'no stderr output with simple message');
    is($out, '', 'no stdout output with simple message');
}

EMAIL_WITHOUT_SUBJECT: {
    my $in = get_email('no-subject');
    my ($out, $err);
    my @command = ('bin/st-admin', 'deliver-email', '--workspace', 'admin');

    IPC::Run::run \@command, \$in, \$out, \$err;
    my $return = $? >> 8;
    
    is($return, 0, 'command returns proper exit code with no subject message');
    is($err, '', 'no stderr output with no subject message');
    is($out, '', 'no stdout output with no subject message');
    ok(-d Test::Socialtext::Environment->instance()->base_dir() .
        '/data/admin/mail_from_devnull1_mon_18_oct_2004_17_24_16_0700',
        'page was created');

    my $hub = new_hub('admin');
    my $page = $hub->pages->new_from_name(
       'Mail from devnull1, Mon, 18 Oct 2004 17:24:16 -0700'
    );
    like($page->metadata->Date, qr/\d+.*GMT/, 'Date looks like a date');
}

NORMAL_MAIL: {
    my $hub = new_hub('admin');
    $hub->current_workspace->permissions->add(
        role       => Socialtext::Role->Guest(),
        permission => Socialtext::Permission->new( name => 'email_in' ),
    );

    my $in = get_email('EmailReceiver');
    warn $in;
    my ($out, $err);
    my @command = ('bin/st-admin', 'deliver-email', '--workspace', 'admin');

    IPC::Run::run \@command, \$in, \$out, \$err;
    my $return = $? >> 8;

    is($return, 0, 'command returns proper exit code');
    is($err, '', 'no stderr output');
    is($out, '', 'no stdout output');

    check_monkey_email( new_hub('admin') );

    $hub->current_workspace->permissions->remove(
        role       => Socialtext::Role->Guest(),
        permission => Socialtext::Permission->new( name => 'email_in' ),
    );
}

CASE_OF_WORKSPACE_IN_TO_ADDRESS: {
    my $hub = new_hub('foobar');
    $hub->current_workspace->permissions->add(
        role       => Socialtext::Role->Guest(),
        permission => Socialtext::Permission->new( name => 'email_in' ),
    );

    my $ws = Socialtext::Workspace->new( name => 'FooBar' );
    die "nope" unless $ws;


    my $in = get_email('EmailReceiver');
    my ($out, $err);
    my @command = ('bin/st-admin', 'deliver-email', '--workspace', 'FooBar');

    IPC::Run::run \@command, \$in, \$out, \$err;
    my $return = $? >> 8;

    is($return, 0, 'command returns proper exit code');
    is($err, '', 'no stderr output');
    is($out, '', 'no stdout output');

    check_monkey_email( new_hub('foobar') );

    $hub->current_workspace->permissions->remove(
        role       => Socialtext::Role->Guest(),
        permission => Socialtext::Permission->new( name => 'email_in' ),
    );
}

exit;


sub check_monkey_email
{
    my $hub = shift;

    my $page_name = '[monkey] CVS monkey and ape2';
    my $page = $hub->pages->new_from_name($page_name);
    ok( $page, "Found a page with the name '$page_name'" );
    is( $page->title, $page_name,
        'check that page title matches subject' );
    like( $page->content, qr{From:\s+"John Williams"\s+<mailto:williams\@tni.com>},
          'content includes email sender name & address' );
    like( $page->content, qr{Date:\s+\QWed, 15 Sep 2004 13:32:14 -0600 (MDT)\E},
          'content includes date from email headers' );
    is( $page->metadata->MessageID,
        '<Pine.LNX.4.33.0409151241140.5203-100000@sharkey.morinda.com>',
        'check that page metadata Message-ID matches the message id in email' );
    like( $page->metadata->Received,
          qr/\Qlists.sourceforge.net ([66.35.250.206]\E\s+\Qhelo=sc8-sf-list1.sourceforge.net)\E/,
          'check that page metadata Received matches part of the Received header in email' );

    my $categories = $page->metadata->Category;
    ok( scalar @$categories, 'page has category metadata' );
    is_deeply( [ sort @$categories ], [ 'Email', 'ape', 'monkey' ],
               'Categories are ape & monkey' );

    my $attachments = $page->hub->attachments->all( page_id => $page->id );
    is( @$attachments, 0,
        'an email without attachments generates a page without attachments' );
}

sub get_email {
    my $name = shift;

    my $file = "t/test-data/email/$name";
    die "No such email at $file" unless -f $file;

    return Socialtext::File::get_contents($file);
}
