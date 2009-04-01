package Socialtext::User::Find;
# @COPYRIGHT@
use Moose;
use Socialtext::SQL qw/get_dbh sql_execute/;
use Socialtext::String;
use namespace::clean -except => 'meta';
use Socialtext::User;

has viewer => (is => 'rw', isa => 'Socialtext::User', required => 1);
has limit => (is => 'rw', isa => 'Maybe[Int]');
has offset => (is => 'rw', isa => 'Maybe[Int]');

sub typeahead_find {
    my $self = shift;
    my $filter = shift;

    die 'Illegal Filter'
        unless (defined $filter && length $filter);

    $filter = lc Socialtext::String::trim($filter);

    # If we don't get rid of these wildcards, the LIKE operator slows down
    # significantly.  Matching on anything other than a prefix causes Pg to not
    # use the 'text_pattern_ops' indexes we've prepared for this query.
    $filter =~ s/[_%]//g; # remove wildcards

    # Remove start of word character
    $filter =~ s/\\b//g;
    $filter .= '%';

    my $sql = q{
        SELECT user_id, first_name, last_name,
               email_address, driver_username AS username
        FROM users
        WHERE (
            lower(first_name) LIKE $1 OR
            lower(last_name) LIKE $1 OR
            lower(email_address) LIKE $1 OR
            lower(driver_username) LIKE $1
        )
        AND EXISTS (
            SELECT 1
            FROM account_user viewer
            JOIN account_user found USING (account_id)
            WHERE viewer.user_id = $2 AND found.user_id = users.user_id
        )
        ORDER BY last_name ASC, first_name ASC
        LIMIT $3 OFFSET $4
    };

    #local $Socialtext::SQL::PROFILE_SQL = 1;
    my $sth = sql_execute($sql, 
        $filter, $self->viewer->user_id, $self->limit, $self->offset);

    my $results = $sth->fetchall_arrayref({}) || [];

    for my $row (@$results) {
        my $user = Socialtext::User->new(user_id => $row->{user_id});
        $row->{best_full_name} = $user->best_full_name;
    }
    return $results;
}

__PACKAGE__->meta->make_immutable;
1;
