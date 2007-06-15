package Socialtext::Wikil10n;
# @COPYRIGHT@
use strict;
use warnings;
use Socialtext::Resting;
use Socialtext::System qw/shell_run/;
use base 'Exporter';
our @EXPORT_OK = qw(load_existing_l10ns make_rester);

sub load_existing_l10ns {
    my $r     = shift;
    my $title = shift;

    my $content = $r->get_page($title);
    return {} if $r->response->code ne 200;

    #use Data::Dumper;
    #print Dumper($content);
    my %l10n;
    my $cellex = qr/\s+(.+?)?\s+/;
    my $cellex_last = qr/\s+(.+?).+?/;
    my $rowgex = qr/^\|$cellex\|$cellex\|$cellex\|$cellex_last/;
    for (split "\n", $content) {
        next unless m/^\|/;
        next if m/^\|\s+\*/;
        my $row = $_;
        my @cols = $row =~ m/$rowgex/;
        $l10n{ $cols[0] || "" } = {
            msgstr    => $cols[1] || '',
            reference => $cols[2] || "",
            other     => $cols[3] || "",
        };
    }

    return \%l10n;
}

sub make_rester {
    my $live = shift;
    return Socialtext::Resting->new(
        username => 'l10n-bot@socialtext.net',
        password => 'l10n4wiki',
        workspace => 'stl10n',
        server => 'http://www.socialtext.net',
    ) if $live;

    shell_run("-st-admin create-workspace --name stl10n --title stl10n");
    shell_run('-st-admin add-member --workspace stl10n '
            . '--email devnull1@socialtext.com');
    return Socialtext::Resting->new(
        username  => 'devnull1@socialtext.com',
        password  => 'd3vnu11l',
        workspace => 'stl10n',
        server    => "http://localhost:" . ( $> + 20000 ),
    );
}

1;
