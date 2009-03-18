package Socialtext::WikiFixture::SocialBase;
# @COPYRIGHT@
use strict;
use warnings;
use Socialtext::Account;
use Socialtext::User;
use Test::More;
use Test::HTTP;
use Socialtext::SQL qw/sql_execute/;
use Socialtext::JSON qw/decode_json encode_json/;
use URI::Escape qw(uri_unescape uri_escape);
use Socialtext::File;
use Time::HiRes qw/gettimeofday tv_interval time/;
use Socialtext::System qw/shell_run/;
use Socialtext::HTTP::Ports;

=head1 NAME

Socialtext::WikiFixture::SocialBase - Base fixture class that has shared logic

=head2 init()

Creates the Test::HTTP object.

=cut

sub init {
    my $self = shift;

    # provide access to the default HTTP(S) ports in use
    $self->{http_port}          = Socialtext::HTTP::Ports->http_port();
    $self->{https_port}         = Socialtext::HTTP::Ports->https_port();
    $self->{backend_http_port}  = Socialtext::HTTP::Ports->backend_http_port();
    $self->{backend_https_port} = Socialtext::HTTP::Ports->backend_https_port();

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

    if (__PACKAGE__->can($command)) {
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

=head2 big_db

Loads the database with records.  Configured through wiki 
variables as follows:

=over 4

=item db_accounts

=item db_users

=item db_pages

=item db_events

=item db_signals

=back

=cut

sub big_db {
    my $self = shift;
    my @args = map { ("--$_" => $self->{"db_$_"}) }
        grep { exists $self->{"db_$_"} }
        qw(accounts users pages events signals);

    shell_run('really-big-db.pl', @args);
}

=head2 stress_for <secs>

Run the stress test code for this many seconds.

=cut

sub stress_for {
    my $self = shift;
    my @args = map { ("--$_" => $self->{"torture_$_"}) }
        grep { exists $self->{"torture_$_"} }
        qw(signalsleep postsleep eventsleep background-sleep signalsclients postclients eventclients background-clients use-at get-avs server limit rampup followers sleeptime base users);

    shell_run('torture', @args);
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

sub get_account_id {
    my ($self, $name, $variable) = @_;
    my $acct = Socialtext::Account->new(name => $name);
    $self->{$variable} = $acct->account_id;
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

sub set_json_from_perl {
    my ($self, $name, $value) = @_;
    $self->{$name} = encode_json(eval $value);
    diag "Set $name to $self->{$name}";
}

sub set_json_from_string {
    my ($self, $name, $value) = @_;
    $self->{$name} = encode_json($value);
    diag "Set $name to $self->{$name}";
}

sub set_uri_escaped {
    my ($self, $name, $value) = @_;
    $self->{$name} = uri_escape($value);
    diag "Set $name to $self->{$name}";
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

=head2 cond_get ( uri, accept, ims, inm )

GET a URI, specifying Accept, If-Modified-Since and If-None-Match headers.

Accept defaults to text/html.

The IMS and INS headers aren't sent unless specified and non-zero.

=cut

sub cond_get {
    my ($self, $uri, $accept, $ims, $inm) = @_;
    $accept ||= 'text/html';
    my @headers = ( Accept => $accept );
    push @headers, 'If-Modified-Since', $ims if $ims;
    push @headers, 'If-None-Match', $inm if $inm;

    warn "Calling get on $uri";
    my $start = time();
    $self->{http}->get($self->{browser_url} . $uri, \@headers);
    $self->{_last_http_time} = time() - $start;
}

sub was_faster_than {
    my ($self, $secs) = @_;

    my $elapsed = delete $self->{_last_http_time} || -1;
    cmp_ok $elapsed, '<=', $secs, "timer was faster than $secs";
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

=head2 set_http_keepalive ( on_off )

Enables/disables support for HTTP "Keep-Alive" connections (defaulting to I<off>).

When called, this method re-instantiates the C<Test::HTTP> object that is
being used for testing; be aware of this when writing your tests.

=cut

sub set_http_keepalive {
    my $self   = shift;
    my $on_off = shift;

    # switch User-Agent classes
    $Test::HTTP::UaClass = $on_off ? 'Test::LWP::UserAgent::keep_alive' : 'LWP::UserAgent';

    # re-instantiate our Test::HTTP object
    delete $self->{http};
    $self->http_user_pass($self->{username}, $self->{password});
}

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

=head2 set_from_header ( name, header )

Set a variable from a header in the last response.

=cut

sub set_from_header {
    my $self = shift;
    my $name = shift || die "name is mandatory for set-from-header";
    my $header = shift || die "header is mandatory for set-from-header";
    my $content = $self->{http}->response->header($header);

    if (defined $content) {
        $self->{$name} = $content;
        warn "# Set $name to '$content' from response header\n";
    }
    else {
        die "Could not set $name - header $header not present\n";
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
    sql_execute("DELETE FROM signal");
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

=head2 json-like

Confirm that the resulting body is a JSON object which is like (ignoring order
for arrays/dicts) the value given. 

The comparison is as follows between the 'candidate' given as a param in the
wikitest, and the value object derived from decoding hte json object from the
wikitest.  this is performed recursively): 1) if the value object is a scalar,
perform comparison with candidate (both must be scalars), 2) if the object is
an array, then for each object in the candidate, ensure the object in the is a
dictionary, then for each key in the candidate object, ensure that the same
key exists in the value object and that it maps to a value that is equivalent
to the value mapped to in the candidate object.

*WARNING* - Right now, this is stupid about JSON numbers as strings v.
numbers. That is, the values "3" and 3 are considered equivalent (e.g.
{"foo":3} and {"foo":"3"} are considered equivalent - this is a known bug in
this fixture)

=cut


sub json_like {
    
    my $self = shift;
    my $candidate = shift;

    my $json = $self->{json};
      
    if (not defined $json ) {
        fail $self->{http}->name . " no json result";
    }
    my $parsed_candidate = eval { decode_json($candidate) };
    if ($@ || ! defined $parsed_candidate || ref($parsed_candidate) !~ /^|ARRAY|HASH|SCALAR$/)  {
        fail $self->{http}->name . " failed to find or parse candidate " . ($@ ? " \$\@=$@" : "");
        return;
    }
    
    my $result=0;
    $result = eval {$self->_compare_json($parsed_candidate, $json)}; 
    if (!$@ && $result) {
        ok !$@ && $result, 
        $self->{http}->name . " compared content and candidate";
    } else {
        fail "$candidate\n and\n ".encode_json($json)."\n" . ($@ ? "\$\@=$@" : "");
    }
}

sub _compare_json {
    my $self = shift;
    my $candidate = shift;
    my $json = shift;


    die "Candidate is undefined" unless defined $candidate;
    die "JSON is undefined" unless defined $json;
    die encode_json($json) . " is not a VAL/SCALAR/HASH/ARRAY" unless ref($json) =~ /^|SCALAR|HASH|ARRAY$/;
    if (ref($json) eq 'SCALAR' || ref($json) eq '') {
        die "Type of $json and $candidate are not both values" unless (ref($json) eq ref($candidate));
        die "No match for \n$candidate\nAND\n$json\n" unless ($json eq $candidate);
    }
    elsif (ref($json) eq 'ARRAY') {
        my $match = 1;
        die "Expecting array for ". encode_json($candidate) . " with json ".encode_json($json) unless ref ($candidate) eq 'ARRAY'; 
        foreach (@$candidate) {
            my $candobj=$_;
            my $exists = 0;
            foreach (@$json) {
                $exists ||= eval {$self->_compare_json($candobj, $_)};
            }
            $match &&= $exists;
        }
        die "No match for candidate ".encode_json($candidate) . " with json ".encode_json($json) unless $match; 
    }
    elsif (ref($json) eq 'HASH') {
        die  "Expecting hash for ". encode_json($candidate) . " with json ".encode_json($json) unless ref($candidate) eq 'HASH'; 
        my $match = 1;
        for my $key (keys %$candidate) {
            die "Can't find value for key '$key' in JSON ". encode_json($json)  unless defined($json->{$key});
            $match &&= $self->_compare_json($candidate->{$key}, $json->{$key});
        }
        die "No match for candidate ".encode_json($candidate) . " with json ".encode_json($json) unless $match;
    }
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
    my $start = time();
    $self->{http}->$method($self->{browser_url} . $uri, $headers, $body);
    $self->{_last_http_time} = time() - $start;
}

sub _get {
    my ($self, $uri, $opts) = @_;
    warn "GET: $self->{browser_url}$uri"; # intentional warn
    my $start = time();
    $self->{http}->get( $self->{browser_url} . $uri, $opts );
    $self->{_last_http_time} = time() - $start;
}

sub _delete {      
    my ($self, $uri, $opts) = @_;
    my $start = time();
    $self->{http}->delete( $self->{browser_url} . $uri, $opts );
    $self->{_last_http_time} = time() - $start;
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

=head2 st_deliver_email( )

Imitates sending an email to a workspace

=cut

sub deliver_email {
    my ($self, $workspace, $email_name) = @_;

    my $in = Socialtext::File::get_contents("t/test-data/email/$email_name");
    $in =~ s{^Subject: (.*)}{Subject: $1 $^T}m;

    my ($out, $err);
    my @command = ('bin/st-admin', 'deliver-email', '--workspace', $workspace);

    IPC::Run::run \@command, \$in, \$out, \$err;
    $self->{_deliver_email_result} = $? >> 8;
    $self->{_deliver_email_err} = $err;
    diag "Delivered $email_name email to the $workspace workspace";
}

sub deliver_email_result_is {
    my ($self, $result) = @_;
    is $self->{_deliver_email_result}, $result, 
        "Delivering email returns $result";
}

sub deliver_email_error_like {
    my ($self, $regex) = @_;
    $regex = $self->quote_as_regex($regex);
    like $self->{_deliver_email_err}, $regex, 
        "Delivering email stderr matches $regex";
}

sub set_from_subject {
    my $self = shift;
    my $name = shift || die "email-name is mandatory for set-from-email";
    my $email_name = shift || die "name is mandatory for set-from-email";
    my $in = Socialtext::File::get_contents("t/test-data/email/$email_name");
    if ($in =~ m{^Subject: (.*)}m) {
        ($self->{$name} = "$1 $^T") =~ s{^Re: }{};
    }
    else {
        die "Can't find subject in $email_name";
    }
}

sub remove_workspace_permission {
    my ($self, $workspace, $role, $permission) = @_;

    require Socialtext::Role;
    require Socialtext::Permission;

    my $ws = Socialtext::Workspace->new(name => $workspace);
    my $perms = $ws->permissions;
    $perms->remove(
        role => Socialtext::Role->$role,
        permission => Socialtext::Permission->new( name => $permission ),
    );
    diag "Removed $permission permission for $workspace workspace $role role";
}

sub add_workspace_permission {
    my ($self, $workspace, $role, $permission) = @_;

    require Socialtext::Role;
    require Socialtext::Permission;

    my $ws = Socialtext::Workspace->new(name => $workspace);
    my $perms = $ws->permissions;
    $perms->add(
        role => Socialtext::Role->$role,
        permission => Socialtext::Permission->new( name => $permission ),
    );
    diag "Added $permission permission for $workspace workspace $role role";
}

sub start_timer {
    my $self = shift;
    my $name = shift || 'default';

    $self->{_timer}{$name} = [ gettimeofday ];
}

sub faster_than {
    my $self = shift;
    my $ms = shift or die "faster_than requires a time in ms!";
    my $name = shift || 'default';
    my $start = $self->{_timer}{$name} || die "$name is not a valid timer!";

    my $elapsed = tv_interval($start);
    cmp_ok $elapsed, '<=', $ms, "$name timer was faster than $ms";
}

sub parse_logs {
    my $self = shift;
    my $file = shift;
    
    die "File doesn't exist!" unless -e $file;
    my $report_perl = "$^X -I$ENV{ST_CURRENT}/socialtext-reports/lib"
        . " -I$ENV{ST_CURRENT}/nlw/lib $ENV{ST_CURRENT}/socialtext-reports";
    shell_run("$report_perl/bin/st-reports-consume-access-log $file");
}

sub clear_reports {
    my $self = shift;
    shell_run("cd $ENV{ST_CURRENT}/socialtext-reports; ./setup-dev-env");
}

=head2 header_isnt ( header, value )

Asserts that a header in the response does not contain the specified value.

=cut

sub header_isnt {
    my $self = shift;
    if ($self->{http}->can('header_isnt')) {
        return $self->{http}->header_isnt(@_);
    }
    else {
        my $header = shift;
        my $expected = shift;
        my $value = $self->{http}->response->header($header);
        isnt($value, $expected, "header $header");
    }
}

=head2 reset_plugins

Reset any global plugin enabled.

=cut

sub reset_plugins {
    my $self = shift;
    sql_execute(q{DELETE FROM "System" WHERE field like '%-enabled-all'});
}


1;
