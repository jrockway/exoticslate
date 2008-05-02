# @COPYRIGHT@
package Socialtext::SOAPServer;

use strict;
use warnings;
use SOAP::Transport::HTTP;
use Socialtext::Log 'st_log';

use base 'Socialtext::Rest';

our $VERSION = '0.09';

# XXX: Fix a bug in SOAP::Lite which breaks .NET clients.
#
# The subroutine below was yanked from the SOAP::Lite sources and modified so
# it would work.  Sometime after 0.67 the way namespaces are handled changed
# in a way that busts some .NET clients.  The below hack is only a stop-gap.
# A better solution is that later versions of SOAP::Lite work with .NET.
if (SOAP::Lite->VERSION > 0.67) {
    no warnings 'redefine';
    undef &SOAP::Serializer::ns;
    *SOAP::Serializer::ns = sub {
        my $self = shift->new;
        if (@_) {
            my ($u,$p) = @_;
            my $prefix;
            if ($p) {
                $prefix = $p;
            } elsif (!$p && !($prefix = $self->find_prefix($u))) {
                $prefix = SOAP::Serializer::gen_ns;
            }
            $self->{'_ns_uri'}         = $u;
            $self->{'_ns_prefix'}      = $prefix;
            $self->{'_use_default_ns'} = 0;
            return $self;
        }
        return $self->{'_ns_uri'};
    };
}

=head1 NAME

Socialtext::SOAPServer - A framework for presenting Socialtext methods over SOAP

C<Socialtext::SOAPServer> adds a CGI-like-hybrid that
provides SOAP-based access to a small number of methods contained
in an inner class L<NLWSOAP>. An inner class is used to operate with
the way L<SOAP::Lite> handles dispatch and namespacing.

Errors in the inner class are returned as soap faults to the client.  In some
cases extra details are returned in the details section of the SOAP fault.

At the time of this writing, this code requires a change to L<SOAP::Lite>
to work correctly with .NET and Java jwsdp-1.6.

A WSDL file for this file is represented at /static/wsdl/0.9.wsdl, subject
to change.

Authentication is not currently supported. This is a prototype. Before
the code is released to customers authentication must be supported.
Expect a C<getAuth()> method in the future.

=cut

# don't want to die on 'Broken pipe' or Ctrl-C
$SIG{PIPE} = 'IGNORE';


sub POST {
    my $self = shift;
    my $rest = shift;

    my $server = SOAP::Transport::HTTP::Posted->new;
    $server->dispatch_to( 'NLWSOAP');
    $server->serializer->ns('');

    $server->request($rest->query);

    my $soap_response = $server->handle(@_);

    $rest->header(
        -status => $soap_response->code,
        -type   => 'text/xml; charset=utf-8',
    );
    return $soap_response->content;
}

package NLWSOAP;

use CGI::Cookie; # avoid dependency on apache for later extraction
use SOAP::Lite;
use URI::Escape qw(uri_unescape);

use Readonly;

use Socialtext;
use Socialtext::Authen;
use Socialtext::Log 'st_log';
use Socialtext::Role;
use Socialtext::Workspace;
use Socialtext::User;
use Socialtext::Validate qw ( validate SCALAR_TYPE );
use Socialtext::HTTP::Cookie qw(USER_DATA_COOKIE);

Readonly my $URN => 'urn:NLWSOAP';

=head1 REMOTE METHODS

=head2 heartBeat()

Returns a string representation of the current time on the server. 
This is provided as a test method.

=cut
sub heartBeat {
    return SOAP::Data->name('heartBeatReturn')->value(scalar localtime(time));
}

=head2 getAuth($username, $password, $workspace [,$act_as])

Request an auth token. The token returned is in the form of an HTTP
cookie, for convenience with other aspects of the auth code. The client
system is expected to hang on to the token.

C<$act_as> is an optional username (in the form of an email address,
for now). When provided, the returned auth token causes methods with
which it is used to be performed on the server as the user in $act_as.

