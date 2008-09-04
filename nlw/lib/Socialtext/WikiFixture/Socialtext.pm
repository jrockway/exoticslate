# @COPYRIGHT@
package Socialtext::WikiFixture::Socialtext;
use strict;
use warnings;
use base 'Socialtext::WikiFixture::Selenese';
use Socialtext::System qw/shell_run/;
use Socialtext::Workspace;
use Sys::Hostname;
use Test::More;
use Cwd;
use Socialtext::AppConfig;

=head1 NAME

Socialtext::WikiFixture::Selenese - Executes wiki tables using Selenium RC

=cut

our $VERSION = '0.03';

=head1 DESCRIPTION

This module is a subclass of Socialtext::WikiFixture::Selenese and includes
extra commands specific for testing a Socialtext wiki.

=head1 FUNCTIONS

=head2 new( %opts )

Create a new fixture object.  The same options as
Socialtext::WikiFixture::Selenese are required, as well as:

=over 4

=item workspace

Mandatory - Specifies which Socialtext workspace will be tested.

=item username

Mandatory - username to login to the wiki with.

=item password

Mandatory - password to login to the wiki with.

=back

=head2 init()

Creates the Test::WWW::Selenium object, and logs into the Socialtext
workspace.

=cut

sub init {
    my ($self) = @_;

    $self->{mandatory_args} ||= [qw(workspace username password)];
    for (@{ $self->{mandatory_args} }) {
        die "$_ is mandatory!" unless $self->{$_};
    }
   
    #Get the workspace skin if the workspace attribute is set
    #Otherwise, default to s2
    my $ws = Socialtext::Workspace->new( name => $self->{workspace} );
    my $skin = 's2';
    if (defined($ws)) {
        $skin = $ws->skin_name();
    }
    
    $self->{'skin'} = $skin;
    $self->SUPER::init;

    { # Talc/Topaz are configured to allow emailing into specific dev-envs
        (my $host = $self->{browser_url}) =~ s#^http.?://(.+):\d+#$1#;
        $self->{wikiemail} = $ENV{WIKIEMAIL} || "$ENV{USER}.$host";
        diag  "wikiemail:  $self->{wikiemail}";
    }
    diag "Browser url is ".$self->{browser_url};
    $self->st_login;
}

=head2 st_login()

Logs into the Socialtext wiki using supplied username and password.

=cut

sub st_login {
    my $self = shift;
    my $sel = $self->{selenium};

    my $username = shift || $self->{username};
    my $password = shift || $self->{password};
    my $workspace = shift || $self->{workspace};

    my $url = '/nlw/login.html';
    $url .= "?redirect_to=\%2F$workspace\%2Findex.cgi" if $workspace;
    diag "st-login: $username, $password, $workspace - $url";
    $sel->open_ok($url);
    $sel->type_ok('username', $username);
    $sel->type_ok('password', $password);
    $self->click_and_wait(q{id=login_btn}, 'log in');
}

=head2 st_logout()

Log out of the Socialtext wiki.

=cut

sub st_logout {
    my $self = shift;
    diag "st-logout";
    $self->click_and_wait('id=logout_btn', 'log out');
}

=head2 st_logoutin()

Logs out of the workspace, then logs back in.

A username and password are optional parameters, and will be used in place
of the configured username and password.

=cut

sub st_logoutin {
    my ($self, $username, $password) = @_;
    $self->st_logout;
    $self->st_login($username, $password);
}

=head2 st_page_title( $expected_title )

Verifies that the page title (NOT HTML title) is correct.

=cut

sub st_page_title {
    my ($self, $expected_title) = @_;
    if ($self->{'skin'} eq 's2') {
        $self->{selenium}->text_like('id=st-list-title', qr/\Q$expected_title\E/);
    } elsif ($self->{'skin'} eq 's3') {
        $self->{selenium}->text_like('//div[@id=\'contentContainer\']', qr/\Q$expected_title\E/);
    } else {
        ok 0, "Unknown skin type: $self->{'skin'}";
    }
}

=head2 st_search( $search_term, $expected_result_title )

Performs a search, and then validates the result page has the correct title.

=cut


