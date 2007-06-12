#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 3;

BEGIN {
    use_ok( 'Socialtext::Search::AbstractFactory' );
}

# Verify that we use the correct class.
{
    my $factory = Socialtext::Search::AbstractFactory->GetFactory;

    ok(
        $factory->isa( Socialtext::AppConfig->search_factory_class ),
        'search_factory_class is obeyed'
    );
}

# Verify that bogus classes blow up.
{
    local $ENV{NLW_APPCONFIG} = 'search_factory_class=This::Class::No::Exist';

    eval {
        my $factory = Socialtext::Search::AbstractFactory->GetFactory;
    };

    like(
        $@,
        qr/^Socialtext::Search::AbstractFactory->GetFactory: /,
        'GetFactory throws exception when given bogus class'
    );
}
