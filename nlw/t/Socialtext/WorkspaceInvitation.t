#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext;
BEGIN {
    unless ( eval { require Email::Send::Test; 1 } ) {
        plan skip_all => 'These tests require Email::Send::Test to run.';
    }
}

plan tests => 18;

use Socialtext::User;
use Socialtext::Workspace;

BEGIN {
    use_ok( 'Socialtext::WorkspaceInvitation' );
}


# fixtures( 'rdbms_clean' );
fixtures( 'admin_no_pages' );

$Socialtext::EmailSender::Base::SendClass = 'Test';

my $admin_workspace = Socialtext::Workspace->new( name => 'admin' );
my $current_user    = Socialtext::User->new( username => 'devnull1@socialtext.com' );

my $invitation = Socialtext::WorkspaceInvitation->new( workspace => $admin_workspace,
                                                       from_user => $current_user,
                                                       invitee   => 'devnull7@socialtext.com',
                                                     );

eval { $invitation->send(); };

my $e = $@;
is( $e, '', "send without exception" );


my @cases = ( { label        => 'non-appliance',
                is_appliance => 0,
                username     => 'devnull8@socialtext.com',
                tests        => [ qr/From: devnull1\@socialtext\.com/,
                                  qr/to join Admin Wiki/,
                                  qr{/submit/confirm_email},
                                ],
              },
              { label        => 'non-appliance has account',
                is_appliance => 0,
                username     => 'devnull8@socialtext.com',
                tests        => [ qr/already have a Socialtext account/,
                                ],
              },
              { label        => 'appliance',
                is_appliance => 1,
                username     => 'devnull9@socialtext.com',
                tests        => [ qr/I'm inviting you/,
                                  qr{/submit/confirm_email},
                                ],
              },
              { label        => 'appliance has account',
                is_appliance => 1,
                username     => 'devnull9@socialtext.com',
                tests        => [ qr/already have a Socialtext Appliance account/,
                                ],
              }
            );


for my $c (@cases) {
    print "# Starting test $c->{label}\n";

    local $SIG{__DIE__};
    local $ENV{NLW_IS_APPLIANCE} = $c->{is_appliance};

    Email::Send::Test->clear;

    my $invitation =
      Socialtext::WorkspaceInvitation->new(
                                           workspace => $admin_workspace,
                                           from_user => $current_user,
                                           invitee   => $c->{username},
                                          );

    $invitation->send() ;

    my $expected = 0;
    if( _confirm_user_if_neccessary( $c->{username} ) ) {
        $expected = 2;
    } else {
        $expected = 1;
    }

    my @emails = Email::Send::Test->emails;
    is scalar @emails, $expected, "$expected email(s) were sent: $c->{label}";
    for my $rx ( @{ $c->{tests} } ) {
        like( $emails[0]->as_string, $rx,
              "$c->{label} - email matches $rx" );
    }
};

my $hub = new_hub('admin');
my $viewer = $hub->viewer;
ok( $viewer, "viewer acquired" );
{
    Email::Send::Test->clear;

    # my $user = _user('devnull9@socialtext.com');

    my $extra_text = <<'EOF';
Here is a paragraph of text. Lalalala.

* A list
* Item 2

Another paragraph.
EOF

    my $invitation =
      Socialtext::WorkspaceInvitation->new(
                                           workspace  => $admin_workspace,
                                           from_user  => $current_user,
                                           invitee    => 'devnull9@socialtext.com',
                                           extra_text => $extra_text,
                                           viewer => $viewer,
                                          );

    $invitation->send();

    my @emails = Email::Send::Test->emails;

    is( scalar @emails, 1, 'one email was sent' );

    my $plain_body = ( $emails[0]->parts() )[0]->body();
    like( $plain_body, qr/Here is a paragraph/,
          'plain body contains extra text' );
    like( $plain_body, qr/\* A list/,
          'plain body contains list in extra text verbatim' );

    my $html_body = ( $emails[0]->parts() )[1]->body();
    like( $html_body, qr{<p>\s*Here is a paragraph[^<]+</p>}s,
          'html body contains extra text as html' );
    like( $html_body, qr{<li>\s*A list},
          'html body contains list items' );
}

sub _confirm_user_if_neccessary {
    my $username = shift;

    my $user = Socialtext::User->new( username => $username );
    warn "_confirm_user_if_necessary($username) - $user";

    if ($user && $user->requires_confirmation ) {
        print "# Confirming user $username\n";
        $user->confirm_email_address();
        $user->update_store( password => 'secret' );
        return 1;
    }
    return 0;
}
