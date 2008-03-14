package Socialtext::Log;
# @COPYRIGHT@

use strict;
use warnings;
use base 'Exporter';
use unmocked 'Test::MockObject';
use unmocked 'Test::Builder';

our @EXPORT = qw(
    clear_log
    logged_count
    next_log
    next_log_is
    next_log_like
    logged_is
    logged_like
    );

our @EXPORT_OK = qw(
    st_log
    );

our %EXPORT_TAGS = (
    all     => [@EXPORT, @EXPORT_OK],
    tests   => [@EXPORT],
    );

###############################################################################
# Set up mock object
my $Instance;

sub st_log {
    my $method = shift;
    unless ($Instance) {
        $Instance = Test::MockObject->new()
            ->set_true(qw( debug info notice warning error critical alert emergency ));
    }
    return $method ? $Instance->$method(@_) : $Instance;
}

sub new {
    return st_log();
}

###############################################################################
# Testing methods
my $Test = Test::Builder->new();

sub clear_log() {
    st_log->clear();
}

sub logged_count() {
    my $count = 0;
    while (1) {
        last if !st_log->call_pos($count+1);
        $count ++;
    }
    return $count;
}

sub next_log(;$) {
    my ($method, $args) = st_log->next_call(@_);
    return undef unless $method;
    return wantarray ? ($method, $args->[1]) : $method;
}

sub next_log_is($$;$) {
    my ($level, $msg, $name) = @_;
    $name ||= "next log entry was: $level => $msg";

    my @logged = next_log();
    my $wasok = (     (defined $logged[0] and ($logged[0] eq $level))
                  and (defined $logged[1] and ($logged[1] eq $msg))
                ) ? 1 : 0;
                

    unless ($Test->ok($wasok, $name)) {
        $logged[0] = 'undef' unless defined $logged[0];
        $logged[1] = 'undef' unless defined $logged[1];
        $Test->diag( "Got:\n\t$logged[0] => $logged[1]\nExpected:\n\t$level => $msg\n" );
    }
}

sub next_log_like($$;$) {
    my ($level, $rgx, $name) = @_;
    $name ||= "next log entry matched: $level => $rgx";

    my @logged = next_log();
    my $wasok  = (     (defined $logged[0] and ($logged[0] eq $level))
                   and (defined $logged[1] and ($logged[1] =~ $rgx))
                 ) ? 1 : 0;

    unless ($Test->ok($wasok, $name)) {
        $logged[0] = 'undef' unless defined $logged[0];
        $logged[1] = 'undef' unless defined $logged[1];
        $Test->diag( "Got:\n\t$logged[0] => $logged[1]\nExpected:\n\t$level => $rgx\n" );
    }
}

sub logged_is($$;$) {
    my ($level, $msg, $name) = @_;
    $name ||= "log contained: $level => $msg";

    my $offset = 0;
    while (1) {
        $offset ++;

        my $sub = st_log->call_pos($offset);
        last unless $sub;
        next unless $sub eq $level;

        my @args = st_log->call_args($offset);
        if ($args[1] and ($args[1] eq $msg)) {
            return $Test->ok(1, $name);
        }
    }

    $Test->ok(0, $name);
}

sub logged_like($$;$) {
    my ($level, $rgx, $name) = @_;
    $name ||= "log contained: $level => $rgx";

    my $offset = 0;
    while (1) {
        $offset ++;

        my $sub = st_log->call_pos($offset);
        last unless $sub;
        next unless $sub eq $level;

        my @args = st_log->call_args($offset);
        if ($args[1] and ($args[1] =~ $rgx)) {
            return $Test->ok(1, $name);
        }
    }

    $Test->ok(0, $name);
}

1;

=head1 NAME

Socialtext::Log - MOCKED Socialtext::Log

=head1 SYNOPSIS

  use mocked 'Socialtext::Log' qw(:tests);

  # clear the log
  clear_log();

  # run your tests (which presumably do some logging)
  ,..

  # check what got logged
  is logged_count(), 3, 'logged right number of entries';

  logged_is   $level, $msg, $test_name;
  logged_like $level, qr/msg/, $test_name;

  next_log_is   $level, $msg, $test_name;
  next_log_like $level, qr/msg/, $test_name;

  ($level, $msg) = next_log();

=head1 DESCRIPTION

F<t/lib/Socialtext/Log.pm> provides a B<mocked> version of C<Socialtext::Log>
that can be used for testing.

This mocked version is implemented as a singleton; all logging is done against
a single mocked object.  Between tests, you probably want to call
C<clear_log()> to clear the log history.

=head1 MOCKED METHODS

B<NOTE:> this mocked version of C<Socialtext::Log> does not (yet) mock all of
the functionality/methods provided by the original.  If you see methods missing
here which you need to test, please add them to the mocked version.

=over

=item B<debug($msg)>

=item B<info($msg)>

=item B<notice($msg)>

=item B<warning($msg)>

=item B<error($msg)>

=item B<critical($msg)>

=item B<alert($msg)>

=item B<emergency($msg)>

=back

=head1 CHECKING YOUR MOCKS

The following methods are built to tie in with C<Test::Builder> to help you
verify that your code has logged the appropriate messages.

=over

=item B<clear_log()>

Clears the log history.  Good idea to do this between tests, so that you don't
have any log entries slipping over from the previous test.

=item B<logged_count()>

Returns a count of the number of entries that have been logged since the last
call to C<clear_log()>.

=item B<next_log($position)>

Returns information on the next log message.  if you provide an optional number
as the C<$position> argument, this method will skip that many log entries,
returning the data for the last one skipped.

In scalar context, returns just the log level.  In array context, returns both
the log level and the message which was logged.

=item B<next_log_is($level, $msg)>

Returns true if the next logged item was the given message, and was logged at
the specified log level.

=item B<next_log_like($level, $regex)>

Returns true if the next logged item matches the given regex, and was logged at
the specified log level.

=item B<logged_is($level, $msg)>

Checks to see if the given message was logged at some point using the specified
log level.  Returns true if it was logged, false otherwise.

The current implementation does not scale especially well, so use this sparingly
if you need to search through hundreds of logged messages.

=item B<logged_like($level, $regex)>

Checks to see if a message matching the given regex was logged at some point
using the specified log level.  Returns true if it was logged, false otherwise.

The current implementation does not scale especially well, so use this sparingly
if you need to search through hundreds of logged messages.

=back

=head1 SEE ALSO

L<Test::MockObject>

=cut