sub st_search {
    my ($self, $opt1, $opt2) = @_;
    my $sel = $self->{selenium};
 
    $sel->type_ok('st-search-term', $opt1);
    
    if ($self->{'skin'} eq 's2') {
        $sel->click_ok('link=Search');
    } elsif ($self->{'skin'} eq 's3') {
        $sel->click_ok('st-search-submit');
    } else {
        ok 0, "Unknown skin type: $self->{'skin'}";
    }
    
    $sel->wait_for_page_to_load_ok($self->{selenium_timeout});
    
    if ($self->{'skin'} eq 's2') {
        $self->{selenium}->text_like('id=st-list-title', qr/\Q$opt2\E/);
    } elsif ($self->{'skin'} eq 's3') {
        $self->{selenium}->text_like('//div[@id=\'contentContainer\']', qr/\Q$opt2\E/);
    } else {
        ok 0, "Unknown skin type: $self->{'skin'}";
    }
}

=head2 st_result( $expected_result )

Validates that the search result content contains a correct result.

=cut

sub st_result {
    my ($self, $opt1, $opt2) = @_;

    if ($self->{'skin'} eq 's2') {
        $self->{selenium}->text_like('id=st-search-content', 
                                 $self->quote_as_regex($opt1));
    } elsif ($self->{'skin'} eq 's3') {
        $self->{selenium}->text_like('//div[@id=\'contentContainer\']', $self->quote_as_regex($opt1));
    } else {
        ok 0, "Unknown skin type: $self->{'skin'}";
    }

}

=head2 st_submit()

Submits the current form

=cut

