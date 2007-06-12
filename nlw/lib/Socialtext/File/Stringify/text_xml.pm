# @COPYRIGHT@
package Socialtext::File::Stringify::text_xml;
use strict;
use warnings;

use XML::SAX::ParserFactory;
use Socialtext::File::Stringify;

sub to_string {
    my ( $class, $file ) = @_;
    my $text = "";
    my $handler
        = Socialtext::File::Stringify::text_xml::SAX->new( output => \$text );
    my $parser = XML::SAX::ParserFactory->parser( Handler => $handler );
    $parser->parse_uri($file);
    return $text
        || Socialtext::File::Stringify->to_string( $file, 'text/plain' );
}

1;

package Socialtext::File::Stringify::text_xml::SAX;
use base 'XML::SAX::Base';

sub new {
    my ( $class, %args ) = @_;
    return $class->SUPER::new(%args);
}

sub characters {
    my ( $self, $content ) = @_;
    ${ $self->{output} } .= $content->{Data} if defined $content->{Data};
}

1;
