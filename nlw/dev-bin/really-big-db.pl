#!/usr/bin/perl
# @COPYRIGHT@
use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";
use Socialtext::SQL qw/get_dbh/;
use List::Util qw(shuffle);

my $now = time;
my $nowish = substr("$now",-5);

my $ACCOUNTS = 1000;
my $USERS = 2000; # _Must_ be bigger than $ACCOUNTS
my $PAGES = 1000;
my $MAX_WS_ASSIGN = 50; # must be much smaller than accounts (at least 20x smaller)
my $PAGE_VIEW_EVENTS = 450_000;
my $OTHER_EVENTS = 50_000;
my $WRITES_PER_COMMIT = 2500;

my $create_ts = '2007-01-01 00:00:00+0000';
my @accounts;
my @workspaces;
my @users;
my %ws_to_acct;
my @pages;

my $total_writes = 0;
my $writes = 0;
my $commits = 0;

my $dbh = get_dbh();
$| = 1;

$dbh->{AutoCommit} = 0;
$dbh->rollback;
$dbh->{RaiseError} = 1;

sub maybe_commit {
    return unless $writes >= $WRITES_PER_COMMIT;
    print ".";
    $dbh->commit;

    $total_writes += $writes;
    $commits++;
    $writes = 0;
}

{
    print "Creating $ACCOUNTS accounts with $ACCOUNTS workspaces";

    my $acct_sth = $dbh->prepare_cached(qq{
        INSERT INTO "Account" (account_id, name)
        VALUES (nextval('"Account___account_id"'), ?)
    });
    my $ws_sth = $dbh->prepare_cached(qq{
        INSERT INTO "Workspace" (
            workspace_id, name, title, 
            account_id, created_by_user_id, skin_name
        ) VALUES (
            nextval('"Workspace___workspace_id"'), ?, ?,
            currval('"Account___account_id"'), 1, 's3'
        )
    });

    for (my $i=1; $i<=$ACCOUNTS; $i++) {
        $acct_sth->execute("Test Account $nowish $i");
        $ws_sth->execute("test_workspace_${nowish}_$i", "Test Workspace $nowish $i");
        $writes += 2;
        
        my ($acct_id) = $dbh->selectrow_array(q{SELECT currval('"Account___account_id"')});
        push @accounts, $acct_id;
        my ($ws_id) = $dbh->selectrow_array(q{SELECT currval('"Workspace___workspace_id"')});
        push @workspaces, $ws_id;
        $ws_to_acct{$ws_id} = $acct_id;

        maybe_commit();
    }

    print " done!\n";
}


{
    print "enable people & dashboard for 5% of the accounts";

    my $pd_sth = $dbh->prepare_cached(qq{
        INSERT INTO account_plugin (
            account_id, plugin
        ) VALUES (
            ?, ?
        )
    });

    my $pd_enabled = int(@accounts * 0.05);
    foreach my $acct_id (@accounts[0 .. $pd_enabled]) {
        for my $plugin ( 'people', 'dashboard', 'widgets' ) {
            $pd_sth->execute( $acct_id, $plugin );
            $writes++;
        }

        maybe_commit();
    }
    print " done!\n";
}

{
    my $n = $ACCOUNTS;
    my $m = $n;
    my $name = $ACCOUNTS;
    my %rand_accounts = map {$_=>1} @accounts;

    my $ws_sth = $dbh->prepare_cached(qq{
        INSERT INTO "Workspace" (
            workspace_id, name, title, 
            account_id, created_by_user_id, skin_name
        ) VALUES (
            nextval('"Workspace___workspace_id"'), ?, ?,
            ?, 1, 's3'
        )
    });

    print "Assigning $ACCOUNTS more workspaces to random accounts (geometric dist.)";
    while ($n > 0) {
        $m = int($n / 2.0);
        $m = 1 if $m <= 0;

        # pick an account at random
        # assign M workspaces to it
        my $acct_id = (keys %rand_accounts)[0];
        delete $rand_accounts{$acct_id};

        for (my $j=0; $j<$m; $j++) {
            $name++;
            $ws_sth->execute("test_workspace_${nowish}_$name", "Test Workspace $nowish $name", $acct_id);
            $writes++;
            my ($ws_id) = $dbh->selectrow_array(q{SELECT currval('"Workspace___workspace_id"')});
            push @workspaces, $ws_id;
            $ws_to_acct{$ws_id} = $acct_id;
            maybe_commit();
        }

        $n -= $m;
    }
    print " done!\n";
}

