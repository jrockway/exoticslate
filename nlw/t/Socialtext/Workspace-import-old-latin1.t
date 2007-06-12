#!perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Socialtext tests => 2;
fixtures('rdbms_clean');

use Socialtext::User;
use Socialtext::Workspace;

# Version "0" export tarballs did not export in utf8 all the time. See
# RT 20744 for details on what this is testing.

Socialtext::Workspace->ImportFromTarball( tarball => 't/test-data/export-tarballs/import-latin1.tar.gz' );

{
    my $user = Socialtext::User->new( username => 'autarch@urth.org' );
    my $umlaut = Encode::decode( 'latin-1', 'Uml' . chr( 0xE4 ) . 'ut' );

    is( $user->first_name(), $umlaut, 'first name is Umlaut (with umlaut on a)' );
    is( $user->last_name(), 'Smith', 'last name is Smith' );
}
