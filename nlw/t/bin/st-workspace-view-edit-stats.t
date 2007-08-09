#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext tests => 14;
fixtures( 'admin_no_pages' );

my $script = "bin/st-workspace-view-edit-stats";
ok -x $script;
$script = "$^X -Ilib $script --no_mail --verbose";

Single_view: {
    stats_ok(
        file => "t/test-data/view-edit-stats/single_view",
        'devnull1@socialtext.com' => [1, 0, 1],
        'Workspace Total' => [1, 0, 1],
    );
}

Single_edit: {
    stats_ok(
        file => "t/test-data/view-edit-stats/single_edit",
        'devnull1@socialtext.com' => [1, 1, 2],
        'Workspace Total' => [1, 1, 2],
    );
}

Unauthenticated_user: {
    stats_ok(
        file => "t/test-data/view-edit-stats/unauth-user",
        no_stats => 1,
    );
}

exit;


sub stats_ok {
    my %opts = @_;
    my $file = delete $opts{file};
    die unless -e $file;
    my $output = qx($script < $file);
    my $expecter = sub {
        my $name = shift;
        my ($line) = $output =~ m/^\|\s+\Q$name\E\s+\|\s+(.+)\s+\|\s*$/m;
        die "Couldn't find '$name' in line!\nOutput:\n$output" unless $line;
        my ($view, $edit, $total) = split qr/\s+\|\s+/, $line;
        is $view, shift, "$name view";
        is $edit, shift, "$name edit";
        is $total, shift, "$name total";
    };

    if (delete $opts{no_stats}) {
        unlike $output, qr/Workspace total/;
    }

    for my $k (keys %opts) {
        $expecter->($k, @{ $opts{$k}});
    }
}
