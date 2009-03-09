# @COPYRIGHT@
package Socialtext::ChangeEvent;

use strict;
use warnings;

use Data::UUID;
use Socialtext::ChangeEvent::Attachment;
use Socialtext::ChangeEvent::Page;
use Socialtext::ChangeEvent::IndexAttachment;
use Socialtext::ChangeEvent::IndexPage;
use Socialtext::ChangeEvent::RampupIndexPage;
use Socialtext::ChangeEvent::RampupIndexAttachment;
use Socialtext::ChangeEvent::Workspace;
use Socialtext::File;
use Socialtext::Log 'st_log';
use Socialtext::Paths;

=head1 NAME

Socialtext::ChangeEvent - Encapsulate a change in the NLW system to notify other systems

=head1 SYNOPSIS

    Socialtext::ChangeEvent->Record( $object );

=head1 DESCRIPTION

Socialtext::ChangeEvent works with the L<ceqlotron>. When a page, workspace,
or attachment is updated in L<NLW> a ChangeEvent is recorded so the
ceqlotron may, at its discretion, act upon the change. It may, for example,
choose to cause the entity to be indexed, or email notifications
to be sent.

=head1 IMPLEMENTATION

In this implementation a ChangeEvent is recorded by making a symlink in a
known directory to the filesystem representation of the entity in question.
It is a known issue that this implementation will not live forever in the
face of changes in the system, but we'll cross that bridge when it is
built.

=head1 CONSTRUCTOR

=head2 Socialtext::ChangeEvent->new( $path_to_symlink );

Returns an instance of
L<Socialtext::ChangeEvent::Workspace>,
L<Socialtext::ChangeEvent::Page>, 
L<Socialtext::ChangeEvent::Attachment>,
L<Socialtext::ChangeEvent::IndexPage>, or
L<Socialtext::ChangeEvent::IndexAttachment>, or
L<Socialtext::ChangeEvent::RampupIndexAttachment>, or
L<Socialtext::ChangeEvent::RampupIndexPage>,
depending on what the path is a symlink to.

=cut

# XXX refactor path comparison logic to Socialtext::Paths or Socialtext::Page
sub new {
    my ( $class, $path ) = @_;
    my $data_dir = Socialtext::AppConfig->data_root_dir;

    my $target = readlink $path or die "readlink '$path': $!";

    return Socialtext::ChangeEvent::RampupIndexPage->new($target, $path)
        || Socialtext::ChangeEvent::RampupIndexAttachment->new($target, $path)
        || Socialtext::ChangeEvent::IndexPage->new($target, $path)
        || Socialtext::ChangeEvent::Page->new($target, $path)
        || Socialtext::ChangeEvent::IndexAttachment->new($target, $path)
        || Socialtext::ChangeEvent::Attachment->new($target, $path)
        || Socialtext::ChangeEvent::Workspace->new($target, $path)
        || die "cequnklink $path $target";
}

=head1 CLASS METHOD

=head2 Socialtext::ChangeEvent->Record( $object )

Record that the provided object has changed. If there is a failure
an exception will be thrown. Possible failure scenarios are:

=over 4

=item System errors

Filesystem failure or other inability to record the change.

=item Unsupported object

At this time only workspace (L<Socialtext::Workspace>), page (L<Socialtext::Page>)
and attachment (L<Socialtext::Attachment>) objects are accepted. Others will
be rejected.

=back

=cut

# REVIEW: Should this be named create instead of Record, in keeping with
# Socialtext::{Account,Workspace,User}?  See
#
#   http://lists.socialtext.net/private/dev/2006-June/005774.html
# 
# but also note that the semantics of Record are a little different in that
# it's not really returning the same kind of thing you usually get from the
# constructor.
#
# Also, if we do rename, should create() be called Create() due to its
# class-ness?
#
#   https://www.socialtext.net/dev-guide/index.cgi?coding_standard#naming
sub Record {
    my $class = shift;
    $class = ref($class) || $class;
    my $self = bless {}, $class;
    my $object = shift;
    defined($object) or die "one single argument is required";

    Socialtext::File::ensure_directory(Socialtext::Paths::change_event_queue_dir);
    $self->_record_object($object);

    return $self;
}

# REVIEW: Rather than dispatching here we should use a 
# language that cares about types. Or subclass. Or
# something. Going for the quick and dirty right now
# with room for later refactoring.
sub _record_object {
    my $self = shift;
    my $object = shift;

    # where's my case statement?
    # REVIEW: The arguments to _link_to suggest an interface that
    # all these object should support, perhaps path()?
    if ($object->isa('Socialtext::Page')) {
        $self->_log_page_action($object);
        $self->_link_to($object->file_path);
    }
    elsif ($object->isa('Socialtext::Attachment')) {
        $self->_link_to($object->full_path);
    }
    elsif ($object->isa('Socialtext::Workspace')) {
        $self->_link_to(Socialtext::Paths::page_data_directory($object->name));
    }
    else {
        die "unsupported object type ", ref($object);
    }
}

sub _log_page_action {
    my $self   = shift;
    my $object = shift;

    my $action = $object->hub->action || '';
    return if $object->hub->rest->query->param('clobber')
        || $action eq 'submit_comment';

    if ( $action eq 'edit_content' ||
         $action eq 'rename_page' ) {
         return unless $object->restored || $object->revision_count == 1;
    }

    my $log_action = ($action eq 'delete_page') ? 'DELETE' : 'CREATE';
    $log_action = 'ATTACHMENTS_UPLOAD' if $action eq 'attachments_upload';

    my $ws     = $object->hub->current_workspace;
    my $user   = $object->hub->current_user;
    my $page   = $object->hub->pages->current;

    st_log()->info("$log_action,PAGE,"
                   . 'workspace:' . $ws->name . '(' . $ws->workspace_id . '),'
                   . 'page:' . $page->id . ','
                   . 'user:' . $user->username . '(' . $user->user_id . '),'
                   . '[NA]'
    );
}

# symlink the provided path
sub _link_to {
    my $self   = shift;
    my $path   = shift;
    my $prefix = shift;
    my $uuid = $self->_get_UUID();
    my $file_name = ($prefix) ? $prefix . $uuid : $uuid;
    
    my $directory = Socialtext::Paths::change_event_queue_dir();
    my $link_name = Socialtext::File::catfile($directory, $file_name);

    symlink( $path, $link_name ) or die "unable to symlink $link_name to $path: $!";
}

sub _get_UUID {
    return Data::UUID->new->create_str();
}

1;

=head1 SEE ALSO

L<ceqlotron>,
L<Socialtext::Ceqlotron>,
L<Socialtext::ChangeEvent::Workspace>,
L<Socialtext::ChangeEvent::Page>,
L<Socialtext::ChangeEvent::Attachment>,
L<Socialtext::Page>,
L<Socialtext::Attachment>,
L<Socialtext::Workspace>.

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

