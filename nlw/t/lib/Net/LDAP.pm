# @COPYRIGHT@

package Net::LDAP;
use strict;
use warnings;

my %test_creds = (
    'cn=one,dc=foo,dc=bar' => {
        cn           => 'one',
        userPassword => 'password',
        mail         => 'one@foo.bar',
        gn           => 'One',
        sn           => 'Loser',
        },
    'cn=two,dc=foo,dc=bar' => {
        cn           => 'two',
        userPassword => 'password',
        mail         => 'two@foo.bar',
        gn           => 'Two',
        sn           => 'Wiener',
        },
    'cn=three,dc=foo,dc=bar' => {
        cn           => 'three',
        userPassword => 'treesaregood',
        mail         => 'three@foo.bar',
        gn           => 'Three',
        sn           => 'Hugger',
        },
);

sub new {
    my ($class, $host, %opts) = @_;
    my $self = {
        host => $host,
        %opts,
    };
    bless $self, $class;
    return $self;
}

sub bind {
    my $self = shift;
    my @args = @_;

    # default: Assume anonymous binding or one that matches creds.
    # REVIEW: when we get to testing configuration that includes binding creds
    my $binding = Net::LDAP::Binding->new(code => 0, error => 'Success');

    # what are the args? sometimes the thing after && can produce
    # a warning
    if (@args && $test_creds{$args[0]}{userPassword} ne $args[2]) {
        $binding = Net::LDAP::Binding->new(code => 49, error => 'Bad credentials');
    }
    return $binding;
}

sub search { 
    my $self = shift;
    return Net::LDAP::Search->new(@_) 
}

package Net::LDAP::Binding;

sub new {
    my ($class, %opts) = @_;
    return bless { %opts }, $class;
}

sub code {
    my $self = shift;
    return $self->{code};
}

sub error {
    my $self = shift;
    return $self->{error};
}

package Net::LDAP::Search;

sub new {
    # ->new( base => 'some_base', scope => 'sub', filter => '(cn=one)' )
    # ->new( base => 'cn=one,dc=foo,dc=bar', scope => 'base', filter => '(objectClass=*)' )
    # ->new( base => 'some_base', scope => 'sub', filter => '(|(cn=*one*)(mail=*one*)(gn=*one*)(sn=*one*))' )
    my ( $class, %opts ) = @_;
    my $self = {%opts};
    $self->{entries} = [];

    # dispatch on scope
    if ( $opts{scope} eq 'base' ) {
        if ( $test_creds{ $opts{base} } ) {
            unshift @{ $self->{entries} },
                { dn => $opts{base}, %{ $test_creds{ $opts{base} } } };
        }
    }
    else {    # we're looking up attrs
              #  - (base = base and filter = '(cn=foo)')
              # break up the filter into sets of '(x=y)'
        my %seen_key;
        my @matches = ( $opts{filter} =~ m/(\([^\(=]*=[^\)]*\))*/g );
        for my $match (grep { defined } @matches) {
            my ( $attr, $value ) = ( $match =~ m/\((.*)=(.*)\)/ );
            $value =~ s/\*//g;
            for my $cred_key ( keys %test_creds ) {
                my %cred = %{ $test_creds{$cred_key} };
                if ( $cred{$attr} =~ m/$value/ ) {

                    # Do not return duplicate records.
                    next if $seen_key{$cred_key}++;

                    unshift @{ $self->{entries} }, { dn => $cred_key, %cred };
                }
            }
        }
    }
    bless $self, $class;
    return $self;
}

sub shift_entry { 
    my $self = shift;
    my $args = shift @{$self->{entries}};
    return Net::LDAP::Entry->new(%$args);
}

sub entries {
    my $self = shift;
    return map { Net::LDAP::Entry->new(%$_) } @{$self->{entries}};
}

package Net::LDAP::Entry;

sub new {
    my ($class, %opts) = @_;
    my $self = { %opts };
    bless $self, $class;
    return $self;
}

sub get_value { 
    my $self = shift;
    my $attr = shift;
    return $self->{$attr};
}

sub dn {
    my $self = shift;
    return $self->{dn};
}

1;
