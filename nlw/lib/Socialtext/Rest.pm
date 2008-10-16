package Socialtext::Rest;
# @COPYRIGHT@

use warnings;
use strict;

# A base class in which to group code common to all 'Socialtext::Rest::*'
# classes.

use Class::Field 'field';
use DateTime;
use DateTime::Format::HTTP;
use Carp 'croak';

use Socialtext::Exceptions;
use Socialtext::Workspace;
use Socialtext::HTTP ':codes';
use Socialtext::Log 'st_log';
use Socialtext::URI;

our $AUTOLOAD;

field 'hub',  -init => '$self->main->hub';
field 'main', -init => '$self->_new_main';
field 'page', -init => '$self->hub->pages->new_from_uri($self->pname)';
field 'workspace';
field 'params' => {};
field 'rest';

sub new {
    my $class = shift;
    my $new_object = bless {}, $class;
    $new_object->_initialize(@_);
    return $new_object;
}

sub error {
    my ( $self, $code, $msg, $body ) = @_;
    $self->rest->header(
        -status => "$code $msg",
        -type   => 'text/plain',
    );
    return $body;
}

sub bad_method {
    my ( $self, $rest ) = @_;
    my $allowed = $self->allowed_methods;
    $rest->header(
        -allow  => $allowed,
        -status => HTTP_405_Method_Not_Allowed,
        -type   => 'text/plain' );
    return HTTP_405_Method_Not_Allowed . "\n\nOnly $allowed are supported.\n";
}

=head2 bad_type

The request sent a content-type that's not useful for the current URI.

=cut
# REVIEW: Ideally this would wire back to the uri_map to tell us
# what types are acceptable.
sub bad_type {
    my ( $self, $rest ) = @_;
    $rest->header(
        -status => HTTP_415_Unsupported_Media_Type,
    );
    return '';
}

sub redirect_workspaces {
    my ( $self, $rest ) = @_;
    $rest->header(
        -status => HTTP_302_Found,
       -Location => $self->rest->query->url(-base => 1) . '/data/workspaces',
    );
    return '';
}

sub _initialize {
    my ( $self, $rest, $params ) = @_;

    $self->rest($rest);
    $self->params($params) if ($params);
    $self->workspace($self->_new_workspace);
}

sub _new_workspace {
    my $self = shift;

    my $workspace;
    if ($self->params->{ws}) {
        $workspace = Socialtext::Workspace->new(name => $self->ws);
    }
    else {
        $workspace = Socialtext::NoWorkspace->new();
    }

    $self->_check_on_behalf_of($workspace);

    return $workspace;
}

sub _check_on_behalf_of {
    my $self      = shift;
    my $workspace = shift;

    # in some cases our rest object is going to be bogus
    # because we are being called internally, or by tests
    return unless $self->rest->can('request');

    my $current_user = $self->rest->user;

    my $behalf_header    = $self->rest->request->header_in('X-On-Behalf-Of');
    my $behalf_parameter = $self->rest->query->param('on-behalf-of');
    my $behalf_user = $behalf_parameter
        || $behalf_header
        || undef;
    return unless $behalf_user;

    # if we are in a non-real workspace, error out
    unless ($workspace->real()) {
        st_log->info(
            $current_user->username, 'tried to impersonate',
            $behalf_user,                'without workspace'
        );
        Socialtext::Exception::Auth->throw(
            'on behalf not valid without workspace');
    }

    my $checker      = Socialtext::Authz::SimpleChecker->new(
        user      => $current_user,
        workspace => $workspace,
    );

    if ($checker->check_permission('impersonate')) {
        my $new_user = Socialtext::User->new(username => $behalf_user);
        if ($new_user) {
            $self->rest->{_user} = $new_user;
            $self->rest->request->connection->user($new_user->username);

            # clear the paramters in case there is a subrequest
            $self->rest->query->param('on-behalf-of', '');
            $self->rest->request->header_in('X-On-Behalf-Of', '');
            st_log->info(
                $current_user->username, 'impersonated as',
                $behalf_user
            );
        }
        else {
            st_log->info(
                $current_user->username,
                'failed to impersonate invalid user', $behalf_user
            );
            Socialtext::Exception::Auth->throw($behalf_user . ' invalid');

        }
    }
    else {
        st_log->info(
            $current_user->username, 'attempted to impersonate',
            $behalf_user,            'without impersonate permission'
        );
        Socialtext::Exception::Auth->throw(
            $current_user->username . ' may not impersonate');
    }
}

