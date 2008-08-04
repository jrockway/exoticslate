package Socialtext::Events::Recorder;
# @COPYRIGHT@
use warnings;
use strict;
use Socialtext::SQL qw/sql_execute/;
use Socialtext::JSON qw/encode_json decode_json/;

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    return bless {}, $class;
}

sub _unbox_objects {
    my $self = shift;
    my $p = shift;

    # subject
    _translate_ref_to_id($p, 'actor' => 'user_id');

    # objects
    _translate_ref_to_id($p, 'page' => 'id');
    _translate_ref_to_id($p, 'person' => 'user_id');

    # context
    _translate_ref_to_id($p, 'workspace' => 'workspace_id');
    _translate_ref_to_id($p, 'target_workspace' => 'workspace_id');
    _translate_ref_to_id($p, 'target_page' => 'id');

}

=head2 record_event()

This method logs an event to the event storage system.  Parameters:

=cut

sub record_event {
    my $self = shift;
    my $p = shift || die 'Requires Event parameters';

    # compatibility aliases:
    $p->{event_class} ||= $p->{class};
    $p->{at} ||= $p->{timestamp};

    my $class = $p->{event_class};
    $p->{at} ||= "now";

    my @fields = qw/at action actor event_class/;
    for (@fields) {
        die "$_ parameter is missing" 
            unless defined $p->{$_};
    }

    die "event_class must be lower-case alpha-with-underscoes"
        unless $class =~ /^[a-z_]+$/;

    die "page parameter is missing for a page event"
        if ($class eq 'page' && !$p->{page});
    die "workspace parameter is missing for a page event"
        if ($class eq 'page' && !$p->{workspace});
    die "person parameter is missing for a person event"
        if ($class eq 'person' && !$p->{person});

    $self->_unbox_objects($p);

    if (ref $p->{context}) {
        $p->{context} = encode_json($p->{context}) 
    }
    else {
        $@ = undef;
        eval { decode_json($p->{context}) } if $p->{context};
        die "context isn't legal json: $p->{context}" if ($@);
    }

    # order: column, parameter, placeholder
    my @ins_map = (
        [ at                => $p->{at},          '?::timestamptz', ],
        [ event_class       => $p->{event_class}, '?', ],
        [ action            => $p->{action},      '?', ],
        [ actor_id          => $p->{actor},       '?', ],
        [ person_id         => $p->{person},      '?', ],
        [ page_id           => $p->{page},        '?', ],
        [ page_workspace_id => $p->{workspace},   '?', ],
        [ tag_name          => $p->{tag_name},    '?', ],
        [ context           => $p->{context},     '?', ],
    );

    my $fields = join(', ', map {$_->[0]} @ins_map);
    my @values = map {$_->[1]} @ins_map;
    my $placeholders = join(', ', map {$_->[2]} @ins_map);

    my $sql = "INSERT INTO event ( $fields ) VALUES ( $placeholders )";
    sql_execute($sql, @values);
}

sub _translate_ref_to_id {
    my ($p, $key, $id_method) = @_;
    my $ref = $p->{$key};
    return unless ref $ref;
    return unless $ref->can($id_method);
    $p->{$key} = $ref->$id_method;
}

1;
