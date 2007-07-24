# @COPYRIGHT@
package Socialtext::Handler::Category::Lite;
use strict;
use warnings;

use Apache;
use base 'Socialtext::Handler::Category';

use Socialtext::Lite;

sub _category_html {
    my $class    = shift;
    my $r        = shift;
    my $nlw      = shift;
    my $category = shift;
    return Socialtext::Lite->new( hub => $nlw->hub )->category($category);
}

1;

__END__

=head1 NAME

Socialtext::Handler::Category::Lite - A part of a Cool URI Interface to NLW with a minimal interface

=head1 SYNOPSIS

    <Location /lite/category>
        SetHandler  perl-script
        PerlHandler +Socialtext::Handler::Category::Lite
    </Location>

=head1 DESCRIPTION

=head1 URIs

A URI for changes takes the form C</lite/category/workspace_id/category_id>. Category_id is optional. If not provided, a list of categories is shown.

=cut

