package Socialtext::LDAP::Base;
# @COPYRIGHT@

use strict;
use warnings;
use Class::Field qw(field);
use Net::LDAP;
use Socialtext::Log qw(st_log);

field 'config';

sub new {
    my ($class, $config) = @_;

    # must have config
    return unless $config;

    # create new object
    my $self = {
        config => $config,
        };
    bless $self, $class;

    # connect to the LDAP server
    $self->connect() or return;

    # return newly created LDAP connection back to caller
    return $self;
}

sub DESTROY {
    my $self = shift;
    # close any open LDAP connection
    if ($self->{ldap}) {
        $self->{ldap}->disconnect();
        delete $self->{ldap};
    }
}

sub connect {
    my $self = shift;
    my $host = $self->config->host();

    # set up connection options
    my %opts = ();
    if ($self->config->port()) {
        $opts{port} = $self->config->port();
    }

    # attempt connection
    $self->{ldap} = Net::LDAP->new( $host, %opts );
    unless ($self->{ldap}) {
        my $host_str = ref($host) eq 'ARRAY' ? join(', ', @{$host}) : $host;
        st_log->error( "ST::LDAP::Base: unable to connect to LDAP server; $host_str" );
        return;
    }
    return $self;
}

sub bind {
    my $self = shift;
    my $user = $self->config->bind_user();

    # set up bind options
    my %opts = ();
    if ($self->config->bind_password()) {
        $opts{password} = $self->config->bind_password();
    }

    # attempt to bind to LDAP connection
    my $mesg = $self->{ldap}->bind( $user, %opts );
    if ($mesg->code()) {
        st_log->error( "ST::LDAP::Base: unable to bind to LDAP connection; " . $mesg->error() );
        return;
    }
    return $self;
}

sub authenticate {
    my ($self, $user_id, $password) = @_;
    my $mesg = $self->{ldap}->bind( $user_id, password => $password );
    if ($mesg->code()) {
        st_log->info( "ST::LDAP::Base: authentication failed for user; $user_id" );
        return;
    }
    return 1;
}

sub search {
    my ($self, %args) = @_;
    # add global filter to search args
    my $filter = $self->config->filter();
    if ($filter) {
        if ($args{filter}) {
            $args{filter} = '(&' . $filter . $args{filter} . ')';
        }
        else {
            $args{filter} = $filter;
        }
    }
    # do search, return results
    return $self->{ldap}->search(%args);
}

1;

=head1 NAME

Socialtext::LDAP::Base - Base class for LDAP plug-ins

=head1 SYNOPSIS

  use Socialtext::LDAP;

  # instantiate a new LDAP connection
  $ldap = Socialtext::LDAP->new();

  # performing a search against an LDAP directory
  $mesg = $ldap->search( %options );

  # authenticating against an existing LDAP connection
  # (see METHODS below for caveats on authorization/privileges)
  $auth_ok = $ldap->authenticate( $user_id, $password );

  # re-binding an LDAP connection (to reset authorization/privileges)
  $bind_ok = $ldap->bind();

=head1 DESCRIPTION

C<Socialtext::LDAP::Base> implements a base class for LDAP plug-ins, which
provides a generic LDAP implementation.  LDAP back-end plug-ins which require
custom behaviour can derive and over-ride methods as needed.

=head1 METHODS

=over

=item B<Socialtext::LDAP::Base-E<gt>new($config)>

Instantiates a new LDAP object and connects to the LDAP server.  Returns the
newly created object on success, false on any failure.

C<connect()> is called automatically, but you will be responsible for binding
or authenticating against the connection yourself.

=item B<connect()>

Connects to the LDAP server, using the configuration provided at
instantiation.  Returns true on success, false on failure.

Called automatically by C<new()>.

=item B<bind()>

Binds to the LDAP connection, using the configuration provided at
instantiation.  Returns true on success, false on failure.

=item B<authenticate($user_id, $password)>

Attempts to authenticate against the LDAP connection, using the provided
C<$user_id> and C<$password>.  Returns true if successful, false otherwise.

B<NOTE:> after calling C<authenticate()>, the LDAP connection will be bound
using the provided C<$user_id>; any further method calls will be done
with the privileges and authorization granted to that user.  If you wish to
reset the connection back to its original privileges, simply call C<bind()>
to re-bind the connection and reset its privileges.

=item B<search(%opts)>

Performs a search against the LDAP connection, making sure that any C<filter>
that has been defined in the LDAP configuration is applied automatically by
prepending it to any provided C<filter> as an "&" (and) condition.

Accepts all of the parameters that C<Net::LDAP::search()> does (refer to
L<Net::LDAP> for more information).  Returns a C<Net::LDAP::Search> object back
to the caller.

=back

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Net::LDAP>.

=cut
