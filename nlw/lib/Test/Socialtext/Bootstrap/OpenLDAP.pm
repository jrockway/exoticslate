package Test::Socialtext::Bootstrap::OpenLDAP;
# @COPYRIGHT@

use strict;
use warnings;
use base qw(Socialtext::Bootstrap::OpenLDAP);
use Test::Builder;

sub import {
    my ($class, @args) = @_;

    # see if failure to auto-detect is fatal or not
    my $fatal = grep { $_ eq ':fatal' } @args;

    # auto-detect OpenLDAP
    #
    # If failure to auto-detect is fatal, abort.  Otherwise, skip all tests
    # (so we don't impose restrictions on developers that they have to have
    # OpenLDAP installed in order to run the test suites).
    eval {
        $class->_autodetect_slapd();
        $class->_autodetect_schema_dir();
        $class->_autodetect_module_dir();
    };
    if ($@) {
        my $message = "OpenLDAP not detected: $@";
        my $builder = Test::Builder->new();

        if ($fatal) {
            unless ($builder->has_plan()) {
                $builder->no_plan();
            }
            $builder->ok(0);
            $builder->diag($message);
            exit;
        }

        $builder->skip_all($message);
    }
}

1;

=head1 NAME

Test::Socialtext::Bootstrap::OpenLDAP - Test::Builder helper for Socialtext::Bootstrap::OpenLDAP

=head1 SYNOPSIS

  # auto-detect OpenLDAP, skipping all tests if it can't be found.
  use Test::Socialtext::Bootstrap::OpenLDAP;
  use Test::Socialtext tests => ...

  # bootstrap OpenLDAP, add some data, and start testing
  ...

or, if you want to fail outright if OpenLDAP can't be found...

  # auto-detect OpenLDAP, failing the test and aborting if it
  # can't be found.
  use Test::Socialtext::Bootstrap::OpenLDAP qw(:fatal);
  use Test::Socialtext tests => ...

=head1 DESCRIPTION

C<Test::Socialtext::Bootstrap::OpenLDAP> implements a C<Test::Builder> helper
for C<Socialtext::Bootstrap::OpenLDAP>.  On load, we try to auto-detect the
installed copy of OpenLDAP and then skip/fail tests as appropriate.

By default, C<Test::Socialtext::Bootstrap::OpenLDAP> does a "skip_all" if
we're unable to find OpenLDAP.  By using the C<:fatal> tag on import, though,
you can turn this into an assertion which causes the tests to fail outright.

B<NOTE:> this does mean, though, that you have to C<use> this bootstrap
I<before> you set up your test plan!

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Socialtext::Bootstrap::OpenLDAP>.

=cut
