package Socialtext::Rest::WorkspaceAttachments;
# @COPYRIGHT@

use warnings;
use strict;

use base 'Socialtext::Rest::Attachments';

sub allowed_methods { 'GET, HEAD' }

sub _entities_for_query {
    my $self = shift;
    return $self->hub->attachments->all_attachments_in_workspace()
}

1;