=cut
sub getAuth {
    my $class = shift;
    my ( $username, $password, $workspace_name, $act_as ) = @_;
    
    _raise_client_fault("Required parameters: username, password, workspace")
        unless $username and $password and $workspace_name;

    my $auth   = Socialtext::Authen->new();
    my $user   = Socialtext::User->new( username => $username )
        or _raise_client_fault("Invalid user: $username");
    my $workspace = Socialtext::Workspace->new( name => $workspace_name )
        or _raise_client_fault("Invalid workspace name: $workspace_name");

    my $pass_ok = $auth->check_password(
        username => $username,
        password => $password
    );

    _raise_client_fault("Access denied for $username", {permission => 'read'})
        unless $pass_ok and _has_permission( $user, $workspace, 'read' );

    # REVIEW: trim off the path info?
    my $cookie_string = _get_cookie( $user->user_id )->as_string;
    $cookie_string =~ s/;.*$//;
    $cookie_string .= '&workspace_id&' . $workspace->workspace_id;

    if ($act_as) {
        if (_is_super_admin( $user, $workspace )) {
            $cookie_string .= '&act_as&' . $act_as;
        }
        else {
            _raise_client_fault(
                "Impersonate denied: $username act as $act_as",
                { permission => 'impersonate' } );
        }
    }

    return SOAP::Data->name('token')->value($cookie_string);
}

=head2 getChanges($key, $category, $count)

Retrieves a list of $count pageMetadata objects representing a
chronologically ordered list of recently changed pages in
$category. $category defaults to 'recent changes'. $count
defaults to 10.  

A pageMetadata object has the following fields:

=over 4

=item subject

The subject, or title, of a page, utf-8 encoded.

=item page_uri

The URI, or external identifier, of the a page.

=item date

The last modified date of a page, currently a string. In the future
a date.

=item author

The username of the author that most recently changed the page.

=item revisions 

And integer representing the total number of revisions this page
has seen.

=back

=cut
sub getChanges {
    my $class = shift;
    my ($key, $category, $count) = @_;
    $category ||= 'recent changes';
    $count    ||= 10;

    _raise_client_fault("Required parameter: key")
                unless $key;
    my $session = _authenticate($key);
    my $hub = _make_hub( $session->{workspace_id}, $session->{actor},
        $session->{act_as} );

    _log('getChanges', $hub, $category, $count);

    my $changes = $hub->recent_changes->get_recent_changes_in_category(
        count    => $count,
        category => lc ($category),
    );

    return
        SOAP::Data->name('changesList')
                  ->type('nlwsoap:ArrayOf_pageMetadata')
                  ->attr({'xmlns:nlwsoap' => $URN})
                  ->value([map {_pageMetadata($_)} @{$changes->{rows}}])
                  ->prefix('');
}

=head2 getSearch($key, $user, $workspace, $query)

Performs a search in worksapce $workspace for $query. Returns
a list of C<pageMetadata>, described in C<getChanges>.

=cut
sub getSearch {
    my $class = shift;
    # REVIEW: do we need to worry about utf8 stuff on $query
    my ($key, $query) = @_;

    _raise_client_fault("Required parameters: key, query")
                unless $key and defined $query;
    my $session = _authenticate($key);
    my $hub = _make_hub( $session->{workspace_id}, $session->{actor},
        $session->{act_as} );

    _log('search', $hub, $query);

    my $results = $hub->search->get_result_set(search_term => $query);

    return 
        SOAP::Data->name('searchList')
                  ->type('nlwsoap:ArrayOf_pageMetadata')
                  ->attr({'xmlns:nlwsoap' => $URN})
                  ->value([map {_pageMetadata($_)} @{$results->{rows}}])
                  ->prefix('');
}

=head2 getPage($key, $page_name, $format)

Retrieve $page_name from $workspace in the format specified
by $format. This can be 'wikitext' or 'html'. Other formats will
be available in the future.