sub st_submit {
    my ($self) = @_;

    $self->click_and_wait(q{//input[@value='Submit']}, 'click submit button');
}

=head2 st_message()

Verifies an error or message appears.

=cut

sub st_message {
    my ($self, $message) = @_;

    $self->text_like(q{errors-and-messages},
                     $self->quote_as_regex($message));
}

=head2 st_watch_page( $watch_on, $page_name, $verify_only )

Adds/removes a page to the watchlist.

If the first argument is true, the page will be added to the watchlist.
If the first argument is false, it will be removed from the watchlist.

If the second argument is not specified, it is assumed that the browser
is already open to a wiki page, and the opened page should be watched.

If the second argument is supplied, it is assumed that the browser
is on the watchlist page, and only the given page name should be watched.

If the 3rd argument is true, only checks will be performed as to whether
the specified page is watched or not.

=cut

sub st_watch_page {
    my ($self, $watch_on, $page_name, $verify_only) = @_;
    my $expected_watch = $watch_on ? 'on' : 'off';
    my $watch_re = qr/watch-$expected_watch(?:-list)?\.gif$/;
    $page_name = '' if $page_name and $page_name =~ /^#/; # ignore comments
    $verify_only = '' if $verify_only and $verify_only =~ /^#/; # ignore comments

    unless ($page_name) {
        return $self->_watch_page_xpath("//img[\@id='st-watchlist-indicator']", 
                                        $watch_re, $verify_only);
    }

    # A page is specified, so assume we're on the watchlist page
    # We need to find which row the page we're interested in is in
    my $sel = $self->{selenium};
    my $row = 2; # starts at 1, which is the table header
    my $found_page = 0;
    (my $short_name = lc($page_name)) =~ s/\s/_/g;
    while (1) {
        my $xpath = qq{//div[\@id='st-watchlist-content']/div[$row]/div[2]/img}; 
        my $alt;
        eval { $alt = $sel->get_attribute("$xpath/\@alt") };
        last unless $alt;
        if ($alt eq $short_name) {
            $self->_watch_page_xpath($xpath, $watch_re);
            $found_page++;
            last;
        }
        else {
            warn "# Looking at watchlist for ($short_name), found ($alt)\n";
        }
        $row++;
    }
    ok $found_page, "st-watch-page $watch_on - $page_name"
        unless $ENV{ST_WF_TEST};
}

sub _watch_page_xpath {
    my ($self, $xpath, $watch_re, $verify_only) = @_;
    my $sel = $self->{selenium};

    my $xpath_src = "$xpath/\@src";
    my $src = $sel->get_attribute($xpath_src);
    if ($verify_only or $src =~ $watch_re) {
        like $src, $watch_re, "$xpath - $watch_re";
        return;
    }

    $sel->click_ok($xpath, "clicking watch button");
    my $timeout = time + $self->{selenium_timeout} / 1000;
    while(1) {
        my $new_src = $sel->get_attribute($xpath_src);
        last if $new_src =~ $watch_re;
        select undef, undef, undef, 0.25; # sleep
        if ($timeout < time) {
            ok 0, 'Timeout waiting for watchlist icon to change';
            last;
        }
    }
}

=head2 st_is_watched( $watch_on, $page_name )

Validates that the current page is or is not on the watchlist.

The logic for the second argument are the same as for st_watch_page() above.

=cut

sub st_is_watched {
    my ($self, $watch_on, $page_name) = @_;
    return $self->st_watch_page($watch_on, $page_name, 'verify only');
}


=head2 st_rm_rf( $command_options )

Runs an command-line rm -Rf command with the supplied options.

Note that this will delete files, directories, and not prompt.  Use at your own risk.

=cut

sub st_rm_rf {
    my $self = shift;
    my $options = shift;
    unless (defined $options) {
        die "parameter required in call to st_rm_rf\n";
    }
    
    _run_command("rm -Rf $options", 'ignore output');
}

=head2 st_qa_setup_reports 

Run the command-line script st_qa_setup_reports that populates reports in order to test the usage growth report

=cut

sub st_qa_setup_reports {
    _run_command("st-qa-setup-reports",'ignore output');
}

=head2 st_admin( $command_options )

Runs st_admin command line script with the supplied options.

If the export-workspace command is used, I'll attempt to remove any existing
workspace tarballs before running the command.

=cut

sub st_admin {
    my $self = shift;
    my $options = shift || '';
    my $verify = shift;
    $verify = $self->quote_as_regex($verify) if $verify;

    # If we're exporting a workspace, attempt to remove the tarball first
    if ($options =~ /export-workspace.+--workspace(?:\s+|=)(\S+)/) {
        my $tarball = "/tmp/$1.1.tar.gz";
        if (-e $tarball) {
            diag "Deleting $tarball\n";
            unlink $tarball;
        }
    }

    diag "st-admin $options";
    _run_command("st-admin $options", $verify);

    if ($ENV{ST_SKIN_NAME} and $options =~ /^\s*create.workspace/ ) {
        $options =~ /--n(?:ame)?\s+(\S*)/;   # extract the workspace name
        my $ws_name = $1;

        diag "st-admin set-workspace-config --w $ws_name skin_name $ENV{ST_SKIN_NAME}";
        _run_command("st-admin set-workspace-config --w $ws_name skin_name $ENV{ST_SKIN_NAME}");
    }
}

=head2 st_ldap( $command_options )

Runs st_bootstrap_openldap command line script with the supplied options.

If the "start" command is used, the OpenLDAP instance is fired off into the
background, which may take a second or two while we wait for it to start.

=cut

sub st_ldap {
    my $self = shift;
    my $options = shift || '';
    my $verify = shift;
    $verify = $self->quote_as_regex($verify) if $verify;

    # If we're starting up an LDAP server, be sure to daemonize it and make
    # sure that it gets fired off into the background on its own.
    if ($options eq 'start') {
        $options .= ' --daemonize';
    }

    diag "st-ldap $options";
    _run_command("./dev-bin/st-bootstrap-openldap $options", $verify);
}

=head2 st_config( $command_options )

Runs st_config command line script with the supplied options.

=cut

sub st_config {
    my $self = shift;
    my $options = shift || '';
    my $verify = shift;
    $verify = $self->quote_as_regex($verify) if $verify;

    diag "st-config $options";
    _run_command("st-config $options", $verify);
}

=head2 st_admin_export_workspace_ok( $workspace )

Verifies that a workspace tarball was created.

The workspace parameter is optional.

=cut

sub st_admin_export_workspace_ok {
    my $self = shift;
    my $workspace = shift || $self->{workspace};
    my $tarball = "/tmp/$workspace.1.tar.gz";
    ok -e $tarball, "$tarball exists";
}

=head2 st_import_workspace( $options, $verify )

Imports a workspace from a tarball.  If the import is successful,
a test passes, if not, it fails.  The output is checked against
$verify.

C<$options> are passed through to "st-admin import-workspace"

=cut

sub st_import_workspace {
    my $self = shift;
    my $options = shift || '';
    my $verify = $self->quote_as_regex(shift);

    _run_command("st-admin import-workspace $options", $verify);
}

=head2 st_force_confirmation( $email, $password )

Forces confirmation of the supplied email address, and sets the user's
password to the second option.

=cut

sub st_force_confirmation {
    my ($self, $email, $password) = @_;

    require Socialtext::User;
    Socialtext::User->new(username => $email)->confirm_email_address();
    $self->st_admin("change-password --email '$email' --password '$password'",
                    'has been changed');
}

=head2 st_open_confirmation_uri

Open the correct url to confirm an email address.

=cut

sub st_open_confirmation_uri {
    my ($self, $email) = @_;

    require Socialtext::User;
    my $uri = Socialtext::User->new(username => $email)->confirmation_uri();
    # strip off host part
    $uri =~ s#.+(/nlw/submit/confirm)#$1#;
    $self->{selenium}->open_ok($uri);
}

=head2 st_should_be_admin( $email, $should_be )

Clicks the admin check box to for the given user.

=cut

sub st_should_be_admin {
    my ($self, $email, $should_be) = @_;
    my $method = ($should_be ? '' : 'un') . 'check_ok';
    $self->_click_user_row($email, $method, '/td[3]/input');
}

=head2 st_click_reset_password( $email )

Clicks the reset password check box to for the given user.

Also verifies that the checkbox is no longer checked.

=cut

sub st_click_reset_password {
    my ($self, $email, $should_be) = @_;
    my $chk_xpath = $self->_click_user_row($email, 'check_ok', '/td[4]/input');
    ok !$self->is_checked($chk_xpath), 'reset password checkbox not checked';
}


=head2 st_catchup_logs
  Runs the script to import the nlw_log into the reports database
=cut

sub st_catchup_logs {
   if (Socialtext::AppConfig::_startup_user_is_human_user()) {
       #In Dev Env
       my $current_dir = cwd;
       my $new_dir =  $ENV{ST_CURRENT} . "/socialtext-reports/";
       chdir($new_dir);
       my $str = $ENV{ST_CURRENT} . "/socialtext-reports/parse-dev-env-logs /var/log/nlw.log 2>&1";
       shell_run($str);
       chdir($current_dir);
   } else {
      #On An Appliance
      shell_run("sudo /usr/bin/st-reports-consume-access-log /var/log/apache-perl/access.log >> /var/log/st-reports.log 2>&1");
      shell_run("sudo /usr/bin/st-reports-consume-nlw-log /var/log/nlw.log >> /var/log/st-reports.log 2>&1");
   }
}


sub _click_user_row {
    my ($self, $email, $method_name, $click_col) = @_;
    my $sel = $self->{selenium};

    my $row = 1;
    my $chk_xpath;
    while(1) {
        $row++;
        my $row_email = $sel->get_text("//tbody/tr[$row]/td[2]");
        diag "row=$row email=($row_email)";
        last unless $row_email;
        next unless $email and $row_email =~ /\Q$email\E/;
        $chk_xpath = "//tbody/tr[$row]$click_col";
        
        $sel->$method_name($chk_xpath);
        if ($self->{'skin'} eq 's3') {
            $self->click_and_wait('link=Save');
            $sel->text_like('contentContainer', qr/\QChanges Saved\E/);
         } elsif ($self->{'skin'} eq 's2') {
            $self->click_and_wait('Button');
            $sel->text_like('st-settings-section', qr/\QChanges Saved\E/);
         } else {
            ok 0, "Unknown skin type: $self->{'skin'}";
        }
        return $chk_xpath;
    }
    ok 0, "Could not find '$email' in the table";
    return;
}

sub _run_command {
    my $command = shift;
    my $verify = shift || '';
    my $output = qx($command 2>&1);
    return if $verify eq 'ignore output';

    if ($verify) {
        like $output, $verify, $command;
    }
    else {
        warn $output;
    }
}

=head1 AUTHOR

Luke Closs, C<< <luke.closs at socialtext.com> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-socialtext-editpage at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Socialtext-WikiTest>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Socialtext::WikiFixture::Socialtext

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Socialtext-WikiTest>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Socialtext-WikiTest>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Socialtext-WikiTest>

=item * Search CPAN

L<http://search.cpan.org/dist/Socialtext-WikiTest>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2006 Luke Closs, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
