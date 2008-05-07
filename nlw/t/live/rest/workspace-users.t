#!perl
# @COPYRIGHT@

use warnings;
use strict;

use Test::HTTP::Socialtext '-syntax', tests => 43;

use JSON::XS;
use Readonly;
use Socialtext::User;
use Socialtext::Workspace;
use Test::Live fixtures => ['foobar'];
use Test::More;
use URI;

Readonly my $BASE =>
    Test::HTTP::Socialtext->url('/data/workspaces/foobar/users');

test_http "DELETE users is a bad method" {
    >> DELETE $BASE

    << 405
    << Allow: GET, HEAD, POST
}

test_http "GET html default" {
    >> GET $BASE

    << 200
    ~< Content-type: \btext/html\b
    <<
    ~< devnull1\@socialtext\.com
    ~< devnull2\@socialtext\.com
    ~< devnull\@urth\.org

}

test_http "GET json" {
    >> GET $BASE
    >> Accept: application/json

    << 200
    ~< Content-type: \bapplication/json\b

    my $result = decode_json($test->response->content);
    isa_ok( $result, 'ARRAY', 'JSON response' );
    is( @$result, 3, 'foobar has 3 users.' );

    foreach my $user (@$result) {
        ok( exists $user->{$_}, "user has a '$_'." ) for qw( name uri);

        # Just testing that each URI is valid here.  Checking actual contents
        # will fall to another test.
        my $uri = URI->new_abs($user->{uri}, $BASE);

        >> GET $uri

        $test->name("GET $user->{uri}");

        << 200

    }
}

$Test::HTTP::BasicUsername = 'devnull2@socialtext.com';
test_http "GET html non-admin user" {
    >> GET $BASE

    << 200

}

# we want to all 'membership' by POSTING to /data/workspaces/:ws/users
# where the 'payload' has either a 'username' or a 'user_id' and
# a role_name to assign
# note that for now, ONLY a business admin or technical admin
# can do this, but they can do it anywhere.

# do member add of devnull2 add as devnull1
# do workspace_admin add of devnull2 add as devnull1
add_user('devnull1@socialtext.com', 'devnull2@socialtext.com', 'member');
add_user('devnull1@socialtext.com', 'devnull2@socialtext.com', 'workspace_admin');

# remove business_admin and technical_admin powers and it should
# still work because devnull1 is a workspace admin
my $admin_user
    = Socialtext::User->new( username => 'devnull1@socialtext.com' );
$admin_user->set_business_admin(0);
$admin_user->set_technical_admin(0);
add_user( 'devnull1@socialtext.com', 'devnull2@socialtext.com', 'member' );

# get rid of workspace_admin for devnull1 and see what happens
# should fail now
Socialtext::Workspace->new(name => 'foobar')->remove_user( user => $admin_user );
add_user(
    'devnull1@socialtext.com', 'devnull2@socialtext.com', 'member',
    'FAIL'
);

# reset business_admin to on, should work again
$admin_user->set_business_admin(1);
add_user('devnull1@socialtext.com', 'devnull2@socialtext.com', 'member');

# just technical admin should work
$admin_user->set_business_admin(0);
$admin_user->set_technical_admin(1);
add_user('devnull1@socialtext.com', 'devnull2@socialtext.com', 'member');

$admin_user->set_business_admin(1);

sub add_user {
    my $acting_user = shift;
    my $target_user = shift;
    my $target_role = shift;
    my $fail        = shift || undef;

    $Test::HTTP::BasicUsername = $acting_user;

    my $membership_payload =
      encode_json( { username => $target_user,
                   rolename => $target_role } );

    test_http "POST membership - working for $target_role" {
        >> POST $BASE
        >> Content-type: application/json
        >>
        >> $membership_payload

        if ($fail) {

            << 403

            return;

        } else {

            << 201
            ~< Location: $BASE

        }
    }
    # now check the db to see if it made it through
    my $user = Socialtext::User->new( username => $target_user );
    my $workspace = Socialtext::Workspace->new( name => 'foobar' );
    my $role_name = $workspace->role_for_user( user => $user )->name;
    is( $role_name, $target_role,  "role is $target_role" );
}

{
    my $membership_payload =
      encode_json( {} );

    test_http "POST membership - required field missing" {
        >> POST $BASE
        >> Content-type: application/json
        >>
        >> $membership_payload

        << 400
        <<
        ~< required
    };
}

# we want to allow posting new members that will cause invitations to
# be sent                                                          
{
 $Test::HTTP::BasicUsername = 'devnull1@socialtext.com';
 
 my $target_role = 'member';
 my $manipulated_username = 'devnull8@socialtext.com';
 
 my $membership_payload =
 encode_json( { username => $manipulated_username,
              rolename => $target_role,
              send_confirmation_invitation => 1 } );

 test_http "POST membership - working with send_confirmation_invitation"
 {
  >> POST $BASE
  >> Content-type: application/json
  >>
  >> $membership_payload

  << 201

  $test->header_like( Location => qr{$BASE} );

  # now check the db to see if it made it through
  my $user = Socialtext::User->new( username => $manipulated_username );
  ok( $user, "$manipulated_username found in Socialtext" );
  my $workspace = Socialtext::Workspace->new( name => 'foobar' );
  my $role_name = $workspace->role_for_user( user => $user )->name;
  is( $role_name, $target_role,  "role is $target_role" );
 };
}
