# @COPYRIGHT@
package Socialtext::Handler::Category::Full;
use strict;
use warnings;

use base 'Socialtext::Handler::Category';

sub _category_html {
    my $class    = shift;
    my $r        = shift;
    my $nlw      = shift;
    my $category = shift;

    my $category_plugin = $nlw->hub->category;

    if ($category) {
        $nlw->hub->action('category_display');
        return $category_plugin->category_display($category);
    }
    else {
        $nlw->hub->action('category_list');
        return $category_plugin->category_list($category);
    }

}

1;

__END__

=head1 NAME

Socialtext::Handler::Category::Full - A part of a Cool URI Interface to NLW with a complex user interface

=head1 SYNOPSIS

    <Location /category>
        SetHandler  perl-script
        PerlHandler +Socialtext::Handler::Category::Full
    </Location>

=head1 DESCRIPTION

=head1 URIs

A URI for categories takes the form C</category/workspace_id/category_id>, where
category_id is optional. If not there, a list of categories is provided.

=cut

