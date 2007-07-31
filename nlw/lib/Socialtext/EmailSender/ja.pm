# @COPYRIGHT@
package Socialtext::EmailSender::ja;

use strict;
use warnings;

our $VERSION = '0.01';

use base 'Socialtext::EmailSender::Base';
use Email::Valid;
use Email::MessageID;
use Email::MIME;
use Email::MIME::Creator;
use Email::Send qw();
use Email::Send::Sendmail;
use Encode         ();
use File::Basename ();
use File::Slurp    ();
use List::Util qw(first);
use MIME::Types;
use Readonly;
use Socialtext::Exceptions qw( param_error );
use Socialtext::Validate
    qw( validate SCALAR_TYPE ARRAYREF_TYPE HASHREF_TYPE SCALAR_OR_ARRAYREF_TYPE BOOLEAN_TYPE );
use charnames ":full";

use Encode::Alias;
use Encode::Unicode::Japanese;
use Lingua::JA::Fold;
use Jcode;
use Unicode::Japanese;

$Email::Send::Sendmail::SENDMAIL = '/usr/sbin/sendmail';

{

    # solve WAVE DASH problems
    define_alias( qr/iso-2022-jp$/i => '"unijp-jis"' );

    sub new {
        my $pkg = shift;
        bless {}, $pkg;
    }

    sub _convert_specification {
        my $self    = shift;
        my $text    = shift;
        $text = Unicode::Japanese->new($text)->h2zKana->get();
        return $text;
    }

    sub _encode_address {
        my $self    = shift;
        my $address = shift;
        $address = Jcode->new($address,'utf8')->mime_encode;
        return $address;
    }

    sub _encode_subject {
        my $self    = shift;
        my $subject = shift;

        # Encode::MIME::Header will buggily add extra spaces when
        # encoding, so we only encode the subject, as that is the only
        # part we think will ever need it. Dave is working on fixing
        # the bug.
        if ( $subject =~ /[\x7F-\xFF]/ ) {
            $subject = Encode::encode( 'MIME-Header', $subject );
        }
        else {

            # This shuts up a "wide character in print" warning from
            # inside Email::Send::Sendmail.
            $subject = $self->_convert_specification($subject);
            $subject = Encode::encode( 'MIME-Header-ISO_2022_JP', $subject );
        }

        return $subject;
    }

    sub _fold_body {
        my $self    = shift;
        my $body    = shift; 
        # fold line over 989bytes because some smtp server chop line over 989
        # bytes and this causes mojibake
        Encode::_utf8_on($body) unless Encode::is_utf8($body);

        my $folded_body;
        my $line_length;
        my @lines = split /\n/, $body;
        foreach my $line (@lines) {
            {
                use bytes;
                $line_length = length($line);
            }
            if($line_length > 988) {
                $line = fold( 'text' => $line, 'length' => 300 );
            }
            
            $folded_body .= $line;
            if(@lines > 1) {
                $folded_body .= "\n";
            }
        }
        $body = $folded_body;
        return $body; 
    }

    sub _text_body {
        my $self     = shift;
        my $body     = shift;
        my $encoding = shift;

        $body = $self->_convert_specification($body);
        $body = $self->_fold_body($body);
        
        # solve WAVE DASH problem
        $body =~ tr/[\x{ff5e}\x{2225}\x{ff0d}\x{ffe0}\x{ffe1}\x{ffe2}]/[\x{301c}\x{2016}\x{2212}\x{00a2}\x{00a3}\x{00ac}]/;

        $body = Encode::encode($encoding, $body);
        return $body;
    }

    sub _html_body {
        my $self     = shift;
        my $body     = shift;
        my $encoding = shift;

        $body = $self->_fold_body($body);

        # solve WAVE DASH problem
        $body =~ tr/[\x{ff5e}\x{2225}\x{ff0d}\x{ffe0}\x{ffe1}\x{ffe2}]/[\x{301c}\x{2016}\x{2212}\x{00a2}\x{00a3}\x{00ac}]/;

        $body = Encode::encode($encoding, $body);
        return $body;
    }

    sub _encode_filename {
        my $self     = shift;
        my $filename = shift;

        Encode::_utf8_off($filename) if Encode::is_utf8($filename);

        $filename = $self->_uri_unescape($filename);

        # If filename is only ascii code, you do not encode fileme to MIME-B.
        $filename = Encode::encode( 'MIME-Header-ISO_2022_JP', $filename );

        return $filename;
    }

    sub _get_encoding {
        return 'iso-2022-jp';
    }

    sub _uri_unescape {
        my $self = shift;
        my $data = shift;
        $data = URI::Escape::uri_unescape($data);
        return $self->_utf8_decode($data);
    }

    sub _utf8_decode {
        my $self = shift;
        my $data = shift;
        $data = Encode::decode( 'utf8', $data )
            if defined $data
            and not Encode::is_utf8($data);
        return $data;
    }

}

1;

__END__

=head1 NAME

Socialtext::EmailSender::ja - An API for sending email

=head1 SYNOPSIS

Perhaps a little code snippet.

  use Socialtext::EmailSender;

  Socialtext::EmailSender->send( ... );

=head1 DESCRIPTION

This module provides a high-level API for sending emails. It can send
emails with text and/or HTML parts, as well as attachments.

It uses C<Email::Send::Sendmail> to actually send mail, and it tells
the sender to find the F<sendmail> program at F</usr/bin/sendmail>.

=head1 METHODS/FUNCTIONS

This module has the following methods:

=head2 send( ... )

This method accepts a number of parameters:

=over 4

=item * to - required

A scalar or array reference of email addresses.

=item * cc - optional

A scalar or array reference of email addresses.

=item * from - has default

The default from address is "Socialtext Workspace
<noreply@socialtext.com>".

=item * text_body - optional

The email's body in text format.

=item * html_body - optional

The email's body in HTML format.

If this body contains C<< <img> >> tags where the "src" attribute's
URI uses the "cid:" scheme, it looks for the references image in the
attachments. If the image is present, generated email should cause the
image to display in clients that display the HTML body. This means
that the image will I<not> show up in the list of attachments for that
email.

=item * attachments - optional

A scalar or array reference of filenames, which will be attached to
the email.

=item * max_size - defaults to 5MB (5 * 1024 * 1024)

The maximum total size in bytes of all attachments for the email. If
an attachment would cause this size to be exceeded, it is not
attached.

To allows an unlimited size, set this to 0.

=back

While both "text_body" and "html_body" are optional, I<at least one>
of them must be provioded.


=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2006 Socialtext, Inc., All Rights Reserved.

=cut
