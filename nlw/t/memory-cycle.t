#!perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Socialtext;

BEGIN {
    unless ( eval { require Test::Memory::Cycle;
                    Test::Memory::Cycle->import(); 1 } ) {
        plan skip_all => 'These tests require Test::Memory::Cycle to run.';
    }
}

fixtures( 'admin' );

plan tests => 3;

my $hub = new_hub('admin');

{
    $hub->pages->new_from_name('FormattingTest')->to_html;

    # Alzabo does create cycles between the schema and tables (and
    # then tables and columns), but this does not matter because it is
    # designed so that the schema, and therefore all the objects it
    # contains, are singleton. They are loaded once and never released
    # (that is the point of the Socialtext::Schema module).
    $hub->current_user(undef);
    $hub->current_workspace(undef);

    memory_cycle_ok( $hub, 'check for cycles in Socialtext::Hub object' );
    memory_cycle_ok( $hub->main, 'check for cycles in NLW object' );
    memory_cycle_ok( $hub->viewer,
        'check for cycles in Socialtext::Formatter::Viewer object' );
}
