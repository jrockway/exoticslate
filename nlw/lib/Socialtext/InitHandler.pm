# @COPYRIGHT@
package Socialtext::InitHandler;

use strict;
use warnings;

our $VERSION = '0.01';

use File::chdir;
use Socialtext::AppConfig;
use Socialtext::Skin;
use Socialtext::Pluggable::Adapter;
use Socialtext::Workspace;
use Socialtext::System qw(shell_run);
use Fcntl ':flock';
use Socialtext::User::Cache;

sub handler {
    # This env var is set in the apache-perl config file (nlw.conf)
    if ($ENV{NLW_DEV_MODE} && ! Socialtext::AppConfig->benchmark_mode) {
        my $r = shift;
        if ($r->uri !~ m{^/data}) {
            my $stamp_file = Socialtext::Paths::storage_directory('make_ran');
            my $mod = (stat $stamp_file)[9] || 0;
            if ($mod < time - 5) {
                open M, "> $stamp_file";
                print M time();
                close M;
                Socialtext::Pluggable::Adapter->make;
                _regen_combined_js($r);
            }
            local $Socialtext::System::SILENT_RUN = 1;
            shell_run '-st-widgets update-all --noremote';
        }
    }

    {
        # make all users use the in-memory cache (per process) in Apache
        no warnings 'once';
        $Socialtext::User::Cache::Enabled = 1;
    }

}

sub _regen_combined_js {
    my $r = shift;

    # Figure out what skin to build
    my ($ws_name) = $r->uri =~ m{^/([^/]+)/index\.cgi$};
    my $workspace = $ws_name ? Socialtext::Workspace->new(name=>$ws_name) : undef;
    my $skin_name = $workspace ? $workspace->skin_name : 's3';
    my $skin      = Socialtext::Skin->new(name => $skin_name);

    for my $dir ($skin->make_dirs) {
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
