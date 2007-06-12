#!perl
# @COPYRIGHT@

use warnings;
use strict;

use Test::HTTP::Socialtext '-syntax', 'no_plan';

use JSON;
use Readonly;
use Socialtext::User;
use Socialtext::Workspace;
use Test::Live fixtures => ['foobar'];
use Test::More;
use URI;

$JSON::UTF8 = 1;

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

    my $result = jsonToObj($test->response->content);
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
# note that for now, ONLY a business admin can do this, but they can do 
# it anywhere.
{
    $Test::HTTP::BasicUsername = 'devnull1@socialtext.com';

    my $target_role = 'member';
    my $manipulated_username = 'devnull1@socialtext.com';

    my $membership_payload =
      objToJson( { username => $manipulated_username,
                   rolename => $target_role } );

    test_http "POST membership - working" {
        >> POST $BASE
        >> Content-type: application/json
        >>
        >> $membership_payload

        << 201
        ~< Location: $BASE
    }
    # now check the db to see if it made it through
    my $user = Socialtext::User->new( username => $manipulated_username );
    my $workspace = Socialtext::Workspace->new( name => 'foobar' );
    my $role_name = $workspace->role_for_user( user => $user )->name;
    is( $role_name, $target_role,  "role is $target_role" );
}

{
Socialtext::AlzaboWrapper::ClearCache();
    my $manipulated_username = 'devnull1@socialtext.com';
    my $target_role = 'workspace_admin';
    my $membership_payload =
      objToJson( { username => $manipulated_username,
                   rolename => $target_role } );

    test_http "POST membership - working back to workspace_admin" {
        >> POST $BASE
        >> Content-type: application/json
        >>
        >> $membership_payload

        << 201
        ~< Location: $BASE
    }
    # now check the db to see if it made it through
    my $user = Socialtext::User->new( username => $manipulated_username );
    my $workspace = Socialtext::Workspace->new( name => 'foobar' );
    my $role_name = $workspace->role_for_user( user => $user )->name;
    is( $role_name, $target_role,  "role is $target_role" );
}


{
    my $membership_payload =
      objToJson( {} );

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
 objToJson( { username => $manipulated_username,
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

  diag( "POST returned:\n" .  $test->response->content . "\n" );

  # now check the db to see if it made it through
  my $user = Socialtext::User->new( username => $manipulated_username );
  ok( $user, "$manipulated_username found in Socialtext" );
  my $workspace = Socialtext::Workspace->new( name => 'foobar' );
  my $role_name = $workspace->role_for_user( user => $user )->name;
  is( $role_name, $target_role,  "role is $target_role" );
 };
}
