#!perl
# @COPYRIGHT@

use strict;
use warnings;

use utf8;

BEGIN {
    # This is needed to fake out HTML::Mason::ApacheHandler to just
    # load outside mod_perl
    sub Apache::perl_hook { 1 }
    sub Apache::server { 0 }
}

use Test::Socialtext tests => 9;
fixtures( 'admin_no_pages' );
use Socialtext::WebApp;
use Encode;
use Storable;

run {
    my $case = shift;
    my %args = %{YAML::Load($case->input)};
    my $copy = Storable::dclone(\%args);
    # Fake, minimal object is all we need right now...
    my $fake_app = bless {}, 'Socialtext::WebApp';
    { 
        no warnings 'redefine';
        *MasonX::WebApp::args = sub { \%args };
    }
    $fake_app->_decode_args;
    is YAML::Dump(\%args), YAML::Dump($copy);
    binmode STDOUT, 'utf8';
    for my $k (keys %args) {
        # Test::Harness can't deal with UTF-8, apparently
        print "# Checking utf-8 flag for: $k\n";
        for my $v (ref $args{$k} ? @{$args{$k}} : $args{$k}) {
            ok Encode::is_utf8($v);
        }
    }
};
__DATA__
===
--- input
scalar_ascii: plain
scalar_utf8: yö
array_utf8: [ yö, knω, it ]
array_ascii: [ you, know, it ]
--- expected
scalar_ascii: plain
scalar_utf8: yö
array_utf8: [ yö, knω, it ]
array_ascii: [ you, know, it ]