If 'html' has '/<word>' appended, the system will attempt to format
the output with a <word>LinkDictionary. This is experimental for
now and is subject to change.

Returns a pageFull object which has the following fields

=over 4

=item subject

The subject or title of the page as a utf-8 encoded String.

=item page_uri

The external identifier of the page, as a String.

=item pageContent

The content of the page, as a utf-8 encoded String.

=item date

The last modified date of a page, currently a string. In the future
a date.

=item author

The username of the author that most recently changed the page.

=item revisions 

And integer representing the total number of revisions this page
has seen.

=back

=cut
# XXX should reuse metadata portion of recent change
# maybe consider a pagemeta complex type
sub getPage {
    my $class = shift;
    my ($key, $page_name, $format) = @_;

    _raise_client_fault("Required parameters: key, page_name, format")
              unless $key and defined $page_name;
    my $session = _authenticate($key);
    my $hub = _make_hub( $session->{workspace_id}, $session->{actor},
        $session->{act_as} );

    _log('getPage', $hub, $page_name, $format);

    return _getPage($hub, $page_name, $format);
}

=head2 setPage($key, $page_name, $content)

Create or update the content of the page named $page_name in workspace
$workspace. Provided content should be in wikitext format.

Returns a pageFull object which has the fields described in C<getPage>.

=cut
sub setPage {
    my $class = shift;
    my ($key, $page_name, $content) = @_;
    _raise_client_fault("Required parameters: key, page_name, content")
                unless $key and $page_name and $content;

    my $session = _authenticate($key);
    my $hub = _make_hub( $session->{workspace_id}, $session->{actor},
        $session->{act_as} );

    _log('setPage', $hub, $page_name);

    _setPage($hub, $page_name, $content);
    return _getPage($hub, $page_name, 'wikitext');
}

sub _log {
    my ($method, $hub, @args) = @_;

    st_log->notice(
        join(
            ', ', "SOAP::$method", $hub->current_user->username,
            $hub->current_workspace->name, @args
        )
    );
}

sub _setPage {
    my ($hub, $page_name, $content) = @_;

    # create the page object. 
    my $page;
    eval {
        $page = $hub->pages->new_from_uri($page_name);
    };

    _raise_client_fault("Invalid page id: $page_name") if $@;

    # REVIEW: mml doesn't find the thing that might cause a die() here.  Help?
    #
    # This can die in some circumstances. We should not get contention
    # because we are not bothering to check.
    eval {
        $page->update_from_remote(
            content   => $content,
        );
    };
    # try to trim the noise of errors a bit
    if (UNIVERSAL::isa($@, 'Socialtext::Exception::Params')) {
        _raise_server_fault( "Invalid page parameters for $page_name", $@ );
    }
    _raise_server_fault( "Error updating $page_name", $@ ) if $@;
}

sub _getPage {
    my ($hub, $page_name, $format) = @_;

    $page_name ||= $hub->current_workspace->title();
    $format    ||= 'html';

    my $page = $hub->pages->new_from_name($page_name);
    my $content = _format_page($hub, $page, $format);
    my $subject = $page->metadata->Subject;

    return SOAP::Data->name('page' => \SOAP::Data->value(
            SOAP::Data->name( 'pageContent' => $content )->type('string')
                  ->prefix(''),
            SOAP::Data->name( 'subject' => $subject )->type('string')
                  ->prefix(''),
            SOAP::Data->name( 'page_uri' => uri_unescape($page->uri) )
                  ->type('string')
                  ->prefix(''),
            SOAP::Data->name( 'date'   => $page->metadata->Date )
                  ->type('string')
                  ->prefix(''),
            SOAP::Data->name( 'author' => $page->metadata->From )
                  ->type('string')
                  ->prefix(''),
            SOAP::Data->name( 'revisions' => $page->revision_count )
                  ->type('int')
                  ->prefix(''),
              ))
             ->prefix('');
}

