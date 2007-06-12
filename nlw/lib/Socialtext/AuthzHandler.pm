# @COPYRIGHT@
package Socialtext::AuthzHandler;
use strict;
use warnings;

use base 'Socialtext::Handler::Cool';
use Socialtext::Authz;
use Socialtext::Log 'st_log';
use Socialtext::Permission 'ST_READ_PERM';

use Apache::Constants qw( NOT_FOUND DECLINED SERVER_ERROR AUTH_REQUIRED OK);

sub workspace_uri_regex {
    my $base = quotemeta($ENV{ST_AUTHZ_URL_BASE} || "");
    return qr{$base/?([\w\-]+)/};
}

sub handler ($$) {
    my $class = shift;
    my $r     = shift;

    my $requires = $r->requires;
    my $user = $r->connection->user;
    my $filename = $r->filename;

    st_log->debug( "checking authorization for $user : $filename" );

    return DECLINED unless $requires;

    my $nlw   = $class->get_cool_nlw($r);

    if( ! $nlw ) {
        st_log->error( "can't get nlw for $user - $filename" );
        return NOT_FOUND;
    }
    my $explanation = <<END;
<html>
<title>Unauthorized</title>
<body>
<h1>You Are Not Authorized to Access This Page</h1>
Access to this page is limited to:
<ul>
END
    for my $entry (@$requires) {
        my $requirement = $entry->{requirement};
        st_log->debug("checking $requirement for $user - $filename");
        if ( lc $requirement eq 'valid-user' ) {

            # go ahead and return ok because authentication should have
            # handled this for us
            return OK;
        }
        elsif ( lc $requirement eq 'valid-workspace-membership' ) {
            st_log->debug("$requirement for $user - $filename");
            my $authorized = $class->_check_authorization($nlw);
            st_log->debug( "$requirement for $user - "
                    . "$filename returned: $authorized" );
            return OK if $authorized;
            $explanation .= "<li>Valid workspace members</li>\n";
        }
        else {
            st_log->error(
                "Socialtext::AuthzHandler got invalid Require: $requirement"
            );
            return SERVER_ERROR;
        }
    }
    $explanation .= <<END;
</ul>
</body>
</html>
END
    $r->custom_response( AUTH_REQUIRED, $explanation );
    $r->log_reason( "user $user: not authorized", $filename );
    $r->note_basic_auth_failure;
    return AUTH_REQUIRED;
}

sub _check_authorization {
    my ( $class, $nlw ) = @_;
    my $authz = Socialtext::Authz->new;
    return $authz->user_has_permission_for_workspace(
        user       => $nlw->hub->current_user,
        permission => ST_READ_PERM,
        workspace  => $nlw->hub->current_workspace,
    );
}

1;

__END__

=head1 NAME

Socialtext::AuthzHandler - An Apache Authz Handler Interface to NLW

=head1 SYNOPSIS

    <Location /page>
        AuthName "Socialtext Authentication"
        AuthType Basic
        PerlAddVar SocialtextAuthenActions check_basic
        PerlAddVar SocialtextAuthenActions http_401
        PerlAuthenHandler Socialtext::Apache::AuthenHandler
        PerlAuthzHandler +Socialtext::AuthzHandler
        require valid-user OR valid-workspace-membership
    </Location>

=head1 DESCRIPTION

B<Socialtext::AuthzHandler> is an Apache Authorization Handler that allows for
different levels of Authorization checks to be performed.  Supported 
mechanisms include valid-user or valid-workspace-membership.


=cut

