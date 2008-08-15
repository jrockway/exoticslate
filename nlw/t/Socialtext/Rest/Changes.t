#!perl
# @COPYRIGHT@
use strict;
use warnings;
use mocked 'Socialtext::Rest';
use Test::More tests => 7;
use Socialtext::CGI::Scrubbed;

BEGIN {
    use_ok 'Socialtext::Rest::Changes';
}

User_names_are_set_correctly: {
    local @Socialtext::Rest::HUB_ARGS = (
        recent_changes => fake_recent_changes->new,
    );
    my $query = Socialtext::CGI::Scrubbed->new;
    my $rest = Socialtext::Rest->new(undef, $query);
    my $a = Socialtext::Rest::Changes->new($rest);
    my @entries =  $a->_hashes_for_query;

    is $entries[0]{username}, 'monkey@example.com', "username";
    is $entries[0]{best_full_name}, "Best FullName", "Best fullname exists";
    is $entries[0]{user_id}, 1, "User id is set";
    is $entries[1]{username}, 'foo@example.com', "username";
    is $entries[1]{best_full_name}, "Best FullName", "Best fullname exists";
    is $entries[1]{user_id}, 1, "User id is set";
}

exit;

package fake_recent_changes;
use strict;
use warnings;
use base 'Socialtext::MockBase';

sub default_result_set {
    return {
        rows => [
            {
                page_id => 'page1',
                Summary => 'blah',
                username => 'foo@example.com',
                Date => '1',
            },
            {
                page_id => 'page2',
                Summary => 'blagh',
                username => 'monkey@example.com',
                Date => '3',
            },
            {
                page_id => 'page3',
                Summary => 'bleagh',
                username => 'bad@example.com',
                Date => '2',
            },
        ],
    };
}


