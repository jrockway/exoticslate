package Socialtext::PageMeta;
# @COPYRIGHT@
use strict;
use warnings;

use base 'Socialtext::Base';
use Socialtext::Indexes ();

use Class::Field qw( field );

sub class_id { 'metadata' }

field Control   => '';
field Subject   => '';
field From      => '';
field Date      => '';
field Received  => '';
field Revision  => '';
field Type      => 'wiki';  # Page type - (wiki|spreadsheet)
field Summary   => '';
field MessageID => '';
field RevisionSummary => '';

field Category  => [];
field Encoding  => '';

field loaded => 0;

sub key_order {
    my $self = shift;
    qw(
        Control
        Subject
        From
        Date
        Received
        Revision
        Type
        Summary
        MessageID
        Category
        Encoding
        RevisionSummary
    )
}

sub add_category {
    my $self = shift;
    my $category = shift;
    chomp $category if $category;

    $category = Socialtext::Encode::ensure_is_utf8($category);
    my $lc_category = lc($category);

    my $exists = 0;
    foreach my $cat (@{$self->{Category}}) {
        if ($lc_category eq lc($cat)) {
            $exists = 1;
            last;
        }
    }
    if (!$exists) {
        push @{$self->{Category}}, $category;
    }
}

sub delete_category {
    my $self = shift;
    my $category = shift;

    my $lc_category = lc($category);
    my $i = 0;
    foreach my $cat (@{$self->{Category}}) {
        if ($lc_category eq lc($cat)) {
            last;
        }
        ++$i;
    }
    if (scalar(@{$self->{Category}}) > $i) {
        splice @{$self->{Category}}, $i, 1;
    }
}

sub has_category {
    my $self = shift;
    my $category = shift;

    $category = lc(Socialtext::Encode::ensure_is_utf8($category));
    my $exists = 0;
    foreach my $cat (@{$self->{Category}}) {
        if ($category eq lc($cat)) {
            return 1;
        }
    }
    return 0;
}

sub from_hash {
    my $self = shift;
    my $hash = shift;
    for my $key (keys %$hash) {
        my $attribute = $key;
        my $value = $hash->{$key};
        $attribute =~ s/-//;
        if ( $self->can($attribute) ) {
            $value = [$value]
                if (ref $self->$attribute and not ref $value);
            $self->$attribute($value);
        }
    }
    $self->loaded(1);
}

sub to_hash {
    my $self = shift;
    my $hash = {};
    for my $key ($self->key_order) {
        my $attribute = $key;
        $key =~ s/^([A-Z][a-z]+)([A-Z].*)$/$1-$2/;
        my $value = $self->$attribute;
        if (ref $value) {
            $hash->{$key} = $value
              if @$value;
        }
        else {
            $hash->{$key} = $value
              if defined $value and length $value;
        }
    }
    return $hash;
}

sub update {
    my $self = shift;
    my %p = @_;
    Carp::confess('no user given to Socialtext::PageMeta->update')
        unless $p{user};

    my $revision = $self->Revision || 0;
    # FIXME: Wrong! should be max of all revisions +1
    $self->Revision($revision + 1);
    $self->From( $p{user}->email_address );
    $self->Date($self->get_date);
    $self->Received($self->get_received)
      unless $self->Received;
    $self->Encoding('utf8');
}

sub get_date {
    my $self = shift;
    my ($sec, $min, $hour, $mday, $mon, $year) = gmtime(time);
    sprintf("%4d-%02d-%02d %02d:%02d:%02d GMT",
            $year + 1900, $mon + 1, $mday, $hour, $min, $sec,
           );
}

sub get_received {
    my $self = shift;
    my $remote_addr = defined $ENV{REMOTE_ADDR}
    ? $ENV{REMOTE_ADDR}
    : 'localhost';
    "from $remote_addr";
}

1;
