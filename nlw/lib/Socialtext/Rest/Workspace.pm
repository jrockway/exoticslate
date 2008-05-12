package Socialtext::Rest::Workspace;
# @COPYRIGHT@

use strict;
use warnings;

use base 'Socialtext::Rest::Entity';
use Socialtext::HTTP ':codes';
use Socialtext::JSON;

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

sub PUT {
    my( $self, $rest ) = @_;

    my $is_admin = $self->hub->checker->check_permission('admin_workspace');
    unless ($is_admin or $self->_user_is_business_admin_p( ) ) {
        $rest->header(
                      -status => HTTP_401_Unauthorized,
                     );
        return '';
    }

    my $workspace = $self->workspace;
    my $update_request_hash = decode_json( $rest->getContent() );

    my $uri = $update_request_hash->{customjs_uri};
    if (defined $uri) {
        $workspace->update(customjs_uri => $uri);
    }

    $rest->header( -status => HTTP_204_No_Content );
    return '';
}

sub DELETE {
    my ( $self, $rest ) = @_;

    unless ($self->_can_delete_workspace()) {
        $rest->header(
            -status => HTTP_403_Forbidden,
        );
        # Be ambivalent about why deletion not allowed.
        return $self->ws . ' cannot be deleted.';
    }

    if ( $self->workspace ) {
        Socialtext::Search::AbstractFactory->GetFactory->create_indexer(
            $self->workspace->name )
            ->delete_workspace( $self->workspace->name );
        $self->workspace->delete;
        $rest->header(
            -status => HTTP_204_No_Content,
        );
        return $self->ws . ' removed';
    }
    else {
        return $self->http_404($rest);
    }
}

# REVIEW: this is starting to look like an idiom.
# Might already exist somewhere in the code.
sub _can_delete_workspace {
    my $self = shift;

    my $user = $self->rest->user;
    return $user->is_business_admin()
        || $user->is_technical_admin()
        || ( $self->workspace
        && $self->hub->checker->check_permission('admin_workspace') );
}

sub validate_resource_id {
    my( $self, $rest, $errors ) = @_;

    return Socialtext::Workspace->NameIsValid(
        name    => $self->ws,
        errors  => $errors
    );
}


1;