sub _format_page {
    my $hub    = shift;
    my $page   = shift;
    my $format = shift;

    my $content;
    if ( $format eq 'wikitext' ) {
        $content = $page->content;
    }
    elsif ( $format eq 'html' ) {
        $content = $page->to_absolute_html;
    }
    elsif ( $format =~ m{\Ahtml/(\w+)\z} ) {
        my $link_dictionary_name
            = 'Socialtext::Formatter::' . $1 . 'LinkDictionary';
        my $link_dictionary;
        # REVIEW: This seems less than ideal
        eval {
            eval "require $link_dictionary_name";
            $link_dictionary = $link_dictionary_name->new();
        };

        # Throw a server error and give a stack trace in the details.
        if ($@) {
            _raise_server_fault( "Unable to create link dictionary.", $@ );
        }

        my $url_prefix = $hub->current_workspace->uri;
        $url_prefix =~ s{/[^/]+/?$}{};
        $hub->viewer->url_prefix($url_prefix);

        $hub->viewer->link_dictionary($link_dictionary);
        $content = $page->to_html();
    }
    else {
        _raise_client_fault("Unknown format: $format.");
    }

    return $content;
}

# REVIEW: The auth stuff really confuses
sub _make_hub {
    my $workspace_id   = shift;
    my $actor          = shift;
    my $act_as_name    = shift;
    my $permission     = shift || 'read';

    my $socialtext = Socialtext->new();
    my $workspace
        = Socialtext::Workspace->new( workspace_id => $workspace_id );
    _raise_client_fault("Unable to create workspace $workspace_id.")
        unless $workspace;

    # If the $actor is an admin in this workspace and there is
    # an act_as_name, create the hub with a user representing act_as_name,
    # otherwise use $actor.
    my $user = $actor;

    if ( $act_as_name && _is_super_admin($actor, $workspace) ) {
        $user = Socialtext::User->new( username => $act_as_name );
        $user ||= Socialtext::User->create(
            username           => $act_as_name,
            email_address      => $act_as_name,
            created_by_user_id => $actor->user_id,
        );
        $workspace->add_user(
            user => $user,
            role => Socialtext::Role->Member(),
        );
    }

    _raise_client_fault("Unable to act as $act_as_name.") unless $user;

    eval {
        $socialtext->load_hub(
            current_user      => $user,
            current_workspace => $workspace,
        );
    };
    _raise_server_fault( "Couldn't create a HUB", $@ ) if $@;
    $socialtext->hub()->registry()->load();
    $socialtext->debug();

    my $checker = Socialtext::Authz::SimpleChecker->new(
        user       => $user,
        workspace  => $workspace,
    );

    return $socialtext->hub if $checker->check_permission($permission);

    _raise_client_fault(
        "Unauthorized access to $workspace_id as $act_as_name.");
}

sub _is_super_admin {
    my $user      = shift;
    my $workspace = shift;

    my $checker = Socialtext::Authz::SimpleChecker->new(
        user       => $user,
        workspace  => $workspace,
    );

    return $checker->check_permission('impersonate');
}

sub _pageMetadata {
    my $row = shift;
    my $subject = $row->{Subject};
    return SOAP::Data->name('pageMetadata' => \SOAP::Data->value(
                SOAP::Data->name( 'subject'   => $subject )->type('string')
                  ->prefix(''),
                SOAP::Data->name( 
                    'page_uri'  => uri_unescape($row->{page_uri}) )
                  ->type('string')
                  ->prefix(''),
                SOAP::Data->name( 'date'      => $row->{Date} )
                  ->type('string')
                  ->prefix(''),
                SOAP::Data->name( 'author'    => $row->{From} )
                  ->type('string')
                  ->prefix(''),
                SOAP::Data->name( 'revisions' => $row->{revision_count} )
                  ->type('int')
                  ->prefix(''),
              ))
              ->type('nlwsoap:pageMetadata')
              ->prefix('');
}

