#!perl
# @COPYRIGHT@

use warnings;
use strict;

use Test::HTTP::Socialtext '-syntax', tests => 53;

use JSON::XS;
use Readonly;
use Test::Live fixtures => ['admin'];
use Test::More;
use URI;

use Socialtext::User;
use Socialtext::Workspace;

Readonly my $WORKSPACE    => 'admin';
Readonly my $NEW_USER_URL => Test::HTTP::Socialtext->url("/data/users");
Readonly my $BASE =>
    Test::HTTP::Socialtext->url("/data/workspaces/$WORKSPACE/users");
Readonly my $ADMIN_USER => 'devnull1@socialtext.com';
Readonly my $TEST_USER  => 'devnull9@socialtext.com';
Readonly my $WEAK_USER  => 'devnull2@socialtext.com';

# confirm the test user is not subscribed to the workspace
user_not_subscribed($TEST_USER);

# as ADMIN_USER:
#   create the TEST_USER
#   subscribe TEST_USER to WORKSPACE
#
#   make user ADMIN_USER gets 405 on methods other than DELETE on
#     $BASE/$TEST_USER url
#
#   delete/unsubscribe TEST_USER from WORKSPACE
add_user($TEST_USER);
check_methods();
delete_user( $TEST_USER, '204', '', $Test::HTTP::BasicUsername );

# as ADMIN_USER
#   subscribed TEST_USER back to WORKSPACE
subscribe_user($TEST_USER);

# as ADMIN_USER
#   create the WEAK_USER
#   subscribe WEAK_USER to WORKSPACE
add_user($WEAK_USER);

# as WEAK_USER
#   attempt to delete TEST_USER from WORKSPACE
#   get 403 (Forbidden) in response
$Test::HTTP::BasicUsername = $WEAK_USER;
delete_user( $TEST_USER, '403', 'User not authorized' );

# as TEST_USER
#   delete TEST_USER from WORKSPACE
#   (a user can unsub themselves)
$Test::HTTP::BasicUsername = $TEST_USER;
delete_user( $TEST_USER, '204', '' );

# as ADMIN_USER
#   attempt to delete now unsub'd TEST_USER from WORKSPACE
#   correct response is 404 with readable message
$Test::HTTP::BasicUsername = $ADMIN_USER;
delete_user( $TEST_USER, '404', "$TEST_USER is not a member of $WORKSPACE" );

# as WEAK_USER
#   attempt to delete now unsub'd TEST_USER from WORKSPACE
#   correct response is 403
#   should always be the same whether user is there or not
$Test::HTTP::BasicUsername = $WEAK_USER;
delete_user( $TEST_USER, '403', 'User not authorized' );


# as TEST_USER
#   attempt to delete now unsub'd TEST_USER from WORKSPACE
#   correct response is 404
$Test::HTTP::BasicUsername = $TEST_USER;
delete_user( $TEST_USER, '404', "$TEST_USER is not a member of $WORKSPACE" );

# as ADMIN_USER
#   subscribe TEST_USER back to workspace
#   confirm ADMIN_USER is_business_admin and is_technical_admin
#   remove ADMIN_USER from workspace
#   attempt to delete TEST_USER from WORKSPACE
#   correct response is 204
$Test::HTTP::BasicUsername = $ADMIN_USER;
subscribe_user($TEST_USER);
user_is_role($ADMIN_USER, 'business_admin');
user_is_role($ADMIN_USER, 'technical_admin');
delete_user($ADMIN_USER, '204', '');
delete_user($TEST_USER, '204', '');

# add the user back and then remove business_admin
subscribe_user($TEST_USER);
my $admin_user = Socialtext::User->new(username=>$ADMIN_USER);
$admin_user->set_business_admin(0);
user_is_role($ADMIN_USER, 'business_admin', 'not');

# as just technical_admin
delete_user($TEST_USER, '204', '');

# put the TEST_USER back in, we need business admin
# because only business admin can add to workspace
$admin_user->set_business_admin(1);
subscribe_user($TEST_USER);

# remove business_admin and technical_admin, now no powers
$admin_user->set_business_admin(0);
$admin_user->set_technical_admin(0);
user_is_role($ADMIN_USER, 'technical_admin', 'not');
user_is_role($ADMIN_USER, 'business_admin', 'not');
delete_user($TEST_USER, '403', 'User not authorized');

# give back business_admin powers
$admin_user->set_business_admin(1);
subscribe_user($TEST_USER);
delete_user($TEST_USER, '204', '');

sub user_is_role {
    my $username = shift;
    my $role = shift;
    my $notness = shift || undef;

    test_http "confirm $username is $role" {
        >> GET $NEW_USER_URL/$username
        >> Accept: application/json

        << 200

        my $content = $test->response->content;
        my $info = decode_json($content);

        if ($notness) {
            ok( ! $info->{"is_$role"}, "is_$role should not be set" );
        } else {
            ok( $info->{"is_$role"}, "is_$role should be set" );
        }
    }
}

sub check_methods {
    foreach my $method ('GET', 'POST', 'HEAD') {
        test_http "confirm no $method available for $BASE/$TEST_USER" {
            >> $method $BASE/$TEST_USER

            << 405
        }
    }
}

sub delete_user {
    my $target_user       = shift;
    my $expected_status   = shift;
    my $expected_response = shift;
    my $test              = Test::HTTP::Socialtext->new(
        "confirm delete $target_user from workspace, as admin");
    $test->delete("$BASE/$target_user");
    $test->status_code_is(
        $expected_status,
        "response status should be $expected_status"
    );
    my $content = $test->response->content;
    chomp $content;
    is $content, $expected_response,
        "response content, $content, should be $expected_response";
}

# add devnull9 to the workspace and confirm
sub add_user {
    my $target_user = shift;

    # first we have to create the user
    my $user_payload = encode_json(
        {
            username      => $target_user,
            email_address => $target_user,
            first_name    => 'a',
            last_name     => 'b',
            password      => $Test::HTTP::BasicPassword,
        }
    );
    test_http "create $target_user" {
        >> POST $NEW_USER_URL
        >> Content-type: application/json
        >>
        >> $user_payload

        << 201
    }

    subscribe_user($target_user);
}

sub subscribe_user {
    my $target_user = shift;

    # then we subscribe them to the workspace
    my $subscription_payload = encode_json(
        {
            username                     => $target_user,
            rolename                     => 'member',
        }
    );

    test_http "add $target_user to workspace" {
        >> POST $BASE
        >> Content-type: application/json
        >>
        >> $subscription_payload

        << 201
    }

    my $user = Socialtext::User->new( username => $target_user );
    my $workspace = Socialtext::Workspace->new( name => $WORKSPACE );
    my $role_name = $workspace->role_for_user( user => $user )->name;
    is( $role_name, 'member',  "role is member" );
}

sub user_not_subscribed {
    my $username = shift;

    test_http "confirm $username not present" {
        >> GET $BASE
        >> Accept: application/json

        << 200

        my $content = $test->response->content;
        my $info = decode_json($content);
        my @users = map $_->{name}, @$info;
        ok( !grep(/^$username$/, @users), "$username not in workspace");
    }
}
