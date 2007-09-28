package Socialtext::Rest::Hydra;
# @COPYRIGHT@
use strict;
use warnings;

our $VERSION = '0.01';

use Socialtext::Resting::Getopt qw/get_rester/;
use Socialtext::HTTP ':codes';
use Blikistan;
use base 'Socialtext::Rest';

sub GET {
    my ($self, $rest) = @_;

    # XXX hello hard coded Kirsten thing
    my $rester = get_rester(
        'rester-config' => '/home/kirsten/.nlw/etc/hydra-rester.conf',
    );
    die "no server!" unless $rester->server; 

    my %magic_opts;

    my $uri = $rest->query->url(-absolute => 1, -path => 1);
    if ($uri  =~ m#^/hydra/search/pages#) {
	my $search = $rest->query->param('q');
	$magic_opts{search} = $search;
    } elsif ($uri =~ m#^/hydra/search/([^/]+)$#) {
	$magic_opts{search} = $1;
    } elsif ($uri =~ m#^/hydra/(\w+)#) {
        $magic_opts{subpage} = $1;
    }

    my $b = Blikistan->new(
	magic_engine => 'perlSite',
        rester => $rester,
        magic_opts => \%magic_opts,
    );

    $rest->header(
        -type => 'text/html',
        -status => HTTP_200_OK,
    );

    my $stuff = $b->print_blog;

    return $stuff;
}

END:
1;