sub _new_main {
    my $self = shift;
    my $main = Socialtext->new;

    $main->load_hub(
        current_user      => $self->rest->user,
        current_workspace => $self->workspace,
    );
    $main->hub->registry->load;
    $main->debug;

    return $main;
}

=head2 make_http_date

Given an epoch time, returns a properly formatted RFC 1123 date
string.

=cut
sub make_http_date {
    my $self = shift;
    my $epoch = shift;
    my $dt = DateTime->from_epoch( epoch => $epoch );
    return DateTime::Format::HTTP->format_datetime($dt);
}

=head2 make_date_time_date

Given an HTTP (rfc 1123) date, return a DateTime object.

=cut
sub make_date_time_date {
    my $self = shift;
    my $timestring = shift;
    return DateTime::Format::HTTP->parse_datetime($timestring);
}

=head2 user_can($permission_name)

C<$permission_name> can either be the name of a L<Socialtext::Permission> or
the name of a L<Socialtext::User> method.  If C<$permission_name> begins with
C<is_>, then it is assumed to be the latter.  E.g, C<is_business_admin>.

=cut
sub user_can {
    my $self = shift;
    my $permission_name = shift;
    return $permission_name =~ /^is_/
        ? $self->rest->user->$permission_name
        : $self->hub->checker->check_permission($permission_name);
}

=head2 if_authorized($http_method, $perl_method, @args)

Checks the hash returned by C<< $self->permission >> to see if the user is
authorized to perform C<< $http_method >> using C<< $self->user_can >>. If so,
executes C<< $self->$perl_method(@args) >>, and if not returns
C<< $self->not_authorized >>.

The default implementation of C<permission> requires C<read> for C<GET> and
C<edit> for C<PUT>, C<POST>, and C<DELETE>.

=cut
sub if_authorized {
    my ( $self, $method, $perl_method, @args ) = @_;
    my $perm_name = $self->permission->{$method};

    return !$perm_name
        ? $self->$perl_method(@args)
        : $perm_name !~ /^is/ && !(defined $self->workspace and $self->workspace->real)
            ? $self->no_workspace
            : ( !$perm_name ) || $self->user_can($perm_name)
                ? $self->$perl_method(@args)
                : $self->not_authorized;
}

sub permission {
    +{ GET => 'read', PUT => 'edit', POST => 'edit', DELETE => 'delete' };
}

=head2 not_authorized()

Tells the client the current user is not authorized for the
requested method on the resource.

=cut
sub not_authorized {
    my $self = shift;

    if ($self->rest->user->is_guest) {
        $self->rest->header(
            -status => HTTP_401_Unauthorized,
            -WWW_Authenticate => 'Basic realm="Socialtext"',
        )
    }
    else {
        $self->rest->header(
            -status => HTTP_403_Forbidden,
            -type   => 'text/plain',
        );
    }
    return 'User not authorized';
}

=head2 _user_is_business_admin_p()

_Protected_

Yet another way to check for a role, though this one works a bit better for checking
if the current user is a business admin.

=cut
sub _user_is_business_admin_p {
    my $self = shift;
    return $self->user_can( 'is_business_admin' );
}

=head2 no_workspace()

Informs the client that we can't operate because no valid workspace
was created from the provided URI.

=cut
sub no_workspace {
    my $self = shift;
    my $ws = shift || $self->ws;
    $self->rest->header(
        -status => HTTP_404_Not_Found,
        -type   => 'text/plain',
    );
    return $ws . ' not found';
}

# REVIEW: making use of CGI.pm here
sub full_url {
    my $self = shift;

    my $path = $self->rest->query->url( -absolute => 1, -path_info => 1 );
    $path = join('', $path, @_);
    my $uri = Socialtext::URI::uri( path => $path );
    return $uri;
}

# Automatic getters for query parameters.
sub AUTOLOAD {
    my $self = shift;
    my $type = ref $self or die "$self is not an object.\n";

    $AUTOLOAD =~ s/.*://;
    return if $AUTOLOAD eq 'DESTROY';

    if (exists $self->params->{$AUTOLOAD}) {
        croak("Cannot set the value of '$AUTOLOAD'") if @_;
        return $self->params->{$AUTOLOAD};
    }
    croak("No such method '$AUTOLOAD' for type '$type'.");
}


1;
