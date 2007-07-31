#!perl
# @COPYRIGHT@
use strict;
use warnings;

BEGIN {
    use mocked 'Socialtext::l10n', qw(system_locale);
    use Socialtext::Workspace;

    use Test::Socialtext tests => 4;
    fixtures('help');

    use_ok('Socialtext::Rest::Help');
}

GET_URI: {
    my $r = FakeRequest->new("/help/foo/matthew/index.cgi?like=2;love=97");
    my $uri = Socialtext::Rest::Help::get_uri( $r, "cows" );
    is( $uri, "/cows/foo/matthew/index.cgi?like=2;love=97",
        "URL was converted" );
}

HANDLER_REDIRECT: {
    system_locale('en');
    my $r = FakeRequest->new("/help/index.cgi?socialtext_documentation");
    Socialtext::Rest::Help->new($r)->handler($r);
    is_deeply(
        $r->header, 
        [
            '-status' => '302 Found',
            '-Location' => '/help-en/index.cgi?socialtext_documentation',
        ],
        "A redirect was generated"
    );
}

HANDLER_REDIRECT: {
    system_locale('xx');
    Socialtext::Workspace->new(name => 'help-en')->delete();
    my $r = FakeRequest->new("/help/index.cgi?socialtext_documentation");
    Socialtext::Rest::Help->new($r)->handler($r);
    is_deeply(
        $r->header, 
        [
            '-status' => '404 Not Found',
            '-type' => 'text/plain'
        ], 
        "A 404 for help-xx was generated"
    );
}

package FakeRequest;

sub new {
    my ( $class, $uri ) = @_;
    bless {_uri => $uri}, $class;
}

# To support $r->query->url(...)
sub url { shift->{_uri} }
sub query { shift }

sub AUTOLOAD {
    our $AUTOLOAD;
    my $self = shift;
    my $method = $AUTOLOAD;
    $method =~ s/.*://;
    return if $method eq 'DESTROY';

    $self->{$method} = shift if @_ == 1;
    $self->{$method} = [@_]  if @_ > 1;
    die "Method undefined: $method\n" unless exists $self->{$method};
    return $self->{$method};
}
