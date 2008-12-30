# @COPYRIGHT@
package Socialtext::Formatter::LiteLinkDictionary;
use base 'Socialtext::Formatter::LinkDictionary';

use strict;
use warnings;

use Class::Field qw'field';

field free         => '%{page_uri}';
field interwiki    => '/lite/page/%{workspace}/%{page_uri}%{section}';
field interwiki_edit    => '/lite/page/%{workspace}/%{page_uri}%{section}?action=edit';
field interwiki_edit_incipient    => '/lite/page/%{workspace}/%{page_uri}%{section}?action=edit;is_incipient=1';
field search_query =>
    '/lite/search/%{workspace}?search_term=%{search_term}';
field category_query =>
    '/lite/changes/%{workspace}/%{category}';
field recent_changes_query => '/lite/changes/%{workspace}';
field category             =>
    '/lite/category/%{workspace}/%{category}';
field weblog             =>
    '/lite/changes/%{workspace}/%{category}';
# special_http and file and image are default

sub format_link {
    my $self   = shift;
    my %p      = @_;
    my $method = $p{link};

    # Fix {bz: 1838}: Normal link dictionary uses "is_incipient=1" to signify
    # incipient pages meant for editing, but in Lite mode we should simply
    # enter Edit mode with "?action=edit".
    if ($method eq 'free') {
        $p{page_uri} =~ s{
            ^
            (.*[;&])?
            page_name=([^;&]+)
            .*
        }{
            (index($1, 'is_incipient=1') >= 0)
                ? "$2?action=edit"
                : $2
        }sex;
    }

    $self->SUPER::format_link(%p);
}

1;
