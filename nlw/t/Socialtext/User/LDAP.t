#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext tests => 17;
fixtures( 'ldap' );
use Test::Exception;
use mocked 'Net::LDAP';

use_ok 'Socialtext::User::LDAP';

Create_user: {
    By_user_id: {
        my $user = Socialtext::User::LDAP->new( user_id => 'cn=one,dc=foo,dc=bar' );
        isa_ok $user, 'Socialtext::User::LDAP';
        is $user->username, 'one', "User's username is 'one'";
        is $user->email_address, 'one@foo.bar', "User's email address is 'one\@foo.bar'";
    }
By_username: {
        my $user = Socialtext::User::LDAP->new( username => 'one' );
        isa_ok $user, 'Socialtext::User::LDAP';
        is $user->username, 'one', "User's username is 'one'";
        is $user->email_address, 'one@foo.bar', "User's email address is 'one\@foo.bar'";
    }
By_email: {
        my $user = Socialtext::User::LDAP->new( email_address => 'one@foo.bar' );
        isa_ok $user, 'Socialtext::User::LDAP';
        is $user->username,      'one',         "User's username is 'one'";
        is $user->email_address, 'one@foo.bar', "User's email address is 'one\@foo.bar'";
    }
Invalid_key: {
        is( Socialtext::User::LDAP->new( foo => 'foo' ), undef,
            "Nonexistent user is undef" );
    }
}

Validate_password: {
    Plaintext_password: {
        my $user = Socialtext::User::LDAP->new(username => 'one');
        isa_ok $user, 'Socialtext::User::LDAP';
        ok $user->password_is_correct('password'), 'correct plaintext pw';
        ok !$user->password_is_correct('bad'), 'incorrect plaintext pw';
    }
}

Search_for_users: {
    my @results = Socialtext::User::LDAP->Search('one');
    is_deeply \@results, [
        { 
            driver_name => 'LDAP',
            email_address => 'one@foo.bar',
            name_and_email => 'One Loser <one@foo.bar>',
        },
    ], "Search results are complete";
}

Password_Is_Sentinal_Value: {
    my $user = Socialtext::User::LDAP->new( username => 'one' );
    isa_ok $user, 'Socialtext::User::LDAP';
    ok $user->password, '*no-password*';
}
