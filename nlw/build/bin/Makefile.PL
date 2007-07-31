#!/usr/bin/env perl
# @COPYRIGHT@
use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Spec::Functions qw(catfile catdir updir);
use ExtUtils::MakeMaker qw(WriteMakefile prompt);
use ExtUtils::Command qw(mkpath);
use Getopt::Long;

# Global settings
my $TMPDIR = "build/tmp";
my $MAKEFILE = "$TMPDIR/Makefile.perl";
my $DEV_BIN = catdir(dirname(__FILE__), updir, updir, 'dev-bin');

my @original_argv = @ARGV;

my %option;
$option{'socialtext-open'} = 0;

GetOptions(
    \%option,
    'socialtext-open:i',
    'dev:i',
    'quiet',
    'verbose',
);

my $LIST_DEPS
   = "$^X $DEV_BIN/list-module-deps --socialtext-open=$option{'socialtext-open'}";

@ARGV = grep { !/^--/ } @ARGV;

my $prereqs = do {
    my $VAR1; # Data::Dumper gives us "$VAR1 = { hash guts }"
    eval qx($LIST_DEPS --dump);
};

CREATE_TMP: {
    # This is how ExtUtils::Command does it: files thru @ARGV
    local @ARGV = ($TMPDIR);
    mkpath();
}

my $mm_args = {
    NAME         => 'Socialtext-Open',
    ABSTRACT     => 'Socialtext Open',
    AUTHOR       => 'Socialtext <socialtext@socialtext.com>',
    VERSION_FROM => 'lib/Socialtext.pm',
    EXE_FILES    => [ chomp_list(qx($DEV_BIN/perl-bin-files bin/)) ],
    PREREQ_FATAL => 1,
    PREREQ_PM    => $prereqs,
    PL_FILES     => {},
    MAKEFILE     => $MAKEFILE,
    NO_META      => 1,  # No META.yml
    dist => {
        DIST_CP => 'cp', # Has to be cp, not best or ln, because we modify the written files
    },
    clean => {
        FILES => 'Socialtext-Open* share/wsdl/0.9.wsdl.test',
    },
};

# Generate Makefile
eval { WriteMakefile( %$mm_args ) };

if ( $@ ) {
    die "$@\n" unless $@ =~ /prereq/i;
    my $error = $@;
    install_deps();  # Only returns if user chooses not to install deps.
    die "$error\n";
}
munge_makefile();

# Install missing dependencies
sub install_deps {
    my @missing = chomp_list(qx($LIST_DEPS -u));
    if (@missing) {
        print "The following modules are missing, or you may have older versions:\n\n";
        print_cols( @missing );
        print "\n";
        my $ans = prompt("Install these missing dependencies from CPAN?", "y");
        if ( $ans =~ /^y(es)?$/i ) {
            s/\s.*// for @missing; # Chomp the trailing version number
            system( 'sudo', $^X, '-MCPAN', '-e', 'CPAN::Shell->install(@ARGV)',
                @missing );
            my $rc = $? >> 8;
            if ($rc == 1) {
                print "\nSudo returned 1.  No permission to install dependencies.\n\n";
                return;
            }
            # Rerun this script to recheck prereqs.  Can't just call WriteMakefile
            # again b/c MakeMaker breaks.
            exec($^X, $0, @original_argv);
        }
    }
}

sub print_cols {
    my @list = @_;

    my $width = 0;
    for (@list) {
        $width = length if $width < length;
    }
    my $maxcols = int(78/$width);

    my $ncols = int((@list-1)/10)+1;
    $ncols = $maxcols if $ncols > $maxcols;

    my $nrows = int((@list-1)/$ncols)+1;

    my @cols;
    for my $colno ( 1..$ncols ) {
        push( @cols, [ splice(@list,0,$nrows) ] );
    }

    my $mask = join( "  ", ("%-${width}.${width}s")x$ncols );
    for my $rowno ( 0..$nrows-1 ) {
        my @row = map { defined($_) ? $_ : "" } map { shift @{$cols[$_]} } 0..$ncols - 1;
        printf( "  $mask\n", @row );
    }
}

# If you chomp() a list, each element is chomped, and the total number of
# characters removed is returned.  chomp_list() is similar 'cept it returns
# the modified list instead.
sub chomp_list {
    map { chomp; $_ } (@_);
}

# Non-portable, but better than 'which' or some of the other options.
sub check_for_file_in_path {
    my $file = shift;
    foreach my $path ( split( ':', $ENV{PATH} ) ) {
        return $path if ( -x catfile( $path, $file ) );
    }
    return 0;
}

# MakeMaker *really* wants the Makefile.PL to be in the CWD, but it is not
# going to be.  So munge the generated Makefile to point to the real location
# of the Makefile.PL.
sub munge_makefile {
    my $this_file = abs_path( dirname(__FILE__) );
    my @lines     = slurp($MAKEFILE);
    spew( $MAKEFILE, map { s/Makefile\.PL/$this_file/g; $_ } @lines );
}

sub slurp {
    my $file = shift;
    open my $fh, '<', $file or die "Could not open $file for reading: $!\n";
    my @lines = <$fh>;
    close($fh);
    return @lines;
}

sub spew {
    my ($file, @lines) = @_;
    open my $fh, '>', $file or die "Could not open $file for writing: $!\n";
    print $fh @lines;
    close($fh);
}

# Override some behaviors so "tardist" can handle files with spaces.
package MY;
sub distdir {
    my $inherited = shift->SUPER::distdir(@_);
    chomp($inherited);
    $inherited .= <<ADDON;
\tgrep '^#-#' MANIFEST | cut -f 3- -d '#' | while read f; do \\
\t   install -D "\$\$f" "\$(DISTVNAME)/\$\$f"; \\
\tdone
\tchmod -R u+w \$(DISTVNAME)
\tbuild/bin/fill-in-copyright \$(DISTVNAME)
\t# Force the permissions of the files in the temp dir to match the originals
\tfind . -type f | grep -v .svn | grep -v "\$(DISTVNAME)" | while read f; do \\
\t   if [ -e "\$(DISTVNAME)/\$\$f" ]; then \\
\t       chmod -c --reference="\$\$f" "\$(DISTVNAME)/\$\$f"; \\
\t   fi \\
\tdone
ADDON
}

sub MY::libscan {
    my $self = shift;
    my $path = shift;

    $path = $self->SUPER::libscan($path);

    # Make sure no template modules get installed
    return '' if $path =~ /\.in$/;
    return $path;
};
