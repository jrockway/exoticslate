#!perl
use warnings;
use strict;
use lib 'lib';
use lib 't/lib';
use Test::More;
use Socialtext::Pluggable::Plugin;
use Socialtext::Gadgets::Gadget;
use Data::Dumper;
use Cwd;

my $cdir = getcwd;

plan tests => 16;

my $base_url = "file:///$cdir/t/widget";

my $api = Socialtext::Pluggable::Plugin->new();

my $gadget = Socialtext::Gadgets::Gadget->install($api,"$base_url/01.xml",'test01');

my $storage = $gadget->storage;
my $content = $gadget->content();
like($content,qr/this is my html data. My title is 'TEST TITLE'./);

my $prefs = $gadget->get_user_prefs();
my ($pref,@discard) = @{$prefs};
is($pref->{name},'title');
is($pref->{val},'TEST TITLE');

my @requires = $gadget->requires;
is(scalar(@requires),1);
is($requires[0],'setprefs');

my $features = $gadget->get_features;

is(scalar(@$features),9);

ok(grep { /core.js/ } map { $_->{src} } @$features);

my $messages = $gadget->messages();

# XXX TODO: LOCALE is hardcoded in gadget to 'en' so we are only testing for
# 'en' local

is($messages->{test_en_1},'test en data 1','en is set');
is($messages->{test_en_2},'test en data 2','en is set');

my $mprefs = $gadget->module_prefs;
is($mprefs->{title},'TEST TITLE');

# test to make sure * evals to 'en'
$gadget = Socialtext::Gadgets::Gadget->install($api,"$base_url/02.xml",'test02');
$mprefs = $gadget->module_prefs;
is($mprefs->{title},'TEST TITLE','expanded __UP_title__');

$messages = $gadget->messages();
is($messages->{test_en_1},'test en data 1','en is undefined');
is($messages->{test_en_2},'test en data 2','en is undefined');

# test to make sure no lang tag evals to 'en'
$gadget = Socialtext::Gadgets::Gadget->install($api,"$base_url/03.xml",'test03');

$messages = $gadget->messages();
is($messages->{test_en_1},'test en data 1','en is *');
is($messages->{test_en_2},'test en data 2','en is *');

$mprefs = $gadget->module_prefs;
is($mprefs->{title},'TEST TITLE EN','expanded __MSG_title_en__');






