#!perl -w
# @COPYRIGHT@
use strict;
use warnings;

use Test::More tests => 41;
use File::Basename qw(dirname);

my $data_dir = dirname(__FILE__) . "/stringify_data";
my %ext_deps = (
    html => 'lynx',
    doc  => 'wvText',
    rtf  => 'unrtf',
    pdf  => 'pdftotext',
    ps   => 'ps2ascii',
    xls  => 'xls2csv',
    mp3  => 'MP3::Tag',
    xml  => 'XML::SAX',
    zip  => 'unzip',
    bin  => 'strings',
);

BEGIN {
    use_ok("Socialtext::File::Stringify");
}

for my $ext (qw(txt html doc rtf pdf ps xls ppt xml mp3 bin)) {
    my $file = $data_dir . "/test.$ext";
    my $text = Socialtext::File::Stringify->to_string($file);
    SKIP: {
        skip( "$ext_deps{$ext} not installed.", 3 ) if should_skip($ext);
        like( $text, qr/This file is a \"$ext\" file/, "Test $ext marker" );
        like( $text, qr/linsey-woolsey/, "Shakespeare 1 ($ext)" );
        like( $text, qr/Their force, their purposes;.+nay, I'll speak that/s,
            "Shakespeare 2 ($ext)" );
    };
}

# Test zip file indexing 
SKIP: {
    skip( "$ext_deps{zip} not installed.", 6 ) if should_skip("zip");
    my $zip_text
        = Socialtext::File::Stringify->to_string("$data_dir/test.zip");

    # these ext correspond to files in the zipfile)
    for my $ext (qw(doc ppt ps html txt xls)) {
    SKIP: {
            skip( "$ext_deps{$ext} not installed.", 1 ) if should_skip($ext);
            like(
                $zip_text, qr/This file is a \"$ext\" file/,
                "Test $ext marker (in zip)"
            );
        }
    };


    PW_PROTECTED: {
        my $protected_zip = "$data_dir/password-vegan.zip";
        die unless -e $protected_zip;
        diag("IF THIS TEST HANGS, HIT ENTER");
        my $text = Socialtext::File::Stringify->to_string(
            $protected_zip);
        ok(1, "Process a PW protected zip file w/o hanging");
    }

};

sub should_skip {
    my $ext = shift;
    return 0 unless exists $ext_deps{$ext};
    if ( $ext_deps{$ext} =~ /:/ ) {
        eval "require $ext_deps{$ext}; 1;";
        return $@ ? 1 : 0;
    }
    else {
        chomp( my $prog = `which $ext_deps{$ext} 2>/dev/null` );
        return $? || length($prog) == 0;
    }
}