{
    print "Adding $USERS users";

    my $user_id_sth = $dbh->prepare_cached(qq{
       INSERT INTO "UserId" (
           system_unique_id, driver_key, driver_unique_id, driver_username
       ) VALUES (
           nextval('"UserId___system_unique_id"'), ?,
           nextval('"User___user_id"'), ?
       )
    });
    my $user_sth = $dbh->prepare_cached(qq{
        INSERT INTO "User" (
            user_id, username, email_address, password, first_name, last_name
        ) VALUES (
            currval('"User___user_id"'), ?, ?, ?, ?, ?
        )
    });
    my $user_meta_sth = $dbh->prepare_cached(qq{
        INSERT INTO "UserMetadata" (
           user_id, email_address_at_import, 
           created_by_user_id, primary_account_id
        ) VALUES (
           currval('"UserId___system_unique_id"'), ?, NULL, 1
        )
    });

    for (my $user=1; $user<=$USERS; $user++) {
        my $uname = "user-$user-$nowish\@ken.socialtext.net";
        $user_id_sth->execute('Default', $uname);
        $user_sth->execute($uname, $uname, 'password', "First$user", "Last$user" );
        $user_meta_sth->execute( $uname );
        my ($system_unique_id) = $dbh->selectrow_array(q{SELECT currval('"UserId___system_unique_id"')});
        push @users, $system_unique_id;
        $writes += 3;
        maybe_commit();
    }
    print " done!\n";
}

{
    print "Assigning users to accounts and workspaces";

    my $updt_sth = $dbh->prepare_cached(q{
        UPDATE "UserMetadata"
        SET primary_account_id = ?
        WHERE user_id = ?
    });
    my $assign_sth = $dbh->prepare_cached(q{
        INSERT INTO "UserWorkspaceRole" (user_id, workspace_id, role_id)
        VALUES (?, ?, 3)
    });

    sub assign_random_workspaces {
        my ($user_id, $number, $workspaces) = @_;
        my %done;

        my $primary_ws = $workspaces[int(rand(@$workspaces))];
        $updt_sth->execute($ws_to_acct{$primary_ws}, $user_id);
        $assign_sth->execute($user_id, $primary_ws);
        $writes += 2;
        $done{$primary_ws} = 1;

        my $assigned = 1;
        # put an upper-bound on the guess-and-check method of randomly
        # assigning workspaces
        my $max = int(1.5 * $number);
        for (my $i=0; $i<$max; $i++) {
            my $ws_id = $workspaces[int(rand(@$workspaces))];
            next if $done{$ws_id};

            # assign a user to a workspace
            $assign_sth->execute($user_id, $ws_id);
            $writes++;
            $done{$ws_id} = 1;

            last if keys(%done) >= $number;
        }
        maybe_commit();
    }

    # assigns half of the users to some number of workspaces
    my %rand_users = map { $_ => 1 } @users;
    for (my $i=1; $i<=$USERS/2; $i++) {
        my $m = int(rand($MAX_WS_ASSIGN))+1;
        my $user_id = (keys %rand_users)[0];
        delete $rand_users{$user_id};
        assign_random_workspaces($user_id, $m, \@workspaces); 
    }

    print " done!\n";
}

print "CHECK >>> system-wide users with the default account: ";
print $dbh->selectrow_array('select count(*) from "UserMetadata" where primary_account_id = 1');
print "\n";

