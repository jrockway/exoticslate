#!perl
# @COPYRIGHT@
use strict;
use warnings;
use mocked 'Socialtext::Rest';
use Test::More tests => 4;
use Socialtext::CGI::Scrubbed;

BEGIN {
    use_ok 'Socialtext::Rest::Changes';
}

# MONKEY PATCH: over-ride ST::M::Pages->By_seconds_limit() so that it returns
# our test data instead of actually dipping into the DB.
{
    no warnings 'redefine';
    *Socialtext::Model::Pages::By_seconds_limit = sub {
        return [
            # only the barest minimal bits to get us a Page object
            Socialtext::Model::Page->new_from_row( {
                    workspace_name => 'any_workspace',
                    page_id        => 'any_page',
                    last_editor_id => 1,
            } )
        ];
    };
}

# TEST: user names are set correctly in the "recent changes" output.
User_names_are_set_correctly: {
    my $query = Socialtext::CGI::Scrubbed->new;
    my $rest = Socialtext::Rest->new(undef, $query);
    my $a = Socialtext::Rest::Changes->new($rest);
    my @entries =  $a->_hashes_for_query;

    my $recent = shift @entries;
    is $recent->{username}, 'oneusername', 'username';
    is $recent->{best_full_name}, 'Best FullName', 'best fullname exists';
    is $recent->{user_id}, 1, 'UserId is set';
}
