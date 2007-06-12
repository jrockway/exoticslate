#!perl
# @COPYRIGHT@

use warnings;
use strict;

use Test::Socialtext;
fixtures( 'admin' );

use File::Path ();
use Socialtext::HTMLArchive;

if ( `which zip` =~ /zip/ && `which unzip` =~ /unzip/ ) {
    plan tests => 9;
}
else {
    plan skip_all =>
      'Socialtext::HTMLArchive tests requires zip and unzip binaries in path';
}

my $hub = new_hub('admin');

# add attachments to a page so we can test that attachment/image links
# are processed properly
{
    $hub->pages->current( $hub->pages->new_from_name('welcome') );

    for my $att (qw( revolts.doc socialtext-logo-30.gif )) {
        my $path = "t/attachments/$att";
        my $attachment = $hub->attachments->new_attachment( filename => $path );
        $attachment->save($path);
        $attachment->store( user => $hub->current_user );
    }

    my $content = $hub->pages->current->content;
    $content .= <<"EOF";
{file revolts.doc}
{image socialtext-logo-30.gif}
EOF

    $hub->pages->current->content($content);
    $hub->pages->current->store( user => $hub->current_user );
}

my $archive = Socialtext::HTMLArchive->new( hub => $hub );

my $dir = 't/tmp/junk';
File::Path::rmtree($dir) if -d $dir;
File::Path::mkpath( $dir, 0, 0755 );

my $file_name = "$dir/admin-archive.zip";
unlink $file_name;

$archive->create_zip($file_name);
ok -e $file_name, 'archive exists';

system( 'unzip', '-q', $file_name, '-d', $dir );

for my $f (
    map { "$dir/$_" }
    qw( admin_wiki.htm
    quick_start.htm
    screen.css
    revolts.doc
    socialtext-logo-30.gif )
  ) {
    ok -e $f, "$f exists";
}

my $html_file = 't/tmp/junk/welcome.htm';
open my $fh, '<', $html_file
  or die "Cannot read $html_file: $!";
my $html = do { local $/; <$fh> };

like $html, qr/link.+ href="screen.css"/,
  'admin_wiki.htm has valid css link to screen.css';
like $html, qr/href="revolts.doc"/, 'welcome.htm has valid link to revolts.doc';
like $html, qr/src="socialtext-logo-30.gif"/,
  'welcome.htm has img link to socialtext-logo-30.gif';