{
    print "creating $PAGES pages";
    my $page_sth = $dbh->prepare_cached(q{
        INSERT INTO page (
            workspace_id, page_id, name, 
            last_editor_id, creator_id,
            last_edit_time, create_time,
            current_revision_id, current_revision_num, revision_count,
            page_type, deleted, summary
        ) VALUES (
            ?, ?, ?,
            ?, ?,
            ?::timestamptz + ?::interval, ?::timestamptz,
            ?, 1, 1,
            'wiki', 'f', 'summary'
        )
    });

    for (my $p=1; $p<=$PAGES; $p++) {
        my $ws = $workspaces[int(rand(scalar @workspaces))];
        my $editor = $users[int(rand(scalar @users))];
        my $creator = $users[int(rand(scalar @users))];
        my $page_id = "page_${nowish}_$p";
        $page_sth->execute(
            $ws, $page_id, "Page: $nowish $p!",
            $editor, $creator,
            $create_ts, rand(int($PAGES)).' seconds', $create_ts,
            '20070101000000',
        );
        $writes++;
        maybe_commit();
        push @pages, [$ws, $page_id];
    }
    print " done!\n";
}

{
    print "generating $PAGE_VIEW_EVENTS page view events";
    my $ev_sth = $dbh->prepare_cached(q{
        INSERT INTO event (
            at, event_class, action, 
            actor_id, page_workspace_id, page_id
        ) VALUES (
            ?::timestamptz + ?::interval, 'page', 'view', 
            ?, ?, ?
        )
    });
    for (my $i=0; $i<$PAGE_VIEW_EVENTS; $i++) {
        my $actor = $users[int(rand(scalar @users))];
        my $page = $pages[int(rand(scalar @pages))];
        $ev_sth->execute(
            $create_ts, rand(int($PAGES)).' seconds', 
            $actor, $page->[0], $page->[1]
        );
        $writes++;
        maybe_commit();
    }
    print " done!\n";
}

{
    print "generating $OTHER_EVENTS other events";
    my $ev_sth = $dbh->prepare_cached(q{
        INSERT INTO event (
            at, 
            event_class, action, 
            actor_id, person_id, page_workspace_id, page_id
        ) VALUES (
            ?::timestamptz + ?::interval,
            ?, ?, 
            ?, ?, ?, ?
        )
    });

    for (my $i=0; $i<$OTHER_EVENTS; $i++) {
        my $actor = $users[int(rand(scalar @users))];
        my $page = [undef,undef];
        my $person = undef;
        my @actions;

        my @classes = (('page') x 8, 'person');
        my $class = $classes[int(rand(scalar @classes))];
        if ($class eq 'page') {
            my $page = $pages[int(rand(scalar @pages))];
            @actions = qw(tag_add watch_add watch_delete rename edit_save comment duplicate edit_contention delete);
        }
        else {
            my $person = $users[int(rand(scalar @users))];
            @actions = qw(tag_add watch_add tag_delete watch_delete edit_save);
        }
        my $action = $actions[int(rand(scalar @actions))];

        $ev_sth->execute(
            $create_ts, rand(int($PAGES)).' seconds', 
            $class, $action,
            $actor, $person, $page->[0], $page->[1]
        );
        $writes++;
        maybe_commit();
    }
    print " done!\n";
}

print "CHECK >>> system-wide page view events: ";
print $dbh->selectrow_array(q{select count(*) from event where event_class = 'page' and action = 'view'});
print "\n";

print "CHECK >>> system-wide non-page view events: ";
print $dbh->selectrow_array(q{select count(*) from event where not (event_class = 'page' and action = 'view')});
print "\n";

# page tags?
# people tags?

# page watchlists
# people watchlists

$commits++;
$total_writes += $writes;
$dbh->commit;

print "ALL DONE ($total_writes writes, $commits commits)!\n";
