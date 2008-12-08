#!/usr/bin/perl
# @COPYRIGHT@

# Though this isn't actually used in the code, it is possible to 
# forcibly delete a user. If this user happens to have created a workspace
# that workspace's DBMS entry is deleted via a FK cascading delete ( not to
# mention the deletes that cascade upon a workspace delete ).

use strict;
use warnings;
use Socialtext::Account;
use Socialtext::User;
use Socialtext::Workspace;
use Test::Socialtext tests => 4;

fixtures( 'rdbms_clean' );

my $user = Socialtext::User->create(
    username      => 'evil.user@socialtext.com',
    first_name    => 'Evil',
    last_name     => 'User',
    email_address => 'evil.user@socialtext.com',
    password      => 'password'
);
isa_ok $user, 'Socialtext::User';

my $evil_ws = Socialtext::Workspace->create(
    name               => 'evil-workspace',
    title              => 'Evil Workspace',
    account_id         => Socialtext::Account->Default()->account_id,
    created_by_user_id => $user->user_id

);
isa_ok $evil_ws, 'Socialtext::Workspace';

$user->delete( force => 1 );

$evil_ws = Socialtext::Workspace->new( name => 'evil-workspace' );

# The workspace should still exist when we delete the user.
isa_ok $evil_ws, 'Socialtext::Workspace';
is $evil_ws->created_by_user_id, Socialtext::User->SystemUser()->user_id();
