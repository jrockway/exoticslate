package Socialtext::Migration::Utils;
# @COPYRIGHT@
use strict;
use warnings;
use Socialtext::Schema;
use base 'Exporter'; 
our @EXPORT_OK = qw/ensure_socialtext_schema/;

sub ensure_socialtext_schema {
    my $max_version = shift || die 'A maximum version number is mandatory';

    my $schema = Socialtext::Schema->new;
    my $current_version = $schema->current_version;
    return if $current_version >= $max_version;

    print "Ensuring socialtext schema is at version $max_version\n";
    $schema->sync( to_version => $max_version );
}

1;
