package Socialtext::Wikil10n;
# @COPYRIGHT@
use strict;
use warnings;
use Socialtext::Resting;
use base 'Exporter';
our @EXPORT_OK = qw(load_existing_l10ns make_rester);

sub load_existing_l10ns {
    my $r     = shift;
    my $title = shift;

    my $content = $r->get_page($title);
    return {} if $r->response->code ne 200;

    my %l10n;
    my $cellex = qr/\s+(.+?)?\s+/;
    my $rowgex = qr/^\|$cellex\|$cellex\|$cellex\|$cellex\|$/;
    for (split "\n", $content) {
        next unless m/^\|/;
        next if m/^\|\s+\*/;
        my $row = $_;
        my @cols = $row =~ m/$rowgex/;
        $l10n{$cols[0]} = {
            msgstr => $cols[1] || '',
            reference => $cols[2],
            other => $cols[3],
        };
    }

    return \%l10n;
}

sub make_rester {
    return Socialtext::Resting->new(
        username => 'l10n-bot@socialtext.net',
        password => 'l10n4wiki',
        workspace => 'stl10n',
        server => 'http://www.socialtext.net',
    );
}
1;
