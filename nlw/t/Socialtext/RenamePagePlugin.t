#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 1;
fixtures( 'admin_no_pages' );

my $admin = new_hub('admin');

{
    my $plugin = $admin->rename_page;

    my $html = $plugin->rename_popup();
    ok ($html =~ /Rename/, 'Got us a rename box');
}
