#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 50;
fixtures( 'rdbms_clean' );

use Socialtext::Account;
use Socialtext::Permission qw( ST_ADMIN_WORKSPACE_PERM ST_EMAIL_IN_PERM );
use Socialtext::Role;
use Socialtext::Workspace;

{
    for my $set_name (
        qw( public
            member-only
            authenticated-user-only
            public-read-only
            public-comment-only
            public-authenticate-to-edit
            intranet
          )
        ) {
        my $ws = Socialtext::Workspace->create(
            name       => $set_name,
            title      => 'Test',
            account_id => Socialtext::Account->Socialtext()->account_id,
            skip_default_pages => 1,
        );

        $ws->set_permissions( set_name => $set_name );

        is( $ws->current_permission_set_name(), $set_name,
            "current permission set is $set_name" );

        my %p = (
            role       => Socialtext::Role->Guest(),
            permission => ST_EMAIL_IN_PERM,
        );
        my $guest_has_email_in = $ws->role_has_permission(%p);

        if ($guest_has_email_in) {
            $ws->remove_permission(%p);
        }
        else {
            $ws->add_permission(%p);
        }

        is( $ws->current_permission_set_name(), $set_name,
            "current permission set is still $set_name regardless of guest's email_in permission" );

        $ws->set_permissions( set_name => $set_name );

        is( $ws->role_has_permission(%p), ( $guest_has_email_in ? 0 : 1 ),
            "guest's email_in permission is unchanged after sceond call to set_permissions()" );

        my %defaults = map { $_ => ( $set_name =~ /^public/ ? 0 : 1 ) }
            qw( allows_html_wafl email_notify_is_enabled homepage_is_dashboard );
        $defaults{email_addresses_are_hidden} = $set_name =~ /^public/ ? 1 : 0;

        for my $k ( sort keys %defaults ) {
            is( $ws->$k(), $defaults{$k}, "$k is $defaults{$k}" );
        }
    }

    my $ws = Socialtext::Workspace->new( name => 'intranet' );
    $ws->add_permission(
        role       => Socialtext::Role->Guest(),
        permission => ST_ADMIN_WORKSPACE_PERM,
    );

    is( $ws->current_permission_set_name(), 'custom',
        'current permission set is custom' );
}


# XXX - needs more tests of methods for setting/removing permissions
