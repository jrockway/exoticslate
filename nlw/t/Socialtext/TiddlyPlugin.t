#!perl
# @COPYRIGHT@
use strict;
use warnings;

use lib 't/lib';

use Test::Socialtext tests => 19;
fixtures('admin_no_pages');

BEGIN {
    use_ok('Socialtext::TiddlyPlugin');
    use_ok('Socialtext::Page');
}

my $Title = "Hey, it is a page";
my $hub = new_hub('admin');

#### Test the units

# class_id
is (Socialtext::TiddlyPlugin->class_id(), 'tiddly', 'class_id is tiddly');

# unplug
eval {
    open STDOUT, ">/dev/null";    # dump output
    binmode STDOUT, 'utf8';
    $hub->tiddly->unplug();
    open STDOUT;
};
if ( my $exception = $@ ) {
    ok(
        Exception::Class->caught(
            'Socialtext::WebApp::Exception::ContentSent'),
        'calling unplug() throws ContentSent exception'
    );
}

# produce_tiddly
# make one page
my $page = Socialtext::Page->new(hub=>$hub)->create(
    title => $Title,
    content => "Righteous\nBro!\n",
    creator => $hub->current_user,
    categories => ['love', 'hope charity'],
);

ok $page->isa('Socialtext::Page'), "we did create a page";

# look at the resulting tiddler
my $html = $hub->tiddly->produce_tiddly(pages => [$page], count => 1);

# turn it into tiddlers
my @chunks = split('<!--STORE-AREA-END-->', $html);
my @tiddlers = split('</div>', $chunks[0]);

# get the one we care about
my $tiddler = $tiddlers[-3];

my ($attributes, $body) = split('>', $tiddler);

is $body, "Righteous\\nBro!\\n", "tiddler content is correct";

my %attribute;
while ($attributes =~ /([\w\.]+)="([^"]+)"/g) {
    $attribute{$1} = $2;
}

is $attribute{'tiddler'}, $page->metadata->Subject,
    'tiddler and subject are the same';
is $attribute{'tiddler'}, $Title, 'tiddler and given title are the same';
is $attribute{'modifier'}, 'devnull1@socialtext.com',
    'tiddler has the devnull1 modifier';
like $attribute{'modified'}, qr{\d{12}},
    'tiddler has a date stamp for modified';
like $attribute{'created'}, qr{\d{12}},
    'tiddler has a date stamp for created';
is $attribute{'tags'},        'love [[hope charity]]',  'tiddler lists correct tags';
is $attribute{'server.type'}, 'socialtext', 'server type is socialtext';
is $attribute{'wikiformat'},  'socialtext', 'Wiki format socialtext';
like $attribute{'server.host'}, qr{^https?://},   'server.host looks like a uri';
is $attribute{'server.workspace'}, 'admin', 'tiddler has the right workspace';
is $attribute{'server.page.id'},   $page->uri,  'page.id is set to uri';
is $attribute{'server.page.name'}, $page->name, 'page.name is to name';
is $attribute{'server.page.version'}, $page->revision_id,
    'version and revision id are the same';

