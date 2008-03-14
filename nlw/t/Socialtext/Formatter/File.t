#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 2;
fixtures( 'admin_no_pages' );

# Confirm that we can create tables of contents of 
# the current page, of another page in the same workspace,
# of a page not in this workspace, but not of a page
# in which we aren't a member.

use Socialtext::Pages;

my $FILE  = 'rock#it.txt';
my $IMAGE = 'sit#start.png';

my $admin  = new_hub('admin');

my $page_one = Socialtext::Page->new( hub => $admin )->create(
    title   => 'aa page yo',
    content => <<'EOF',

Shoots brah, I'm going to attach me something here

{file rock#it.txt}
{image sit#start.png}

EOF
    creator => $admin->current_user,
);

# attach those bad boys
$admin->pages->current($page_one);
attach($FILE);
attach($IMAGE);

my $html_one
    = $admin->pages->new_from_name('aa page yo')->to_html_or_default();

like $html_one,
     qr{/data/workspaces/admin/attachments/aa_page_yo:[\d-]+/original/rock%23it\.txt"},
     'url for rock#it.txt is escaped';
like $html_one,
     qr{/data/workspaces/admin/attachments/aa_page_yo:[\d-]+/scaled/sit%23start\.png"},
     'url for sit#start.png is escaped';
exit;


sub attach {
    my $filename = shift;
    my $path = 't/attachments/' . $filename;
    open my $fh, '<', $path or die "unable to open $path $!";
    $admin->attachments->create(
        filename => $filename,
        fh => $fh,
        creator => $admin->current_user,
    );
}

