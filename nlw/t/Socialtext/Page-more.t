#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 33;
fixtures( 'admin_with_extra_pages' );

my $hub = new_hub('admin');
my $pages = $hub->pages;
my $creator = Socialtext::User->new( username => 'devnull1@socialtext.com' );

{
    Socialtext::Page->new( hub => $hub )
        ->create(
            title   => 'simple', content => 'as can be',
            creator => $creator,
        );
    my $simple = $pages->new_from_name('simple');
    is $simple->content, "as can be\n", 'basic usage';
    ok ! $simple->is_default, 'new page is not a default page';
}

{
    Socialtext::Page->new( hub => $hub )->create(
        title      => 'basic usage',
        content    => 'with category',
        categories => ['test'],
        creator => $creator,
    );
    my $basic = $pages->new_from_name('basic usage');
    is $basic->metadata->Category->[0], 'test', 'category saved';
}

ok $pages->new_from_name('Quick Start')->is_default, "Quick Start is a default page";

{
    my $sample = $hub->pages->new_from_name('FormattingTest');
    $sample->doctor_links_with_prefix('Foozle');
    like $sample->content, qr/\[FoozleFormattingToDo\]/,
        'doctor_links_with_prefix';
    like $sample->content, qr/\[wiki 101\]}/,
        'do not doctor interwiki links';
    $sample->doctor_links_with_prefix('Foozle');
    like $sample->content, qr/\[FoozleFormattingToDo\]/,
        'doctor_links_with_prefix refuses to double-prefix';

    for my $input ( Socialtext::File::all_directory_files('t/extra-pages') ) {
        my $content = Socialtext::File::get_contents("t/extra-pages/$input");
        $sample->content($content);
        $sample->doctor_links_with_prefix('');
        is $sample->content, $content,
            'doctor_links harmlessness ' . $input;
    }
}

{    # create time twiddling
    my $expected_date = DateTime->from_epoch(epoch => 1231231231);
    my $stringified_expected = '2009-01-06 08:40:31 GMT';
    Socialtext::Page->new( hub => $hub )->create(
        title   => 'dated',
        content => '(irrelevant)',
        date    => $expected_date,
        creator => $creator,
    );
    my $page = $hub->pages->new_from_name('dated');
    my $fs_epoch = (stat $page->file_path)[9];
    is $fs_epoch, $expected_date->epoch,
        'filesystem date - needed for RecentChanges';
    is $page->metadata->Date, $stringified_expected,
        'metadata date - needed for display';
}

use utf8;
my %cases = (
    'asdf'    => 'asdf',
    '_asdf'   => 'asdf',
    'as_df'   => 'as_df',
    'asdf_'   => 'asdf',
    'a@#$sdf' => 'a_sdf',
    'as > df' => 'as_df',
    "as\ndf"  => 'as_df',
    'as[d]f'  => 'as_d_f',
    'asüf'    => 'as%C3%BCf',
    # XXX - is this really what we want '' to go to?
    ''        => '',
    '-:-'     => '_',
    '0'       => '_'
    # ...any others?
    # You're going to hate me for this, but transliterate your new test to
    # javascript, too please (see main.js). (TODO - OAOO these tests)
);
while (my($in, $out) = each %cases) {
    is(Socialtext::Page->name_to_id($in), $out, "'$in' => '$out'");
}

{ # handle newlines in Subject headers
    my $page = Socialtext::Page->new( hub => $hub )->create(
        title   => "new\nline",
        content =>
            'You are only young once, but you can stay immature indefinitely.',
        creator => $creator,
    );
    $page = $hub->pages->new_from_name('new line');
    is $page->metadata->Subject, 'new line',
        'Page loads can handle newlines in Subjects - found in the wild';
}