# XXX: This stuff, which is stolen from Socialtext::Apache::User
# should be somewhere that is not tied to Apache and not here
sub _get_cookie {
    my $id = shift;

    my $mac = Socialtext::HTTP::Cookie->MAC_for_user_id($id);

    my $cookie = CGI::Cookie->new(
        -name => USER_DATA_COOKIE,
        -value => {
            user_id => $id,
            MAC => $mac,
        },
    );

    return $cookie;
}

# XXX some dupe with Socialtext::Apache::User here
sub _authenticate {
    my $key = shift;

    my %cookies = CGI::Cookie->parse($key);
    my %user_data = $cookies{USER_DATA_COOKIE()}->value;
    my $mac = Socialtext::HTTP::Cookie->MAC_for_user_id( $user_data{user_id} );
    unless ( $mac eq $user_data{MAC} ) {
        _raise_client_fault(
            "Invalid MAC Secret for $user_data{user_id}: $user_data{MAC}");
    }

    my $user = Socialtext::User->new( user_id => $user_data{user_id} );

    return +{
        actor => $user,
        workspace_id => $user_data{workspace_id},
        act_as => $user_data{act_as},
    }
}

sub _has_permission {
    my $user            = shift;
    my $workspace       = shift;
    my $permission_name = shift;

    my $checker = Socialtext::Authz::SimpleChecker->new(
        user       => $user,
        workspace  => $workspace,
    );

    return $checker->check_permission($permission_name);
}

sub _raise_client_fault {
    my ( $string, $details ) = @_;
    return _raise_fault( 'Client', $string, $details );
}

sub _raise_server_fault {
    my ( $string, $details ) = @_;
    return _raise_fault( 'Server', $string, $details );
}

sub _raise_fault {
    my ( $code, $string, $details ) = @_;
    my $fault = SOAP::Fault->new(
        faultcode   => $code   || 'Server',
        faultstring => $string || "Unknown error",
        $details ? ( faultdetail => _make_detail($details) ) : ()
    );

    st_log->info( "Soap Fault: $fault" );
    die $fault;
}

sub _make_detail {
    my $detail = shift;
    if ( ref($detail) eq 'HASH' ) {
        return bless( $detail, 'Socialtext::Error' );
    }
    elsif ( ref $detail ) {
        return $detail;
    }
    else {
        return bless( { stacktrace => $detail }, 'Soscialtext::Error' );
    }
}

1;

=head1 TODO

C<getUserInfo> method would be useful.

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

package SOAP::Transport::HTTP::Posted;
use SOAP::Transport::HTTP;

# most use ISA because SOAP::Lite diddles with things weirdly.
use vars qw(@ISA);
@ISA = qw(SOAP::Transport::HTTP::Server);

sub handle {
    my $self = shift->new;

    my $length = $ENV{'CONTENT_LENGTH'} || 0;

    if ( !$length ) {
        $self->response( HTTP::Response->new(411) )    # LENGTH REQUIRED
    }
    elsif ( defined $SOAP::Constants::MAX_CONTENT_SIZE
        && $length > $SOAP::Constants::MAX_CONTENT_SIZE ) {
        $self->response( HTTP::Response->new(413) ) # REQUEST ENTITY TOO LARGE
    }
    else {
        my $content = $self->request->param('POSTDATA');
        $self->request(
            HTTP::Request->new(
                $ENV{'REQUEST_METHOD'} || '', # method
                $ENV{'SCRIPT_NAME'},          # uri
                HTTP::Headers->new(           # headers
                    map {
                        (     /^HTTP_(.+)/i
                            ? ( $1 =~ m/SOAPACTION/ )
                            ? ('SOAPAction')
                            : ($1)
                            : $_ ) => $ENV{$_}
                        } keys %ENV
                ),
                $content,                     # content
            )
        );
        $self->SUPER::handle;
    }

    return $self->response;
}
