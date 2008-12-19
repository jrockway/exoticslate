package Test::Socialtext::User;
# @COPYRIGHT@

use strict;
use warnings;
use Carp qw(croak);
use Socialtext::SQL qw(sql_execute);
use Socialtext::User;
use Socialtext::Cache;

sub delete_recklessly {
    my ($class, $user_or_homunculus) = @_;
    my $system_user = Socialtext::User->SystemUser;

    # Resolve the User, so we know we've got a `ST::User` object.  This allows
    # for us to be called with a homunculus, and we'll still DTRT.
    # 
    # DON'T use `ST::User->Resolve()`, though, as that's a bit *too* flexible
    # for our needs.
    my $user = Socialtext::User->new( user_id => $user_or_homunculus->user_id );

    # Don't allow for system created Users to be deleted
    if ($user->is_system_created()) {
        croak "can't delete system created users, even recklessly";
    }

    # Re-assign all Workspaces that were "created by" this User so that
    # they're now the responsibility of the System User.
    sql_execute( q{
        UPDATE "Workspace"
           SET created_by_user_id = ?
         WHERE created_by_user_id = ?
        }, $system_user->user_id, $user->user_id
    );

    # Re-assign all Pages that were "created by" this User so that they're now
    # the responsibility of the System User.
    sql_execute( q{
        UPDATE page
           SET creator_id = ?
         WHERE creator_id = ?
        }, $system_user->user_id, $user->user_id
    );

    # Re-assign all Pages that were "last edited by" this User so that they're
    # now the responsibility of the System User.
    sql_execute( q{
        UPDATE page
           SET last_editor_id = ?
         WHERE last_editor_id = ?
        }, $system_user->user_id, $user->user_id
    );

    # Delete the User from the DB, and let this cascade across all other DB
    # tables, nuking data from the DB as it goes.
    sql_execute( q{
        DELETE FROM users
         WHERE user_id = ?
        }, $user->user_id
    );

    # Clear any User cache(s) that may be in use
    Socialtext::Cache->clear();
}

1;

=head1 NAME

Test::Socialtext::User - methods to operate on Users from within tests

=head1 SYNOPSIS

  use Test::Socialtext::User;

  # recklessly delete a User from the DB
  $user = Socialtext::User->new(username => $username);
  Test::Socialtext::User->delete_recklessly($user);

  # or...
  $homunculus = ...
  Test::Socialtext::User->delete_recklessly($homunculus);

=head1 DESCRIPTION

C<Test::Socialtext::User> implements methods that can be used to operate on
C<Socialtext::User> objects from within test suites.

These methods are placed here so that its B<really> obvious that you don't
want to be using these methods as part of the regular operation of the system.
They're useful for test purposes, but beyond that you should keep your fingers
out of them.

=head1 METHODS

=head2 B<Test::Socialtext::User-E<gt>delete_recklessly($user)>

Deletes the given C<$user> record outright, purging B<all> of the data related
to this User from the DB.  This is an B<irreverible> action!

This method accepts either a `Socialtext::User` object, or a homunculus
object.  I<Either> of these will cause the deletion of data relating to this
User.

Workspaces and Pages that this User had created are first re-assigned to be
owned by the System User, so that we don't cascade through a series of deletes
in the DB that leaves the system in a funky state; you'd have files for the
Workspace/Pages on disk but no records for them in the DB.

=head1 AUTHOR

Socialtext, Inc., C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Socialtext, Inc., All Rights Reserved.

=cut
