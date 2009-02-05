#!perl
# @COPYRIGHT@
use strict;
use warnings;

# use Test::Socialtext tests => 12;
use Test::Base;
use Socialtext::WikiText::Parser::Signals;
use Socialtext::WikiText::Emitter::Signals::HTML;
use WikiText::WikiByte::Emitter;

filters {
    wikitext => 'format',
};

run_is wikitext => 'html';

sub format {
    my $parser = Socialtext::WikiText::Parser::Signals->new(
       receiver => Socialtext::WikiText::Emitter::Signals::HTML->new,
#        receiver => WikiText::WikiByte::Emitter->new,
    );
    return $parser->parse($_);
}

__DATA__
=== Strikethrough phrase wikitext not supported
--- wikitext: I mean to say -hello- goodbye.
--- html: I mean to say -hello- goodbye.

=== Plain is plain
--- wikitext: Plain text is plain text!
--- html: Plain text is plain text!

=== Link to a page with workspace and text override
--- wikitext: Check out "my idea"{link: admin [Foo]} FTW!
--- html: Check out <a href="/admin/index.cgi?foo">my idea</a> FTW!

=== Link to a page without text override
--- wikitext: Check out {link: admin [Foo]} FTW!
--- html: Check out <a href="/admin/index.cgi?foo">Foo</a> FTW!

=== Invalid wafl phrase with arguments
--- wikitext: The wafl {foo: bar baz} is invalid.
--- html: The wafl {foo: bar baz} is invalid.

=== Invalid wafl phrase without arguments
--- wikitext: The wafl {toc} is invalid.
--- html: The wafl {toc} is invalid.

=== Invalid wafl phrase without arguments, but with colon and spaces
--- wikitext: The wafl {toc  :    } is invalid.
--- html: The wafl {toc} is invalid.

=== Wikitext with extra spaces
--- SKIP
Fix later...
--- wikitext: The    time   is  now.
--- html: The time is now.

=== Link with many words
--- SKIP
name_to_id should call real method in Socialtext::Page(s)
--- wikitext: Read {link: admin [The Page Name]} now
--- html: Read <a href="/admin/index.cgi?the_page_name">The Page Name</a> now

