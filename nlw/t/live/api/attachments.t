#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Live fixtures => ['admin_with_extra_pages'];
my $LiveTest = Test::Live->new();
$LiveTest->standard_query_validation;

# Delete an existing attachment
{
    # get the attachments for formattingtest (as json)
    my $content = _get_page_content(
        $LiveTest,
        '/page/admin/formattingtest/attachments',
        'text/javascript',
    );
    # extract the id of the first attachment
    my $id;
    if ($content =~ /"id":"([\d\-]+)"/) {
        $id = $1;
    }

    # delete the attachment
    my $request = HTTP::Request->new(DELETE => $LiveTest->base_url . '/page/admin/formattingtest/attachments/' .$id);
    my $response = $LiveTest->mech->request($request);

    # get the attachment list agin
    $content = $response->content;

    # element should be missing
    Test::More->builder->unlike( $content, qr/$id/, 'Delete Attachment - attachment list does not include deleted attachment' );

    sub _get_page_content {
        my $LIVE_TEST = shift;
        my $URI = shift;
        my $ACCEPT_TYPE = shift;

        my $url = $LIVE_TEST->base_url . $URI;
        if (defined($ACCEPT_TYPE)) {
            $LIVE_TEST->mech->add_header(Accept => $ACCEPT_TYPE);
        }

        $LIVE_TEST->mech->get($url);
        return $LIVE_TEST->mech->content;
    }
}


__DATA__
=== First page should have no attachments
--- request_path: /page/admin/start_here/attachments
--- match: \[\]

=== formattingtest has 3 attachments
--- request_path: /page/admin/formattingtest/attachments
--- match
Robot.txt
test_image.jpg
thing.png

=== Get to 'start here' page
--- request_path: /admin/index.cgi?start_here
--- match: Start here

=== Attach a file
--- form: attachForm
--- post
file: t/extra-attachments/live/attachments.t/test.txt
--- match: test\.txt

=== Should have an attachment now
--- request_path: /page/admin/start_here/attachments
--- match: test\.txt

=== Attachment list in HTML
--- request_path: /page/admin/start_here/attachments
--- accept: text/html
--- match
<html>
test\.txt
devnull1

=== Try to pull link
--- follow_link
text: test.txt
n: 1
--- match_file: t/extra-attachments/live/attachments.t/test.txt

=== Attachment list in JSON
--- request_path: /page/admin/start_here/attachments
--- accept: text/javascript
--- match
{"attachments":\[{
test\.txt
devnull1
--- match_header
Pragma: no-cache

=== Return to 'Start here' page
--- request_path: /admin/index.cgi?start_here
--- match: Start here
--- match_status: 200

=== Attach a text file
--- request_path: /page/admin/start_here/attachments
--- multipart_post
file: t/extra-attachments/live/attachments.t/test2.txt
embed: 0
unpack: 0
--- match_status: 201
--- match
test2\.txt

=== Attach a binary file
--- request_path: /page/admin/start_here/attachments
--- multipart_post
file: t/extra-attachments/live/attachments.t/thing.png
embed: 0
unpack: 0
--- match_status: 201
--- match
thing\.png

=== Make sure binary file is in attachment list
--- request_path: /page/admin/start_here/attachments
--- accept: text/html
--- match
<html>
test\.txt
thing\.png
devnull1

=== Try to pull link for binary file
--- follow_link
text: thing.png
n: 1
--- match_file: t/extra-attachments/live/attachments.t/thing.png
