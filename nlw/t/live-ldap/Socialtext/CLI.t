#!perl
# @COPYRIGHT@

use strict;
use warnings;
use File::Slurp qw(write_file);
use Test::Output;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext;

BEGIN {
    require Socialtext::People::Profile;
    plan skip_all => 'People is not linked in' if ($@);
    plan tests => 36;
}

fixtures( 'db', 'destructive' );

use_ok 'Socialtext::CLI';

###############################################################################
# over-ride "_exit", so we can capture the exit code
our $LastExitVal;
{
    no warnings 'redefine';
    *Socialtext::CLI::_exit = sub { $LastExitVal=shift; die 'exited'; };
}

###############################################################################
# bootstrap OpenLDAP; we'll use a single copy of this for *all* of the LDAP
# tests we're going to run here.

# ... bootstrap OpenLDAP
my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP';

# ... populate OpenLDAP
ok $openldap->add('t/test-data/ldap/base_dn.ldif'), '.. added data: base_dn';
ok $openldap->add('t/test-data/ldap/people.ldif'), '... added data: people';

# ... save LDAP config, and set up user_factories to use this LDAP server
my $openldap_cfg = $openldap->ldap_config();
my $rc = Socialtext::LDAP::Config->save($openldap_cfg);
ok $rc, 'saved LDAP config to YAML';

my $openldap_id = $openldap_cfg->id();
my $user_factories = "LDAP:$openldap_id;Default";
my $appconfig = Socialtext::AppConfig->new();
$appconfig->set( 'user_factories' => $user_factories );
$appconfig->write();
is $appconfig->user_factories(), $user_factories, 'added LDAP user factory';

###############################################################################
MASS_ADD_USERS: {
    # mass-add an LDAP user
    # - is required for the 'update_ldap_user' test that comes below
    add_ldap_user: {
        # create CSV file, matching a user in the LDAP store
        my $csvfile = Cwd::abs_path(
            (File::Temp::tempfile(SUFFIX=>'.csv', OPEN=>0))[1]
        );
        write_file $csvfile,
            join(',', 'John Doe', qw(ignored@example.com ignored_first ignored_last ignored_password position company location work_phone mobile_phone home_phone));

        # do mass-add
        expect_success(
            sub {
                Socialtext::CLI->new(
                    argv => ['--csv', $csvfile]
                )->mass_add_users();
            },
            qr/\QUpdated user John Doe\E/,
            'mass-add-users successfully added LDAP user'
        );

        # verify that the User record contains the data from LDAP, and not the
        # data that we provided in the CSV
        my $user = Socialtext::User->new(username => 'John Doe');
        ok $user, 'found test user';
        isa_ok $user->homunculus, 'Socialtext::User::LDAP', '... which is an LDAP user';
        is $user->username, 'John Doe', '... using username from LDAP';
        is $user->first_name, 'John', '... using first_name from LDAP';
        is $user->last_name, 'Doe', '... using last_name from LDAP';
        is $user->password, '*no-password*', '... using password from LDAP';

        # verify that a People profile was created with the data from CSV
      SKIP: {
          skip 'Socialtext People is not installed', 7 unless $Socialtext::MassAdd::Has_People_Installed;
            my $profile = Socialtext::People::Profile->GetProfile($user, no_recurse => 1);
            ok $profile, '... ST People profile was found';
            is $profile->position, 'position', '... ... using position from CSV';
            is $profile->company, 'company', '... ... using company from CSV';
            is $profile->location, 'location', '... ... using location from CSV';
            is $profile->work_phone, 'work_phone', '... ... using work_phone from CSV';
            is $profile->mobile_phone, 'mobile_phone', '... ... using mobile_phone from CSV';
            is $profile->home_phone, 'home_phone', '... ... using home_phone from CSV';
        }
    }

    # mass-update an LDAP user
    # - relies on the 'add_ldap_user' test above having been run to create the
    #   user
    update_ldap_user: {
        # create CSV file, to try to update the LDAP user created in the
        # 'add_ldap_user' test above
        my $csvfile = Cwd::abs_path(
            (File::Temp::tempfile(SUFFIX=>'.csv', OPEN=>0))[1]
        );
        write_file $csvfile,
            join(',', 'John Doe', qw(updated@example.com updated_first updated_last updated_password updated_position updated_company));

        # do mass-add
        expect_success(
            sub {
                Socialtext::CLI->new(
                    argv => ['--csv', $csvfile]
                )->mass_add_users();
            },
            qr/\QUpdated user John Doe\E/,
            'mass-add-users successfully updated LDAP user'
        );

        # verify that the User record still contains the data from LDAP, and
        # not the data that we provided in the CSV
        my $user = Socialtext::User->new(username => 'John Doe');
        ok $user, 'found test user';
        isa_ok $user->homunculus, 'Socialtext::User::LDAP', '... which is an LDAP user';
        is $user->username, 'John Doe', '... using username from LDAP';
        is $user->first_name, 'John', '... using first_name from LDAP';
        is $user->last_name, 'Doe', '... using last_name from LDAP';
        is $user->password, '*no-password*', '... using password from LDAP';

        # verify that our People profile updates were applied
      SKIP: {
          skip 'Socialtext People is not installed', 7 unless $Socialtext::MassAdd::Has_People_Installed;
            my $profile = Socialtext::People::Profile->GetProfile($user, no_recurse => 1);
            ok $profile, '... ST People profile was found';
            is $profile->position, 'updated_position', '... ... using position from CSV';
            is $profile->company, 'updated_company', '... ... using company from CSV';
            is $profile->location, 'location', '... ... using original location';
            is $profile->work_phone, 'work_phone', '... ... using original work_phone';
            is $profile->mobile_phone, 'mobile_phone', '... ... using original mobile_phone';
            is $profile->home_phone, 'home_phone', '... ... using original home_phone';
        }
    }
}
exit;




###############################################################################
# These functions copied directly from `t/Socialtext/CLI.t`
sub expect_success {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $sub    = shift;
    my $expect = shift;
    my $desc   = shift;

    my $test = ref $expect ? \&stdout_like : \&stdout_is;

    local $LastExitVal;
    $test->(
        sub {
            eval { $sub->() };
        },
        $expect,
        $desc
    );
    warn $@ if $@ and $@ !~ /exited/;
    is( $LastExitVal, 0, 'exited with exit code 0' );
}

sub expect_failure {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $sub    = shift;
    my $expect = shift;
    my $desc   = shift;
    my $error_code = shift || 1;

    my $test = ref $expect ? \&stderr_like : \&stderr_is;

    local $LastExitVal;
    $test->(
        sub {
            eval { $sub->() };
        },
        $expect,
        $desc
    );
    warn $@ if $@ and $@ !~ /exited/;
    is( $LastExitVal, $error_code, "exited with exit code $error_code" );
}
