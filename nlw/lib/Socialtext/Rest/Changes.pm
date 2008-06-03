package Socialtext::Rest::Changes;
# @COPYRIGHT@

use warnings;
use strict;

use base 'Socialtext::Rest::Collection';

use Socialtext::HTTP ':codes';
use Socialtext::Workspace;
use Class::Field 'field';

field ws => '';

sub allowed_methods {'GET, HEAD'}
sub collection_name { "Changes" }
sub permission { +{} }

sub _get_user_bfn_and_id {
    my ($self, $username, $ws) = @_;
    my $user = Socialtext::User->new(username => $username);
    my $bfn = $user->best_full_name(workspace => $ws);
    return ($bfn, $user->user_id);
}
# TODO: memoize the above if too slow, reset _bfn_cache on each call to
# _entities_for_query()
#   use Memoize;
#   my $_bfn_cache = {};
#   memoize '_get_user_bfn_and_id',
#       LIST_CACHE => ['HASH', $_bfn_cache],
#       NORMALIZER => '_bfn_normalizer';
#   sub _bfn_normalizer { $_[1]."\000".$_[2]->name }

sub _entities_for_query {
    my ($self, $rest) = @_;

    my @changes;

    my $count = $self->rest->query->param('count') || 20;

    for my $ws ($self->rest->user->workspaces->all) {
        $self->ws($ws->name);
        $self->hub->current_workspace($ws);
        
        my $res = $self->hub->recent_changes->default_result_set;
        # for each result that is returned get a summary of it
        foreach my $row (@{$res->{rows}}) {
            my $page = $self->hub->pages->new_page($row->{page_id});
            my $summary = $page->preview_text();
            $row->{Summary} = $summary;
            ($row->{best_full_name}, $row->{user_id}) = 
                $self->_get_user_bfn_and_id($row->{username}, $ws);
        }

        push @changes, grep { $_->{workspace} = $ws->name } @{$res->{rows}};
    }

    @changes = sort { $b->{Date} cmp $a->{Date} } @changes;

    return grep { $_ } @changes[0 .. $count-1];
}

sub _entity_hash {
    my ($self, $change) = @_;
    return {
        name => $change->{page_id},
        uri => "/data/changes/$change->{workspace}/$change->{page_id}",
        %$change,
    };
}

1;
