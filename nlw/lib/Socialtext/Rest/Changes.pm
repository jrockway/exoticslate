package Socialtext::Rest::Changes;
# @COPYRIGHT@

use warnings;
use strict;

use base 'Socialtext::Rest::Collection';

use Socialtext::Pluggable::Adapter;
use Socialtext::HTTP ':codes';
use Socialtext::Workspace;
use Class::Field 'field';
use Socialtext::SQL qw/sql_execute/;

field ws => '';

sub allowed_methods {'GET, HEAD'}
sub collection_name { "Changes" }
sub permission { +{} }

sub _entities_for_query {
    my ($self, $rest) = @_;

    my $count = $self->rest->query->param('count') || 20;
    my $since = $self->rest->query->param('since');
    my $pages_ref = Socialtext::Model::Pages->By_seconds_limit(
        workspace_ids => [
            map { $_->workspace_id } $self->rest->user->workspaces->all
        ],
        # Default to 7 days
        $since ? (since => $since) : (seconds => 7 * 1440 * 60),
        count => $count,
    );

    my @changes;
    my %bfn;
    for my $page (@$pages_ref) {
        my $row = $page->to_result();
        my $ws = new Socialtext::Workspace(name => $page->{workspace_name});
        my $user = Socialtext::User->new(user_id => $page->{last_editor_id});

        $row->{workspace} = $ws->name;
        $row->{uri} = "/data/workspaces/$row->{workspace}/pages/$row->{page_id}";
        $row->{user_id} = $user->user_id;
        $row->{best_full_name} = $user->guess_real_name();
        $row->{From} = Socialtext::User->MaskEmailAddress(
            $row->{From},
            $ws
        );
        $row->{hidden} = 1;
        if (Socialtext::Pluggable::Adapter->plugin_exists('people')) {
            require Socialtext::People::Profile;
            my $profile = Socialtext::People::Profile->GetProfile($user);
            $row->{hidden} = $profile->is_hidden if $profile;
        }

        push @changes, $row;
    }

    return @changes;
}

sub _entity_hash { $_[1] }

1;
