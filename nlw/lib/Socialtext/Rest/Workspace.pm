package Socialtext::Rest::Workspace;
# @COPYRIGHT@

use strict;
use warnings;

use base 'Socialtext::Rest::Entity';

sub permission      { +{ GET => 'read' } }
sub allowed_methods {'GET, HEAD'}
sub entity_name     { 'workspace ' . $_[0]->workspace->title }


# Generic method called by the other GET_* routines.
#
sub _GET_any {
    my( $self, $rest ) = @_;

    # Return any problems as an HTTP 400 error message.
    #
    my @errors;
    if ( ! $self->validate_resource_id( $rest, \@errors ) ) {
        return $self->http_400( $rest, join("\n", @errors) );
    }

    # Call the superclass method with the same name as the calling
    # subroutine.
    #
    # REVIEW: This feels too clever, but the SUPER:: call is the *only*
    # difference among the different GET_* methods.  DRY wins over
    # simpler-but-duplicated code, at least for now.
    #
    # (The GET_* methods could also be generated based on a template,
    # but that seems even worse.)
    #
    my $super_method = (caller 1)[3];   # - get fully-qualified name of calling sub
    $super_method =~ s/^.+::/SUPER::/;  # - replace package name with SUPER
    return $self->$super_method($rest); # - call the superclass method
}

sub GET_html { _GET_any(@_) }
sub GET_text { _GET_any(@_) }
sub GET_json { _GET_any(@_) }


sub get_resource {
    my( $self, $rest ) = @_;

    my $workspace = $self->workspace;
    my $is_admin
        = sub { $self->hub->checker->check_permission('admin_workspace') };
    my $peon_view
        = sub { name => $workspace->name, title => $workspace->title };
    my $extra_data
        = sub { pages_uri => $self->full_url('/pages') };

    return
          !$workspace ? undef
        : &$is_admin  ? { &$extra_data, %{$workspace->to_hash} }
                      : { &$extra_data, &$peon_view };
}


sub validate_resource_id {
    my( $self, $rest, $errors ) = @_;

    return Socialtext::Workspace->NameIsValid(
        name    => $self->ws,
        errors  => $errors
    );
}


1;
