package Socialtext::WikiFixture::SocialBase;
# @COPYRIGHT@
use strict;
use warnings;
use Socialtext::Account;
use Socialtext::User;
use Test::More;
use Test::HTTP;
use Socialtext::SQL qw/sql_execute/;
use Socialtext::JSON qw/decode_json/;

=head1 NAME

Socialtext::WikiFixture::SocialBase - Base fixture class that has shared logic

=head2 init()

Creates the Test::HTTP object.

=cut

sub init {
    my $self = shift;

    # Set up the Test::HTTP object initially
    $self->http_user_pass($self->{username}, $self->{password});
}

sub _munge_command_and_opts {
    my $self = shift;
    my $command = lc(shift);
    my @opts = $self->_munge_options(@_);
    $command =~ s/-/_/g;
    $command =~ s/^\*(.+)\*$/$1/;

    if ($command eq 'body_like') {
        $opts[0] = $self->quote_as_regex($opts[0]);
    }
    elsif ($command =~ m/_like$/) {
        $opts[1] = $self->quote_as_regex($opts[1]);
    }

    return ($command, @opts);
}

sub _handle_command {
    my $self = shift;
    my ($command, @opts) = @_;

    if ($self->can($command)) {
        use Data::Dumper;
        return $self->$command(@opts);
    }
    if ($self->{http}->can($command)) {
        return $self->{http}->$command(@opts);
    }
    die "Unknown command for the fixture: ($command)\n";
}

=head2 http_user_pass ( $username, $password )

Set the HTTP username and password.

=cut

sub http_user_pass {
    my $self = shift;
    my $user = shift;
    my $pass = shift;

    my $name = ($self->{http}) ? $self->{http}->name : 'SocialRest fixture';

    $self->{http} = Test::HTTP->new($name);
    $self->{http}->username($user) if $user;
    $self->{http}->password($pass) if $pass;
}

sub create_account {
    my $self = shift;
    my $name = shift;
    my $acct = Socialtext::Account->create(
        name => $name,
    );
    my $ws = Socialtext::Workspace->new(name => 'admin');
    $acct->enable_plugin($_) for qw/people dashboard widgets signals/;
    $ws->enable_plugin($_) for qw/socialcalc/;
    diag "Created account $name";
}

sub account_config {
    my $self = shift;
    my $account_name = shift;
    my $key = shift;
    my $val = shift;
    my $acct = Socialtext::Account->new(
        name => $account_name,
    );
    $acct->update($key => $val);
    diag "Set account $account_name config: $key to $val";
}

sub workspace_config {
    my $self = shift;
    my $ws_name = shift;
    my $key = shift;
    my $val = shift;
    my $ws = Socialtext::Workspace->new(
        name => $ws_name,
    );
    $ws->update($key => $val);
    diag "Set workspace $ws_name config: $key to $val";
}

sub disable_account_plugin {
    my $self = shift;
    my $account_name = shift;
    my $plugin = shift;

    my $acct = Socialtext::Account->new(
        name => $account_name,
    );
    $acct->disable_plugin($plugin);
    diag "Disabled plugin $plugin in account $account_name";
}

sub create_user {
    my $self = shift;
    my $email = shift;
    my $password = shift;
    my $account = shift;
    my $name = shift || ' ';

    my ($first_name,$last_name) = split(' ',$name,2);
    $first_name ||= '';
    $last_name ||= '';

    my $user = Socialtext::User->create(
        email_address => $email,
        username      => $email,
        password      => $password,
        first_name    => $first_name,
        last_name     => $last_name,
        (
            $account
            ? (primary_account_id =>
                    Socialtext::Account->new(name => $account)->account_id())
            : ()
        )
    );
    diag "Created user ".$user->email_address. ", name ".$user->guess_real_name;
}

sub create_workspace {
    my $self = shift;
    my $name = shift;
    my $account = shift;

    my $ws = Socialtext::Workspace->new(name => $name);
    if ($ws) {
        diag "Workspace $name already exists";
        return
    }

    Socialtext::Workspace->create(
        name => $name, title => $name,
        (
            $account
            ? (account_id => Socialtext::Account->new(name => $account)
                ->account_id())
            : (account_id => Socialtext::Account->Default->account_id())
        ),
        skip_default_pages => 1,
    );
    diag "Created workspace $name";
}

sub set_ws_permissions {
    my $self       = shift;
    my $workspace  = shift;
    my $permission = shift;

    my $ws = Socialtext::Workspace->new(name => $workspace);
    die "No such workspace $workspace" unless $ws;
    $ws->permissions->set( set_name => $permission );
    diag "Set workspace $workspace permission to $permission";
}

sub add_member {
    my $self = shift;
    my $email = shift;
    my $workspace = shift;

    my $ws = Socialtext::Workspace->new(name => $workspace);
    die "No such workspace $workspace" unless $ws;
    my $user = Socialtext::User->Resolve($email);
    die "No such user $email" unless $user;

    $ws->add_user( user => $user );
    diag "Added user $email to $workspace";
}

sub set_user_id {
    my $self = shift;
    my $var_name = shift;
    my $email = shift;

    my $user = Socialtext::User->Resolve($email);
    die "No such user $email" unless $user;
    $self->{$var_name} = $user->user_id;
    diag "Set variable $var_name to $self->{$var_name}";
}

sub set_account_id {
    my $self = shift;
    my $var_name = shift;
    my $acct_name = shift;

    my $acct = Socialtext::Account->new(name => $acct_name);
    die "No such user $acct_name" unless $acct;
    $self->{$var_name} = $acct->account_id;
    diag "Set variable $var_name to $self->{$var_name}";
}

