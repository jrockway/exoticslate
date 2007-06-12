# @COPYRIGHT@
package Socialtext::Handler::Changes::Lite;
use strict;
use warnings;

use Apache;
use base 'Socialtext::Handler::Changes';

use Socialtext::Lite;

sub _changes_html {
    my $class    = shift;
    my $r        = shift;
    my $nlw      = shift;
    my $category = shift;
    return Socialtext::Lite->new( hub => $nlw->hub )->recent_changes($category);
}

1;

__END__

=head1 NAME

Socialtext::Handler::Changes::Lite - A part of a Cool URI Interface to NLW with a minimal interface

=head1 SYNOPSIS

    <Location /lite/changes>
        SetHandler  perl-script
        PerlHandler +Socialtext::Handler::Changes::Lite
    </Location>

=head1 DESCRIPTION

=head1 URIs

A URI for changes takes the form C</lite/changes/workspace_id/category_id>. Category_id is optional.

=cut

