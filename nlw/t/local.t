#!perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Socialtext tests => 7;
fixtures( 'admin_no_pages' );

=head1 DESCRIPTION

Verify that various 'local override' directories are observed.

=cut

use Socialtext::AppConfig;
use File::Path;

my $hub = new_hub('admin');
isa_ok( $hub, 'Socialtext::Hub' );

test_templates();
test_css();

sub test_templates {
    my $template_dir  = Socialtext::AppConfig->code_base . '/skin/s2/template';
    my $local_dir     = "$template_dir/local";

    {
        my $template_name = 'test-template';
        my $orig_path  = "$template_dir/$template_name";
        my $local_path = "$local_dir/$template_name";

        unlink $local_path; # in case a previous test instance crashed
        write_to( $orig_path, 'xyzzy' );
        my $output = $hub->template->render($template_name);

        is( $output, 'xyzzy', "Original template renders correctly." );
    }

    {
        my $template_name = 'test-template2';
        my $orig_path  = "$template_dir/$template_name";
        my $local_path = "$local_dir/$template_name";

        mkpath( [$local_dir] );
        write_to( $orig_path, 'xyzzy' );
        write_to( $local_path, 'fnord' );
        my $output = $hub->template->render($template_name);

        is( $output, 'fnord', "Overridden template renders correctly." );

        unlink $orig_path, $local_path;
    }
}

sub test_css {
    my $css_dir   = $hub->css->RootDir . "/st";
    my $local_dir = $hub->css->RootDir . "/local";
    my $file      = 'screen.css';

    my $orig_path  = "$css_dir/$file";
    my $local_path = "$local_dir/$file";
    unlink $local_path; # in case a previous test instance crashed
    is(
        scalar grep( m{s2/css/screen\.css}, $hub->css->uris ),
        1,
        'Normal screen.css is present at start.'
    );

   is(
       scalar grep( m{css/local/screen\.css}, $hub->css->uris),
       0,
       'Local screen.css is absent at start.'
   );

   mkpath( [$local_dir] );
   write_to( $local_path, '' );
   # Generate new Socialtext::CSS object to simulate what a new process would see.
   $hub->css(Socialtext::CSS->new(hub => $hub));
   is(
       scalar grep( m{css/nlw/screen\.css}, $hub->css->uris ),
       0,
       'Normal screen.css is missing when local/screen.css is on the disk.'
   );

   is(
       scalar grep( m{local/screen\.css}, $hub->css->uris ),
       1,
       'Local screen.css is picked up when local/screen.css is on the disk.'
   );

   unlink $local_path;
}

sub write_to {
    my ( $path, $contents ) = @_;

    open my $fh, '>', $path or die "$path: $!";
    print ${fh} $contents or die "$path: $!";
    close ${fh} or die "$path: $!";
}
