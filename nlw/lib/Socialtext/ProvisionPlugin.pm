# @COPYRIGHT@
package Socialtext::ProvisionPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use Class::Field qw( const );
use Template::Iterator::AlzaboWrapperCursor;
use Socialtext::User;
use YAML;

sub class_id {'provision_ui'}
const cgi_class => 'Socialtext::ProvisionPlugin::CGI';

sub register {
    my $self     = shift;
    my $registry = shift;

    # Web Service UI
    $registry->add( action => 'workspaces_create_full' );
}

sub _clone_current_workspace {
    my $self       = shift;
    my $parameters = shift;
    my $account_id = shift;
    my $ws;

    eval {
        my $current_ws = $self->hub->current_workspace;
        $ws = Socialtext::Workspace->create(
            name               => $parameters->name,
            title              => $parameters->title,
            created_by_user_id => $self->hub->current_user->user_id,

            # begin customization inheritances
            skin_name => $self->hub->current_workspace->skin_name,
            show_welcome_message_below_logo =>
                $current_ws->show_welcome_message_below_logo,
            show_title_below_logo => $current_ws->show_title_below_logo,
            header_logo_link_uri  => $current_ws->header_logo_link_uri,

            # end customization inheritances
            account_id => $account_id );

        $ws->set_logo_from_uri( uri => $parameters->logo_uri )
            if $parameters->logo_uri;

        # XXX - need to give child workspace its parents permissions
    };

    if ( my $e
        = Exception::Class->caught('Socialtext::Exception::DataValidation') )
    {
        $self->add_error($_) for $e->messages;
        return;
    }
    die $@ if $@;

    return $ws;
}

sub _validate_input {
    my $self   = shift;
    my $inputs = shift;
    my @missing_fields;

    # NOTE: we are only checking a couple of fields here, because
    # there is better data validation down lower in the libraries

    push @missing_fields, 'account_id' unless $inputs->account_name;
    push @missing_fields, 'user_email' unless $inputs->user_email;

    if ( @missing_fields > 0 ) {
        push @{ $self->errors },
            "Missing required fields: " . join( @missing_fields, ", " );
        die "data validation error";
    }
}

sub workspaces_create_full {
    my $self = shift;
    my $parameters;
    my $response;
    eval {
        my $parameters = $self->cgi;
        $self->_validate_input($parameters);
        $response = $self->_workspaces_create_full($parameters);
    };
    if ($@) {
        $response->{status}         = 'error';
        $response->{error_messages} = ($@);

        if ( grep( /workspace.*already in use/, @{ $self->errors } ) ) {
            $response->{error_code} = 'duplicate_workspace_error';
        }
        elsif ( grep( /Missing required fields/i, @{ $self->errors } ) ) {
            $response->{error_code} = 'data_validation_error';
        }
        else {
            $response->{error_code} = 'unknown_error';
        }

        #         if( @{$self->errors} ) {
        #             push @{$response->{error_messages}, @{$self->errors};
        #         }
    }

    $self->hub->headers->content_type('text/x-yaml; charset=utf-8');

    Dump($response);
}

sub _workspaces_create_full {
    my $self       = shift;
    my $parameters = shift;

    $self->hub->assert_current_user_is_admin;

    # set up for a response
    my $response = {
        status                         => 'ok',
        administrator_confirmation_uri => '', };

    my $account
        = Socialtext::Account->new( name => $parameters->account_name );
    $account
        ||= Socialtext::Account->create( name => $parameters->account_name );

    my $new_ws = $self->_clone_current_workspace(
        $parameters,
        $account->account_id() );

    die "clone current workspace failed" if ( @{ $self->errors } );

    my $user
        = Socialtext::User->new( email_address => $parameters->user_email );
    $user ||= Socialtext::User->create(
        username      => $parameters->user_email,
        email_address => $parameters->user_email,
        first_name    => $parameters->user_first_name,
        last_name     => $parameters->user_last_name, );

    $new_ws->add_user(
        user => $user,
        role => Socialtext::Role->WorkspaceAdmin(), );

    # make sure user gets confirmation message
    unless ( $user->has_valid_password() ) {
        $user->set_confirmation_info();
        $response->{administrator_confirmation_uri}
            = $user->confirmation_uri();
    }

    # XXX - I think this is being called just to make sure it exists (HACK)
    $self->user_plugin_directory( $user->email_address );

    $self->log_action(
        "INVITE_USER_FROM_CLONE_WORKSPACE",
        $user->email_address );

    return $response;
}

package Socialtext::ProvisionPlugin::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'Button';
cgi name     => '-clean';
cgi logo_uri => '-clean';
cgi title     => '-clean';
cgi 'workspace_id';
cgi 'user_email';
cgi 'user_first_name';
cgi 'user_last_name';
cgi 'account_id';
cgi 'account_name';

1;
