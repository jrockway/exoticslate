#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 1;
fixtures( 'admin_no_pages' );

use Socialtext::File;


my $hub = new_hub('admin');
my $cat = $hub->category();

if ( my $pid = fork ) {
    # We hold the lock long enough to ensure that the child process is
    # also waiting on the lock before writing here in the parent.
    my $lock_fh = Socialtext::File::write_lock( $cat->_lock_file );
    sleep 4;

    Socialtext::File::set_contents_utf8( $cat->_dot_categories_file(), "c\nd\n" );

    close $lock_fh;

    wait;
}
else {
    sleep 2;
    $cat->categories( { a => 'a', b => 'b' } );
    $cat->_save();
    exit;
}

$cat->load();
is_deeply( $cat->all(), { a => 'a', b => 'b' },
           'Because of locking, the child process should have '
           . 'written its categories _after_ the parent process' );
