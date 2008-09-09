# @COPYRIGHT@
package Socialtext::InitHandler;

use strict;
use warnings;

our $VERSION = '0.01';

use File::chdir;
use Socialtext::AppConfig;
use Socialtext::File;
use Socialtext::Skin;
use Socialtext::Pluggable::Adapter;
use Socialtext::Workspace;
use Fcntl ':flock';

sub handler {
    # This env var is set in the apache-perl config file (nlw.conf)
    if ($ENV{NLW_DEV_MODE} && ! Socialtext::AppConfig->benchmark_mode) {
        my $r = shift;
        _regen_combined_js($r);
        Socialtext::Pluggable::Adapter->make;
    }
}

sub _regen_combined_js {
    my $r = shift;

    # Figure out what skin to build
    my ($ws_name) = $r->uri =~ m{^/([^/]+)/index\.cgi$};
    my $workspace = $ws_name ? Socialtext::Workspace->new(name=>$ws_name)
                             : Socialtext::NoWorkspace->new;
    my $skin_name = $workspace->skin_name;

    my $skin = Socialtext::Skin->new;

    for my $dir ($skin->make_dirs($skin_name)) {
        local $CWD = $dir;

        my $semaphore = "$dir/build-semaphore";
        open( my $lock, ">>", $semaphore )
            or die "Could not open $semaphore: $!\n";
        flock( $lock, LOCK_EX )
            or die "Could not get lock on $semaphore: $!\n";
        system( 'make', 'all' ) and die "Error calling make in $dir: $!";
        close($lock);
    }
}

1;

__END__

=head1 NAME

Socialtext::InitHandler - A PerlInitHandler for Socialtext

=head1 SYNOPSIS

  PerlInitHandler  Socialtext::InitHandler

=head1 DESCRIPTION

This module is the place to put per-request initialization code.  It
should only be called for requests which are generating dynamic
content.  It does not need to be called when serving static files.

It does the following:

=over 4

=item *

Re-generates the javascript files if in a development mode.

=back

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005 Socialtext, Inc., All Rights Reserved.

=cut
