#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 1;
fixtures( 'admin' );

use Socialtext::Attachments;

# These tests are primarily to test the way Socialtext::Attachments handles
# archives. See t/archive.t for more extensive tests of how we handle
# various types of archive files.

my $hub = new_hub('admin');

my $page = $hub->pages()->new_from_name('Quick Start');
$hub->pages()->current($page);

my $zip = 't/attachments/flat-bundle.zip';
open my $fh, '<', $zip
    or die "Cannot read $zip: $!";

my ($attachment) = $hub->attachments()->create(
    page_id  => $page->id,
    fh       => $fh,
    filename => 'flat-bundle.zip',
    creator  => $hub->current_user(),
);
$attachment->extract;
$attachment->delete(user => $hub->current_user);

is_deeply(
    [ sort map { $_->filename } @{ $hub->attachments()->all() } ],
    [ qw( html-page-wafl.html index-test.doc socialtext-logo-30.gif ) ],
    "Check that all attachments flat-bundle.zip were unpacked and attached",
);
