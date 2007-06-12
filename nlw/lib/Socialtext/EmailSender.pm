# @COPYRIGHT@
package Socialtext::EmailSender;

use strict;
use warnings;

our $VERSION = '0.01';

use Email::Valid;
use Email::MessageID;
use Email::MIME;
use Email::MIME::Creator;
use Email::Send qw();
use Email::Send::Sendmail;
use Encode ();
use File::Basename ();
use File::Slurp ();
use List::Util qw(first);
use MIME::Types;
use Readonly;
use Socialtext::Exceptions qw( param_error );
use Socialtext::Validate
    qw( validate SCALAR_TYPE ARRAYREF_TYPE HASHREF_TYPE SCALAR_OR_ARRAYREF_TYPE BOOLEAN_TYPE );

$Email::Send::Sendmail::SENDMAIL = '/usr/sbin/sendmail';

my $SendClass = 'Sendmail';
sub TestModeOn { $SendClass = 'Test' }

{
    Readonly my $spec => {
        to          => SCALAR_OR_ARRAYREF_TYPE,
        cc          => SCALAR_OR_ARRAYREF_TYPE( optional => 1 ),
        from        => SCALAR_TYPE( default => 'Socialtext Workspace <noreply@socialtext.com>' ),
        subject     => SCALAR_TYPE,
        text_body   => SCALAR_TYPE( optional => 1 ),
        html_body   => SCALAR_TYPE( optional => 1 ),
        attachments => SCALAR_OR_ARRAYREF_TYPE( default => [] ),
        # default max size is 5MB
        max_size    => SCALAR_TYPE( default => 1024 * 1024 * 5 ),
    };
    sub send {
        shift;
        my %p = validate( @_, $spec );

        unless ( $p{text_body} or $p{html_body} ) {
            param_error
                'You must provide a text or HTML body when calling Socialtext::EmailSender::send()';
        }

        my $to  = ref $p{to} ? join ', ', @{ $p{to} } : $p{to};
        my $cc  = ref $p{cc} ? join ', ', @{ $p{cc} } : $p{cc};

        # Encode::MIME::Header will buggily add extra spaces when
        # encoding, so we only encode the subject, as that is the only
        # part we think will ever need it. Dave is working on fixing
        # the bug.
        if ( $p{subject} =~ /[\x7F-\xFF]/ ) {
            $p{subject} = Encode::encode( 'MIME-Header', $p{subject} )
        }
        else {
            # This shuts up a "wide character in print" warning from
            # inside Email::Send::Sendmail.
            $p{subject} = Encode::encode( 'utf8', $p{subject} );
        }

        my %headers = (
            From                        => $p{from},
            To                          => $to,
            Subject                     => $p{subject},
            'Message-ID'                => '<' . Email::MessageID->new . '>',
            'X-Sender'                  => "Socialtext::EmailSender v$VERSION",
            'Content-Transfer-Encoding' => '8bit',
        );
        $headers{Cc} = $cc if $cc;

        my $text_body_part;
        my $html_body_part;
        if ( $p{text_body} ) {
            $text_body_part = Email::MIME->create(
                attributes => {
                    content_type => 'text/plain',
                    disposition  => 'inline',
                    charset      => 'UTF-8',
                },
                body   => _text_body( $p{text_body} ),
            );
        }

        if( $p{html_body} ) {
            $html_body_part = Email::MIME->create(
                attributes => {
                    content_type => 'text/html',
                    disposition  => 'inline',
                    charset      => 'UTF-8',
                },
                body   => _html_body( $p{html_body} ),
            );

            my %basenames =
                map { File::Basename::basename($_) => $_ }
                grep { -f } @{ $p{attachments} };

            my %cids;
            while ( $p{html_body} =~ /\G.*?src="cid:([^"]+)"/gs ) {
                $cids{$1} = 1
                    if $basenames{$1};
            }

            if ( keys %cids ) {
                my @image_parts = map { _attachment_part( $basenames{$_} ) } keys %cids;

                # The structure will be:
                #
                # multipart/related
                #  - text/html body
                #  - image cid 1
                #  - image cid 2
                #  - etc
                $html_body_part = Email::MIME->create(
                    header => [ 'Content-Type' => 'multipart/related; type="text/html"' ],
                    parts  => [ $html_body_part, @image_parts ],
                );

                $p{attachments} =
                    [ grep { ! $cids{ File::Basename::basename($_) } }
                      @{ $p{attachments} } ];
            }
        }

        my $body;
        if ( $text_body_part and $html_body_part ) {
            $body = Email::MIME->create(
                header => [ 'Content-Type' => 'multipart/alternative' ],
                parts  => [ $text_body_part, $html_body_part ],
            );
        }
        else {
            $body = first { defined } $text_body_part, $html_body_part;
        }

        my @attachments;
        my $total_size = 0;
        for my $file ( grep { -f } @{ $p{attachments} } ) {

            my $att_size = -s $file;
            next if $p{max_size} and $total_size + $att_size > $p{max_size};

            push @attachments, _attachment_part($file);

            $total_size += $att_size;
        }

        my $email;
        if (@attachments) {
            # The goal here is to produce an email of this structure
            #
            # multipart/mixed
            #  - multipart/alternative
            #    - text/plain
            #    - text/html
            #  - attachment 1
            #  - attachment 2
            #  - etc
            #
            # I tested this type in both Pine and Thunderbird, and it
            # displays the HTML part by default, and the file
            # attachments are viewable/downloadable as appropriate.
            $email = Email::MIME->create(
                header => [
                    %headers,
                    'Content-Type' => 'multipart/mixed',
                ],
                parts  => [ $body, @attachments ],
            );
        }
        else {
            # If there's no attachments we already have an appropriate
            # top-level structure with the $body part we created
            # earlier, we just need to add the appropriate headers.
            $email = $body;

            $email->header_set( $_ => $headers{$_} )
                for keys %headers;
        }

        Email::Send->new( { mailer => $SendClass } )->send($email);
    }
}

sub _text_body {
    return Encode::encode( 'utf8', $_[0] );
}

sub _html_body {
    return Encode::encode( 'utf8', $_[0] );
}

sub _attachment_part {
    my $file = shift;

    my $filename = File::Basename::basename($file);

    return Email::MIME->create(
        header     => [ 'Content-Id' => $filename ],
        attributes => {
            content_type => MIME::Types->new()->mimeTypeOf($file),
            disposition  => 'attachment',
            encoding     => 'base64',
            filename     => $filename,
        },
        body       => scalar File::Slurp::read_file($file),
    );
}


1;

__END__

=head1 NAME

Socialtext::EmailSender - An API for sending email

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

=head2 TestModeOn()

Turns on testing mode, which means emails are sent using
C<Email::Send::Test>. This allows you to capture sent emails and
examine them in tests.

You will need to load C<Email::Send::Test> yourself to make this work
properly.

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2006 Socialtext, Inc., All Rights Reserved.

=cut
