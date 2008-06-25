package Socialtext::Events::Recorder;
# @COPYRIGHT@
use warnings;
use strict;
use Socialtext::SQL qw/sql_execute/;
use Socialtext::JSON qw/encode_json/;

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    return bless {}, $class;
}

=head2 record_event()

This method logs an event to the event storage system.  Parameters:

=over 4

=item action

What the actor did to the object (e.g. View, Edit, Delete).

=item actor

Who did the event.  

Can be a Socialtext::User object, or a user_id from the "User" table.

=item class

To which type of object did the event happen (e.g. Page, Workspace, Person, Attachment, Spreadsheet, etc).

=item object

The human-readable identifier of this class of object (e.g. page title)

=item context

Useful annotations for this event, stored as key-value pairs.  Optional.

=back

=cut

sub record_event {
    my $self = shift;
    my $p = shift || die 'Requires Event parameters';
    $p->{timestamp} ||= "now";
    if ($p->{context} and ref($p->{context})) {
        $p->{context} = encode_json($p->{context});
    }
    $p->{context} ||= '';

    my @fields = qw/timestamp action actor class object context/;
    for (@fields) {
        die "$_ parameter is missing" unless defined $p->{$_};
    }

    if (ref( my $a = $p->{actor} ) ) {
        $p->{actor} = $a->user_id;
    }

    sql_execute(
        q{INSERT INTO event VALUES ( '?'::timestamptz, ?, ?, ?, ?, ? )},
        @{ $p }{ @fields },
    );
}

1;
