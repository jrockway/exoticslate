package Socialtext::Apache::Authen::NTLM;
# @COPYRIGHT@

use strict;
use warnings;
use base qw(Apache::AuthenNTLM);
use Socialtext::NTLM::Config;
use Socialtext::Log qw(st_log);

###############################################################################
# read in our custom NTLM config, instead of relying on Apache config file to
# set this up.
sub get_config {
    my ($self, $r) = @_;

    # if we've already read in the config, don't do it again.
    return if ($self->{smbpdc});

    # let our base class read in its config, so that Admins _could_ use their
    # Apache config to define some of this if they wanted to.
    $self->SUPER::get_config($r);

    # read in our NTLM config, and set up our PDC/BDCs
    my @all_configs = Socialtext::NTLM::Config->load();
    foreach my $config (@all_configs) {
        my $domain  = lc( $config->domain() );
        my $primary = $config->primary();
        my $backups = $config->backup();

        $self->{smbpdc}{$domain} = $primary;
        $self->{smbbdc}{$domain} = join ' ', @{$backups};
    }

    # debugging notes
    my $prefix = 'ST::Apache::Authen::NTLM:';
    st_log->debug( "$prefix default domain: " . $self->{defaultdomain} );
    st_log->debug( "$prefix fallback domain: " . $self->{fallbackdomain} );
    st_log->debug( "$prefix AuthType: " . $self->{authtype} );
    st_log->debug( "$prefix AuthName: " . $self->{authname} );
    st_log->debug( "$prefix Auth NTLM: " . $self->{authntlm} );
    st_log->debug( "$prefix Auth Basic: " . $self->{authbasic} );
    st_log->debug( "$prefix NTLMAuthoritative: " . $self->{ntlmauthoritative} );
    st_log->debug( "$prefix SplitDomainPrefix: " . $self->{splitdomainprefix} );
    foreach my $domain (sort keys %{$self->{smbpdc}}) {
        st_log->debug( "$prefix domain: $domain" );
        st_log->debug( "$prefix ... pdc: " . $self->{smbpdc}{$domain} );
        st_log->debug( "$prefix ... bdc: " . $self->{smbbdc}{$domain} );
    }
}

###############################################################################
# Over-ridden Mod_perl handler.
sub handler($$) {
    my ($class, $r) = @_;

    # turn HTTP KeepAlive requests *ON*
    st_log->debug( "turning HTTP Keep-Alives back on" );
    $r->subprocess_env(nokeepalive => undef);

    # call base class to do its work
    return $class->SUPER::handler($r);
}

1;

=head1 NAME

Socialtext::Apache::Authen::NTLM - Custom Apache NTLM Authentication handler

=head1 SYNOPSIS

  # In your Apache/Mod_perl config
  <Location /nlw/ntlm>
    SetHandler          perl-script
    PerlHandler         +Socialtext::Handler::Redirect
    PerlAuthenHandler   +Socialtext::Apache::Authen::NTLM
    Require             valid-user
  </Location>

=head1 DESCRIPTION

C<Socialtext::Apache::Authen::NTLM> is a custom Apache/Mod_perl authentication
handler, that uses NTLM for authentication and is derived from
C<Apache::AuthenNTLM>.  Please note that only NTLM v1 is implemented at this
time.

=head1 METHODS

=over

=item B<Socialtext::Apache::Authen::NTLM-E<gt>handler($request)>

Over-ridden C<handler()> method, which forcably turns B<on> HTTP Keep-Alive
requests before letting our base class to its work.

This re-enabling of Keep-Alive requests is required as they're auto-disabled
by C<Socialtext::InitHandler>.

=item B<$self-E<gt>get_config($request)>

Over-ridde C<get_config()> method, which reads in our configuration from
C<Socialtext::NTLM::Config>, instead of expecting it to be configured in the
Apache/Mod_perl configuration files.

You I<can> still use the Apache/Mod_perl configuration file to define NTLM
configuration, but this configuration will be supplemented/over-written by the
configuration read using C<Socialtext::NTLM::Config>.

=back

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc., All Rights Reserved.

=head1 SEE ALSO

L<Apache::AuthenNTLM>,
L<Socialtext::InitHandler>,
L<Socialtext::NTLM::Config>.

=cut
