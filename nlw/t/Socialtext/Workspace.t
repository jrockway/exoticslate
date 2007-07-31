#!perl
# @COPYRIGHT@
use Test::Socialtext tests => 90;

use strict;
use warnings;

fixtures( 'rdbms_clean', 'help' );

use mocked qw(Socialtext::l10n system_locale);

use Socialtext::EmailAlias;
use Socialtext::File;
use Socialtext::Paths;
use Socialtext::Account;
use Socialtext::Workspace;

my $has_image_magick = eval { require Image::Magick; 1 };

{
    is( Socialtext::Workspace->Count(), 1, 'Only help workspace in DBMS yet' );
}

{
    my $ws = Socialtext::Workspace->create(
        name       => 'short-name',
        title      => 'Longer Title',
        account_id => Socialtext::Account->Socialtext()->account_id,
    );
    isa_ok( $ws, 'Socialtext::Workspace' );

    is( $ws->name,  'short-name',   'name of new workspace is short-name' );
    is( $ws->title, 'Longer Title', 'title of new workspace is Longer Title' );
    is( $ws->account->name, 'Socialtext',
        'name of account for workspace is SOcialtext' );
    ok( $ws->email_notify_is_enabled,
        'new workspace defaults to email notify enabled' );
    is( $ws->created_by_user_id, Socialtext::User->SystemUser()->user_id(),
        'creator is system user' );
    is( $ws->account_id, Socialtext::Account->Socialtext()->account_id(),
        'account id is for Socialtext account' );
    is( Socialtext::User->SystemUser()->workspace_count(), 0,
        'system user is not in any workspaces' );
    ok( Socialtext::EmailAlias::find_alias( $ws->name ), 'found alias for new workspace' );

    is( Socialtext::Workspace->Count(), 2, 'workspace count is 2' );

    my $hostname = Socialtext::AppConfig->web_hostname;
    like( $ws->uri, qr{\Qhttp://$hostname/short-name/\E}i,
          'check workspace uri' );

    for my $dir (
        Socialtext::Paths::page_data_directory('short-name'),
        Socialtext::Paths::plugin_directory('short-name'),
        Socialtext::Paths::user_directory('short-name'),
    ) {
        ok( -d $dir, "$dir exists after workspace is created" );
    }

    my $page_dir =
        Socialtext::File::catdir( Socialtext::Paths::page_data_directory('short-name'), 'quick_start' );
    ok( -d $page_dir, "$page_dir exists after workspace is created" );
}

{
    eval {
        Socialtext::Workspace->create(
            name                     => 'short-name',
            title                    => undef,
            incoming_email_placement => 'foobar',
            skin_name                => 'does-not-exist',
        );
    };
    my $e = $@;
    check_errors($e);
    ok( ( grep { /account must be specified/ } $e->messages ),
        'got error message saying account is required' );
}

{
    Socialtext::Workspace->create(
        name       => 'short-name-2',
        title      => 'Longer Title 2',
        account_id => Socialtext::Account->Socialtext()->account_id,
    );
    my $ws = Socialtext::Workspace->new( name => 'short-name' );

    eval {
        $ws->update(
            title                    => undef,
            incoming_email_placement => 'foobar',
            skin_name                => 'does-not-exist',
        );
    };
    check_errors($@);
}

{
    my $ws = Socialtext::Workspace->new( name => 'short-name' );
    $ws->delete;

    for my $dir (
        Socialtext::Paths::page_data_directory('short-name'),
        Socialtext::Paths::plugin_directory('short-name'),
        Socialtext::Paths::user_directory('short-name'),
    ) {
        ok( ! -d $dir, "$dir does not exist after workspace is deleted" );
    }

    ok( ! Socialtext::EmailAlias::find_alias('short-name'),
        'alias for short-name-2 does not exist after workspace is deleted' );
}

INHERITING_WORKSPACE_INVITE:
{
    my $ws = Socialtext::Workspace->create(
        name                => 'invite-inherit',
        title               => 'Invitation Inheritance',
        account_id          => Socialtext::Account->Socialtext()->account_id,
        invitation_template => 'my_template',
        invitation_filter => 'friends',
        restrict_invitation_to_search => '1',
    );

    is(
        $ws->invitation_filter, 'friends',
        "Workspace inherited the invitation filter correctly\n"
    );
    is(
        $ws->invitation_template, 'my_template',
        "Workspace inherited the invitation template correctly\n"
    );
    is(
        $ws->restrict_invitation_to_search, '1',
        "Workspace inherited the invitation search restriction correctly\n"
    );
}

EMAIL_NOTIFICATION_FROM_ADDRESS:
{
    my $ws = Socialtext::Workspace->create(
        name       => 'email-address-test',
        title      => 'The Workspace Title',
        account_id => Socialtext::Account->Socialtext()->account_id,
    );

    is( $ws->email_notification_from_address(),
        'noreply@socialtext.com',
        'default from address is noreply@socialtext.com' );

    is( $ws->formatted_email_notification_from_address(),
        '"The Workspace Title" <noreply@socialtext.com>',
        'formatted default from address includes workspace title and noreply@socialtext.com' );

    $ws->update( email_notification_from_address => 'bob@example.com' );

    is( $ws->email_notification_from_address(),
        'bob@example.com',
        'default from address now bob@example.com' );

    is( $ws->formatted_email_notification_from_address(),
        '"The Workspace Title" <bob@example.com>',
        'formatted default from address now includes workspace title and bob@example.com' );

    # Tests RT #21870
    $ws->update( title => q{Title with, a comma} );

    is( $ws->email_notification_from_address(),
        'bob@example.com',
        'default from address still just bob@example.com' );

    is( $ws->formatted_email_notification_from_address(),
        q{"Title with, a comma" <bob@example.com>},
        'default from address includes workspace title and bob@example.com' );
}

sub check_errors {
    my $e = shift;
    ok( $e,
        'got an error after giving bad data to Socialtext::Workspace->create'
    );

    for my $regex (
        qr/one of top, bottom, or replace/,
        qr/title is a required field/,
        ) {
            my $errors = join ', ', $e->messages;           
            like $errors, $regex, "got error message matching $regex";
    }

 TODO:
    {
        local $TODO = 'Skins are not yet checked';
        my $regex = qr/skin you specified/;
        ok( ( grep {/$regex/} $e->messages ),
            "got error message matching $regex" );
    }
}

{
    eval {
        Socialtext::Workspace->create(
            name                     => 'a',
            title                    => 'b',
            incoming_email_placement => 'foobar',
            skin_name                => 'does-not-exist',
        );
    };
    my $e = $@;
    ok( ( grep {/3 and 30/} $e->messages ),
        'name < 3 characters is not allowed' );
    ok( ( grep {/2 and 64/} $e->messages ),
        'title < 2 characters is not allowed' );
}

{
    eval {
        Socialtext::Workspace->create(
            name  => '123456789012345678901234567890A',
            title =>
                '1234567890123456789012345678901234567890123456789012345678901234A',
            incoming_email_placement => 'foobar',
            skin_name                => 'does-not-exist',
        );
    };
    my $e = $@;
    ok( ( grep {/3 and 30/} $e->messages ),
        'name > 30 characters is not allowed' );
    ok( ( grep {/2 and 64/} $e->messages ),
        'title > 64 characters is not allowed' );
}

{
    my $ws = Socialtext::Workspace->create(
        name       => 'logo-test',
        title      => 'logo testing',
        account_id => Socialtext::Account->Socialtext()->account_id,
    );

    eval { $ws->update( logo_uri => '/foo/bar.png' ) };
    like( $@, qr/cannot set logo_uri/i, 'cannot set logo_uri directly via update()' );

    my $file = 't/extra-attachments/FormattingTest/thing.png';
    open my $fh, '<', $file
        or die "Cannot read $file";
    $ws->set_logo_from_filehandle(
        filehandle => $fh,
        filename   => $file,
    );
    like( $ws->logo_uri, qr{/logos/logo-test/logo-test-.+\.png$},
          'logo uri has been updated' );
    ok( -f $ws->logo_filename, 'saved logo file exists' );

    eval {
        $ws->set_logo_from_filehandle(
            filehandle => $fh,
            filename   => 'foobar.notanimage',
        );
    };
    like(
        $@, qr/must be a gif.+/,
        'cannot set the logo when the extension is not a recognized file type'
    );

    ok( -f $ws->logo_filename,
        'old logo was not deleted when trying to set an invalid logo' );

    # test a text file posing as an image
    my $text_file = 't/attachments/foo.txt';
    open my $text_fh, '<', $text_file
        or die "Cannot read $text_file";
    eval {
        $ws->set_logo_from_filehandle(
            filehandle => $text_fh,
            filename   => 'foo.png',
        );
    };

    SKIP: {
        skip 'Image::Magick not installed.', 1 unless $has_image_magick;
        like(
            $@, qr/Unable to process logo file\. Is it an image\?/,
            'cannot set logo with non image file posing as one'
        );
    }

    $ws->set_logo_from_uri( uri => 'http://example.com/image.png' );
    is( $ws->logo_uri, 'http://example.com/image.png', 'logo_uri has changed' );
    is( $ws->logo_filename, undef, 'logo_filename is now undef' );
}

{
    my $user = Socialtext::User->SystemUser;
    my $ws = Socialtext::Workspace->new( name => 'short-name-2' );

    eval { $ws->assign_role_to_user(
               user => $user,
               role => Socialtext::Role->Member(),
           ) };
    like( $@, qr/system-created/, 'system user cannot be assigned a role in a workspace' );
    is( $user->workspace_count, 0, 'workspace count for system user is 0' );
}

{
    my $user = Socialtext::User->create(
        username      => 'devnull11@socialtext.com',
        email_address => 'devnull11@socialtext.com',
        password      => 'd3vnu11l',
    );
    my $ws = Socialtext::Workspace->new( name => 'short-name-2' );

    eval { $ws->assign_role_to_user(
               user => $user,
               role => Socialtext::Role->Guest(),
           ) };
    like( $@, qr/cannot explicitly assign/i, 'cannot assign the guest role' );

    eval { $ws->assign_role_to_user(
               user => $user,
               role => Socialtext::Role->AuthenticatedUser(),
           ) };
    like( $@, qr/cannot explicitly assign/i, 'cannot assign the authenticated user role' );
}

{
    my $user = Socialtext::User->new( username => 'devnull11@socialtext.com' );
    my $ws = Socialtext::Workspace->create(
        name               => 'short-name-3',
        title              => 'Longer Title 3',
        created_by_user_id => $user->user_id,
        account_id         => Socialtext::Account->Socialtext()->account_id,
    );

    is( $user->workspace_count, 1, 'devnull1 is in one workspace' );
    is( $user->workspaces()->next()->workspace_id(), $ws->workspace_id(),
        'devnull1 is in the workspace that was just created' );
    ok( $ws->user_has_role( user => $user, role => Socialtext::Role->WorkspaceAdmin() ),
        'devnull1 is a workspace admin in the workspace that was just created' );
}

{
    my $ws = Socialtext::Workspace->create(
        name       => 'short-name-4',
        title      => 'Longer Title 4',
        account_id => Socialtext::Account->Socialtext()->account_id,
    );

    {
        my @uris = ( 'http://example.com/ping', 'http://example.com/ping2' );
        $ws->set_ping_uris( uris => \@uris );

        is_deeply( [ sort $ws->ping_uris ], \@uris,
                   'ping uris matches what was just set', );
    }

    {
        my @uris = ( 'https://example.com/ping3', 'https://example.com/ping3' );
        $ws->set_ping_uris( uris => \@uris );
        is( $ws->ping_uris, 'https://example.com/ping3',
            'set_ping_uris discards duplicates, allows https' );
    }

    {
        my @uris = ( 'file:///etc/hostname', 'http://example.com/ping3' );
        eval { $ws->set_ping_uris( uris => \@uris ) };
        like( $@, qr{file:///.+not a valid},
              'cannot use non http(s) URIs for pings' );
    }
}

{
    Socialtext::EmailAlias::create_alias( 'has-alias' );
    eval { Socialtext::Workspace->create(
               name         => 'has-alias',
               title        => 'Has an alias',
               account_id   => Socialtext::Account->Socialtext()->account_id,
           ) };
    ok( $@, ' alias matching the ws name already existed' );
    ok( ! Socialtext::Workspace->new( name => 'has-alias' ),
        'The has-alias workspace exists' );
}

{
    Socialtext::Workspace->create(
        name               => 'no-pages',
        title              => 'No Pages',
        account_id         => Socialtext::Account->Socialtext()->account_id,
        skip_default_pages => 1,
    );

    my $page_dir =
        Socialtext::File::catdir( Socialtext::Paths::page_data_directory('no-pages'), 'quick_start' );
    ok( ! -d $page_dir,
        "$page_dir does not exist after workspace is created with skip_default_pages flag" );
}

NON_ASCII_WS_NAME: {
    eval { Socialtext::Workspace->create(
        name               => 'high-ascii-' . Encode::decode( 'latin-1', chr(155) ),
        title              => 'A title',
        account_id         => Socialtext::Account->Socialtext()->account_id,
        skip_default_pages => 1,
    ) };
    like( $@, qr/\Qmust contain only upper- or lower-case letters/,
          'workspace name with non-ASCII letters is invalid' );
}

customjs_uri: {
    my $ws = Socialtext::Workspace->create(
        name       => 'customjs-1',
        title      => 'Custom JS 1',
        account_id => Socialtext::Account->Socialtext()->account_id,
    );
    is( $ws->customjs_uri, '', 'Default custom javascript URI is blank'),

    $ws->update(customjs_uri => 'custom.js');
    is( $ws->customjs_uri, 'custom.js', 'Custom javascript set correctly'),
}

CHANGE_WORKSPACE_TITLE: {
    my $ws = Socialtext::Workspace->create(
        name               => 'title-tester',
        title              => 'Original Title',
        account_id         => Socialtext::Account->Socialtext()->account_id,
    );

    my $main = Socialtext->new();
    my $hub  = $main->load_hub(
        current_workspace => $ws,
        current_user      => Socialtext::User->SystemUser(),
    );
    $hub->registry()->load();

    my $old_front_page = $hub->pages()->new_from_name( $ws->title() );
    ok( $old_front_page->exists(), 'Page named after workspace title exists' );

    $ws->update( title => 'My Brand New Title' );

    my $new_front_page = $hub->pages()->new_from_name( $ws->title() );
    ok( $new_front_page->exists(), 'Page named after new workspace title exists' );
    like( $new_front_page->content(), qr/home page/,
          'new front page has expected content' );

    $ws->update( title => 'Original Title' );

    $old_front_page = $hub->pages()->new_from_name( $ws->title() );
    ok( $old_front_page->exists(), 'Page named after original workspace title exists' );
    like( $old_front_page->content(), qr/home page/,
          'original front page has expected content after rename to original title' );
}

NAME_IS_VALID: {

    # Check an invalid name, then a valid name, to make
    # sure that the errors from the invalid name aren't
    # preserved between calls.
    #
    {
        Socialtext::Workspace->NameIsValid( name => 'aa');
        ok( Socialtext::Workspace->NameIsValid( name => 'valid'),
            'Errors are cleared from default error list between calls'
        );
    }

    # Make sure simple valid names work.
    #
    ok( Socialtext::Workspace->NameIsValid( name => 'valid'),
        'Valid workspace name succeeds'
    );
    
    #
    # Check length boundary conditions.
    #
    
    ok( ! Socialtext::Workspace->NameIsValid( name => 'aa'),
        'Too-short workspace name fails'
    );

    ok( ! Socialtext::Workspace->NameIsValid( name => ('a' x 31) ),
        'Too-long workspace name fails'
    );

    ok( Socialtext::Workspace->NameIsValid( name => 'aaa' ),
        'Workspace name of exactly 3 characters succeeds'
    );
    
    ok( Socialtext::Workspace->NameIsValid( name => ('a' x 30) ),
        'Workspace name of exactly 30 characters succeeds'
    );

    # 
    # Other miscellaneous problems
    #

    ok( ! Socialtext::Workspace->NameIsValid( name => q() ),
        'Blank workspace name fails'
    );

    ok( ! Socialtext::Workspace->NameIsValid( name => 'data' ),
        'Reserved word as workspace name fails'
    );

    # Check basic parameter validation
    {
        my $e;

        eval { Socialtext::Workspace->NameIsValid( name => undef ) };
        
        $e = $@;
       
        like( $e->message,
             qr/'name' parameter .+ not one of the allowed types/i, 
            'Undef workspace name generates expected exception'
        );

        eval { Socialtext::Workspace->NameIsValid( name => 'aaa', errors => '' ) };

        $e = $@;

        like( $e->message,
            qr/'errors' parameter .+ not one of the allowed types/i,
            'Undef errors array generates expected exception'
        );
    }

    # Check for specific messages in the error lists
    {
        my @errors;

        Socialtext::Workspace->NameIsValid( name => 'aa', errors => \@errors );
        ok( ( grep { qr/3 and 30/i } @errors ),
            'Expected error message was returned for too-short workspace name'
        );

        @errors = ();
        Socialtext::Workspace->NameIsValid( name => 'st_stuff', errors => \@errors );
        ok( ( grep { qr/reserved word/i } @errors ),
            'Expected error message was returned for reserved workspace name'
        );
    }

    # Check for multiple errors in a single workspace name
    {
        my @errors;
        Socialtext::Workspace->NameIsValid(
            name    => 'st_illegal/and/reserved',
            errors  => \@errors
        );

        is( scalar(@errors), 2,
            'Correct number of errors for workspace name with multiple problems'
        );
       
        ok( ( grep { qr/3 and 30/i } @errors ),
            'Error list contains length message'
        );

        ok( ( grep { qr/reserved word/i } @errors ),
            'Error list contains reserved word message'
        );
    }
}

HELP_WORKSPACE_WITH_WS_MISSING: {
    system_locale('xx');  # Set locale to xx, but help-xx doesn't exist yet.

    my $ws1 = Socialtext::Workspace->help_workspace();
    is( $ws1->name, "help-en", "help_workspace() is help-en" );

    my $ws2 = Socialtext::Workspace->new( name => "help" );
    is( $ws2->name, "help-en", "new(name => help) DTRT" );
}

HELP_WORKSPACE_WITH_WS_NOT_MISSING: {
    system_locale('xx');
    Socialtext::Workspace->create(
        name       => 'help-xx',
        title      => 'Help XX',
        account_id => Socialtext::Account->Socialtext()->account_id,
    );

    my $ws1 = Socialtext::Workspace->help_workspace();
    is( $ws1->name, "help-xx", "help_workspace() is help-xx" );

    my $ws2 = Socialtext::Workspace->new( name => "help" );
    is( $ws2->name, "help-xx", "new(name => help) DTRT" );
}