sub sleep {
    my $self = shift;
    my $secs = shift;
    sleep $secs;
}

=head2 get ( uri, accept )

GET a URI, with the specified accept type.  

accept defaults to 'text/html'.

=cut

sub get {
    my ($self, $uri, $accept) = @_;
    $accept ||= 'text/html';

    $self->_get($uri, [Accept => $accept]);
}

=head2 delete ( uri, accept )

DELETE a URI, with the specified accept type.  

accept defaults to 'text/html'.

=cut

sub delete {
    my ($self, $uri, $accept) = @_;
    $accept ||= 'text/html';

    $self->_delete($uri, [Accept => $accept]);
}
            

=head2 code_is( code [, expected_message])

Check that the return code is correct.

=cut

sub code_is {
    my ($self, $code, $msg) = @_;
    $self->{http}->status_code_is($code);
    if ($self->{http}->response->code != $code) {
        warn "Response message: "
            . ($self->{http}->response->message || 'None')
            . " url(" . $self->{http}->request->url . ")";
    }
    if ($msg) {
        like $self->{http}->response->content(), $self->quote_as_regex($msg),
             "Status content matches";
    }
}

=head2 has_header( header [, expected_value])

Check that the specified header is in the response, with an optional second check for the header's value.

=cut

sub has_header {
    my ($self, $header, $value) = @_;
    my $hval = $self->{http}->response->header($header);
    ok $hval, "header $header is defined";
    if ($value) {
        like $hval, $self->quote_as_regex($value), "header content matches";
    }
}

=head2 post( uri, headers, body )

Post to the specified URI

=cut

sub post { shift->_call_method('post', @_) }

=head2 post_json( uri, body )

Post to the specified URI with header 'Content-Type=application/json'

=cut

sub post_json { 
    my $self = shift;
    my $uri = shift;
    $self->post($uri, 'Content-Type=application/json', @_);
}

=head2 put( uri, headers, body )

Put to the specified URI

=cut

sub put { shift->_call_method('put', @_) }

=head2 set_from_content ( name, regex )

Set a variable from content in the last response.

=cut

sub set_from_content {
    my $self = shift;
    my $name = shift || die "name is mandatory for set-from-content";
    my $regex = $self->quote_as_regex(shift || '');
    my $content = $self->{http}->response->content;
    if ($content =~ $regex) {
        if (defined $1) {
            $self->{$name} = $1;
            warn "# Set $name to '$1' from response content\n";
        }
        else {
            die "Could not set $name - regex didn't capture!";
        }
    }
    else {
        die "Could not set $name - regex ($regex) did not match $content";
    }
}

=head2 st-clear-events

Delete all events

=cut

sub st_clear_events {
    sql_execute('DELETE FROM event');
}


=head2 st-clear-signals

Delete all signals

=cut

sub st_clear_signals {
    sql_execute("DELETE FROM noun WHERE noun_type = 'signal'");
}


=head2 st-delete-people-tags

Delete all people tags.

=cut

sub st_delete_people_tags {
    sql_execute('DELETE FROM tag_people__person_tags');
    sql_execute('DELETE FROM person_tag');
}

=head2 json-parse

Try to parse the body as JSON, remembering the result for additional tests.

=cut

sub json_parse {
    my $self = shift;
    $self->{json} = undef;
    $self->{json} = eval { decode_json($self->{http}->response->content) };
    ok !$@ && defined $self->{json} && ref($self->{json}) =~ /^ARRAY|HASH$/,
        $self->{http}->name . " parsed content" . ($@ ? " \$\@=$@" : "");
}

=head2 json-array-size

Confirm that the resulting body is a JSON array of length X.

=cut

sub json_array_size {
    my $self = shift;
    my $comparator = shift;
    my $size = shift;

    if (!defined($size) or $size eq '') {
        $size = $comparator;
        $comparator = '==';
    }

    my $json = $self->{json};
    if (not defined $json ) {
        fail $self->{http}->name . " no json result";
    }
    elsif (ref($json) ne 'ARRAY') {
        fail $self->{http}->name . " json result is not an array";
    }
    else {
        cmp_ok scalar(@$json), $comparator, $size, 
            $self->{http}->name . " array is expected size" ;
    }
}

sub _call_method {
    my ($self, $method, $uri, $headers, $body) = @_;
    if ($headers) {
        $headers = [
            map {
                my ($k,$v) = split m/\s*=\s*/, $_;
                $k =~ s/-/_/g;
                ($k,$v);
            } split m/\s*,\s*/, $headers
        ];
    }
    $self->{http}->$method($self->{browser_url} . $uri, $headers, $body);
}

sub _get {
    my ($self, $uri, $opts) = @_;
    warn "GET: $self->{browser_url}$uri";
    $self->{http}->get( $self->{browser_url} . $uri, $opts );
}

sub _delete {      
        my ($self, $uri, $opts) = @_;
            $self->{http}->delete( $self->{browser_url} . $uri, $opts );
}

sub edit_page {
    my $self = shift;
    my $workspace = shift;
    my $page_name = shift;
    my $content = shift;
    $self->put("/data/workspaces/$workspace/pages/$page_name",
        'Accept=text/html,Content-Type=text/x.socialtext-wiki',
        $content,
    );
    my $code = $self->{http}->response->code;
    ok( (($code == 201) or ($code == 204)), "Code is $code");
    diag "Edited page [$page_name]/$workspace";
}

1;
