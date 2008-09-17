package Socialtext::WorkspaceListPlugin;
# @COPYRIGHT@
use strict;
use warnings;
use Class::Field qw(const);
use Socialtext::l10n qw(loc);
use Socialtext::Workspace;

use base 'Socialtext::Plugin';

const class_id    => 'workspace_list';
const class_title => loc('Workspace List');

sub WORKSPACE_LIST_SIZE { 10 }

sub register {
    my $self     = shift;
    my $registry = shift;
    $registry->add(action => 'workspace_list');
}

sub workspace_list {
    my $self = shift;
    return $self->template_render(
        template => 'view/workspace_list',
        vars     => {
            $self->hub->helpers->global_template_vars,
            action            => 'workspace_list',
            my_workspaces     => [ $self->my_workspaces ],
            public_workspaces => [ $self->public_workspaces ],
        },
    );
}

sub my_workspaces {
    my $self = shift;

    # get the list of workspaces that the logged in user is a member of
    my $user = $self->hub->current_user();
    my @workspaces;
    my $it = $user->workspaces();
    while (my $ws = $it->next) {
        push @workspaces, [ $ws->name, $ws->title ];
    }

    return @workspaces;
}

sub public_workspaces {
    my $self = shift;

    # get the list of public workspaces:
    # - "help"
    # - "hand-picked list of ws by admin" (TODO)
    # - "most often accessed public workspaces last week"
    my $ws_help   = Socialtext::Workspace->help_workspace();
    my @available = (
        [ $ws_help->name, $ws_help->title ],
        Socialtext::Workspace->MostOftenAccessedLastWeek(),
    );

    # trim list to max length, and remove duplicates
    my %seen;
    my @workspaces;
    while (@available) {
        my $ws = shift @available;
        next if ($seen{ $ws->[0] }++);
        push @workspaces, $ws;
        last if (scalar(@workspaces) == WORKSPACE_LIST_SIZE);
    }

    return @workspaces;
}

1;
