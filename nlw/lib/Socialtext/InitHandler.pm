# @COPYRIGHT@
package Socialtext::InitHandler;

use strict;
use warnings;

our $VERSION = '0.01';

use File::chdir;
use Socialtext::AppConfig;
use Socialtext::File;
use Socialtext::AlzaboWrapper;


sub handler {
    # This ensures that we have a good DBI handle underneath.  The
    # handle could be bad if the Pg server restarted since the last
    # request in this Apache process, or if this Apache process forked
    # for post-processing in the last request, or if this child had
    # not been used in so long that the handle timed out.
    Socialtext::Schema->CheckDBH();

    Socialtext::AlzaboWrapper->ClearCache();

    # This env var is set in the apache-perl config file (nlw.conf)
    _regen_combined_js()
        if $ENV{NLW_DEV_MODE} && ! Socialtext::AppConfig->benchmark_mode;
}

sub _regen_combined_js {
    my $dir = Socialtext::File::catdir( Socialtext::AppConfig->code_base(),
                                 'javascript' );
    local $CWD = $dir;

    system( 'make', 'all' )
        and die "Cannot call 'make combined-source.js' in $dir: $!";
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

Calls C<< Socialtext::Schema->CheckDBH() >> to make sure that the
cached schema object has a usable database handle.

=item *

Calls C<< Socialtext::AlzaboWrapper->ClearCache() >>. This clears any
cached data from a previous request.

=back

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005 Socialtext, Inc., All Rights Reserved.

=cut
