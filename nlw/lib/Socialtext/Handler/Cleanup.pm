# @COPYRIGHT@
package Socialtext::Handler::Cleanup;
use strict;
use warnings;

use Apache;
use File::Temp 0.16 ();
use Socialtext::Cache ();
use Socialtext::SQL ();

sub handler {
    my $r = shift;

    # Clean up lookup caches
    Socialtext::Cache->clear();

    File::Temp::cleanup();

    Socialtext::SQL::invalidate_dbh();

    # This must always come last since it may cause the process to
    # exit.
    _call_apache_size_limit($r);
}

BEGIN {
    # We want A::SL to be optional since it doesn't work on all
    # platforms, and isn't really criticial.
    if ( eval { require Apache::SizeLimit; 1 } ) {
        # Why is this necessary?
        #
        # As of version 0.9, the handler() sub is prototyped with ($$) in
        # order to make mod_perl recognize it as a method handler. However, we
        # also want this code to not blow up with earlier versions of
        # Apache::SizeLimit until all our active branches are requiring 0.9,
        # so we have to be able to call it the old way too.
        #
        # We use eval "string" because we want to make sure that Perl only
        # sees one version of the sub compiled. If it sees the non-OO version
        # and we have A::SL 0.9 then it will cause a compile-time error.

        my $s = Apache->server;
        my $max_process  = $s->dir_config( 'st_max_process_size' );
        my $max_unshared = $s->dir_config( 'st_max_unshared_size' );
        my $min_shared   = $s->dir_config( 'st_min_shared_size' );

        if ( Apache::SizeLimit->VERSION and (Apache::SizeLimit->VERSION >= 0.9) ) {
            Apache::SizeLimit->set_max_process_size(  $max_process )  if $max_process;
            Apache::SizeLimit->set_max_unshared_size( $max_unshared ) if $max_unshared;
            Apache::SizeLimit->set_min_shared_size(   $min_shared )   if $min_shared;
            eval 'sub _call_apache_size_limit { Apache::SizeLimit->handler(shift); }';
            die $@ if $@;
        }
        else {
            $Apache::SizeLimit::MAX_PROCESS_SIZE  = $max_process  if $max_process;
            $Apache::SizeLimit::MAX_UNSHARED_SIZE = $max_unshared if $max_unshared;
            $Apache::SizeLimit::MIN_SHARED_SIZE   = $min_shared   if $min_shared;
            eval 'sub _call_apache_size_limit { Apache::SizeLimit::handler(shift); }';
            die $@ if $@;
        }
    }
    else {
        *_call_apache_size_limit = sub {};
    }
}

1;

__END__


=head1 NAME

Socialtext::Handler::Cleanup - a CleanupHandler for NLW

=head1 SYNOPSIS

  PerlCleanupHandler  Socialtext::Handler::Cleanup

=head1 DESCRIPTION

A handler to which we can add cleanup code and have it run for all
requests.

Currently it just runs C<File::Temp::cleanup()>.

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=cut
