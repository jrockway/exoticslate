#!perl
# @COPYRIGHT@
use strict;
use warnings;

use DateTime;
use Test::Socialtext tests => 13;
fixtures('ALL');

BEGIN {
    use_ok "Socialtext::WorkspaceBreadcrumb";
}

SAVE_BREADCRUMB: {
    save_breadcrumb_ok('help-en');
}

UPDATE_BREADCRUMB: {
    # Create initial breadcrumb
    my $bc = save_breadcrumb_ok('admin');
    ok( $bc->timestamp, "Timestamp was set after creation" );
    my $t1 = $bc->parsed_timestamp;

    # Update bread crumb
    $bc = save_breadcrumb_ok('admin');
    my $t2 = $bc->parsed_timestamp;
    my $cmp = DateTime->compare( $t1, $t2 );
    is( $cmp, -1, "First timestamp is before second timestamp" );
}

SAVE_MULTIPLE_BREADCRUMBS: {
    for my $ws (qw(foobar sale exchange public)) {
        save_breadcrumb_ok($ws);
        sleep 1;
    }
}

LIST_BREADCRUMBS: {
    get_breadcrumbs_ok(
        'devnull1@socialtext.com',
        10,
        qw(public exchange sale foobar admin help-en),
    );
}

LIST_BREADCRUMBS_WITH_SMALL_LIMIT: {
    get_breadcrumbs_ok(
        'devnull1@socialtext.com',
        2,
        qw(public exchange),
    );
}

LIST_FOR_DEVNULL2_EMPTY: {
    get_breadcrumbs_ok(
        'devnull2@socialtext.com',
        10,
        qw(),
    );
}

sub save_breadcrumb_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $workspace = shift;
    my $hub       = new_hub($workspace);
    my $bc        = Socialtext::WorkspaceBreadcrumb->Save(
        workspace_id => $hub->current_workspace->workspace_id,
        user_id      => $hub->current_user->user_id,
    );
    ok( $bc->timestamp, "Timestamp was set saving breadcrumb." );
    sleep 1;
    return $bc;
}

sub get_breadcrumbs_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ( $username, $limit, @result ) = @_;
    my $hub = new_hub('admin', $username);    # Workspace doesn't matter here
    my @workspaces = Socialtext::WorkspaceBreadcrumb->List(
        user_id => $hub->current_user->user_id,
        limit => $limit,
    );
    is_deeply(
        [ map { $_->name } @workspaces ], \@result,
        "Comparing breadcrumb results for $username with limit $limit"
    );
    return @workspaces;
}
