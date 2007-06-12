# @COPYRIGHT@
=head1 NAME

Socialtext::Watchlist - Represents a watchlist for a user in a given workspace

=cut

package Socialtext::Watchlist;

use strict;
use warnings;

our $VERSION = '0.01';

use Socialtext::Schema;

use Alzabo::SQLMaker::PostgreSQL qw(COUNT DISTINCT LOWER CURRENT_TIMESTAMP);
use Socialtext::String;
use Readonly;
use Socialtext::Validate qw( validate USER_TYPE WORKSPACE_TYPE PAGE_TYPE OPTIONAL_INT_TYPE );

=head1 SYNOPSIS

    my $watchlist = Socialtext::Watchlist->new(
                    user => $user,
                    workspace => $ws,
    );

=head1 DESCRIPTION

The Watchlist is designed to allow users to select which pages in a wiki
they would like to keep track of.

Each watchlist object refers to a single workspace/user combination.

=cut

{
    Readonly my $spec => {
        user      => USER_TYPE,
        workspace => WORKSPACE_TYPE,
    };

    sub new {
        my $class = shift;
        my %p     = validate( @_, $spec );

        return bless {
            user_id      => $p{user}->user_id(),
            workspace_id => $p{workspace}->workspace_id(),
        };
    }
}

=head1 REMOTE METHODS

=head2 has_page( $page )

Checks to see if the given page is present in the watchlist

=cut

{
    Readonly my $spec => { page => PAGE_TYPE };

    sub has_page {
        my $self = shift;
        my %p    = validate( @_, $spec );

        my $watchlist_table = Socialtext::Schema->Load()->table('Watchlist');
        return $watchlist_table->function(
            select => 1,
            where  => [
                [
                    $watchlist_table->column('user_id'), '=', $self->{user_id}
                ],
                [
                    $watchlist_table->column('workspace_id'), '=',
                    $self->{workspace_id}
                ],
                [
                    $watchlist_table->column('page_text_id'), '=',
                    $p{page}->id()
                ],
            ],
        ) || 0;
    }

=head2 add_page( $page )

Adds the specified page to the watchlist

=cut

    sub add_page {
        my $self = shift;
        my %p    = validate( @_, $spec );

        my $watchlist_table = Socialtext::Schema->Load()->table('Watchlist');
        $watchlist_table->insert(
            values => {
                user_id      => $self->{user_id},
                workspace_id => $self->{workspace_id},
                page_text_id => $p{page}->id(),
            }
        );
    }

=head2 remove_page( $page )

Removes the specified page from the watchlist

=cut

    sub remove_page {
        my $self = shift;
        my %p    = validate( @_, $spec );

        my $watchlist_table = Socialtext::Schema->Load()->table('Watchlist');
        my $row             = $watchlist_table->row_by_pk(
            pk => {
                user_id      => $self->{user_id},
                workspace_id => $self->{workspace_id},
                page_text_id => $p{page}->id(),
            }
        );
        $row->delete() if $row;
    }
}

=head2 pages()

List the current pages in the watchlist.

=cut

{
    Readonly my $spec => { limit => OPTIONAL_INT_TYPE };

    sub pages {
        my $self            = shift;
        my %p               = validate( @_, $spec );
        my $watchlist_table = Socialtext::Schema->Load()->table('Watchlist');

        my %function = (
            select => $watchlist_table->column('page_text_id'),
            where  => [
                [
                    $watchlist_table->column('workspace_id'), '=',
                    $self->{workspace_id}
                ],
                [ $watchlist_table->column('user_id'), '=', $self->{user_id} ],
            ],
            order_by => $watchlist_table->column('page_text_id'),
        );
        $function{limit} = $p{limit} if defined $p{limit};
        return $watchlist_table->function(%function);
    }
}
1;
