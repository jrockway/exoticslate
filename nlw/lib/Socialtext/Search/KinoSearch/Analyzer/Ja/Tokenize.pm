# @COPYRIGHT@
package Socialtext::Search::KinoSearch::Analyzer::Ja::Tokenize;
use strict;
use warnings;
use base 'Socialtext::Search::KinoSearch::Analyzer::Base';

# NOTE. this is not 'use bytes'.
# We only want to be able to call bytes::length(); we do not want
# our strings to be treated as sequence of bytes.
require bytes;
use Encode qw(decode_utf8 encode_utf8);
use KinoSearch::Analysis::TokenBatch;
use Socialtext::Search::KinoSearch::Analyzer::Ja::mecabif;
use Socialtext::AppConfig;
use File::Spec::Functions qw(catdir catfile updir);
use File::Basename qw(dirname);
use Cwd qw(abs_path);

use Socialtext::AppConfig;
my $config = Socialtext::AppConfig->new;
my $sharedir = $config->code_base;
my @dicdir = ( dicdir => catdir( $sharedir, "l10n", "mecab" ) );

# Generate mecab files if this is a dev-env and it doesn't exist.
if ( $config->_startup_user_is_human_user ) {
    unless ( -e catfile( $dicdir[1], "dicrc" ) ) {
        my $dir    = dirname(__FILE__);
        my $script = abs_path(catfile(
            $dir, (updir) x 6, "build", "bin",
            "convert-mecab-juman-dict-to-utf8"
        ));
        system($script) and die "Could not generate Juman Mecab files!\n";
    }
}

sub analyze {
    my ($self, $batch) = @_;
    local ($_);
    $batch = $self->_get_batch_from_input($batch);

    my @all;
    while ($batch->next) {
	    push @all, decode_utf8($batch->get_text);
    }

    my $if = Socialtext::Search::KinoSearch::Analyzer::Ja::mecabif->new(
	@dicdir
    );

    my $new_batch = KinoSearch::Analysis::TokenBatch->new;
    for ($if->analyze(@all)) {
	    $new_batch->append($_, 0, length($_));
    }
    return $new_batch;
}

1;
