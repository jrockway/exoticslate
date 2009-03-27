package Socialtext::Job;
use strict;
use warnings;
use Socialtext::User;

sub _make_hub {
    my $class = shift;
    my $ws = shift;

    require Socialtext;
    my $main = Socialtext->new();
    $main->load_hub(
        current_workspace => $ws,
        current_user      => Socialtext::User->SystemUser,
    );
    $main->hub()->registry()->load();

    return $main->hub;
}

sub _create_indexer {
    my $class = shift;
    my $wksp  = shift;
    my $search_type = shift || 'live';

    require Socialtext::Search::AbstractFactory;

    my $indexer
        = Socialtext::Search::AbstractFactory->GetFactory->create_indexer(
        $wksp->name,
        config_type => $search_type,
    );
    if ( !$indexer ) {
        $job->permanent_failure("Couldn't create a indexer");
        return;
    }
    return $indexer;
}

1;
