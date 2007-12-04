#!perl
# @COPYRIGHT@

use strict;
use warnings;
use utf8;

use Test::Socialtext tests => 8;
fixtures( 'admin_no_pages' );

BEGIN {
    use_ok( 'Socialtext::WeblogPlugin' );
}

WEBLOG_CACHE: {
    my $hub = new_hub('admin');

    $hub->weblog->current_weblog('socialtext blog');
    $hub->weblog->update_current_weblog();
    is $hub->weblog->current_blog, 'socialtext blog',
        'cache is written with socialtext blog';
}

WEBLOG_TITLE_IS_VALID: {
    my $hub = new_hub('admin');
   
    #
    # Check length boundary conditions.
    #
    ok( ! $hub->weblog->_weblog_title_is_valid('a' x 256),
       'Too-long weblog name fails'
    );
    ok( $hub->weblog->_weblog_title_is_valid('a' x 255),
        'Weblog name of exactly 255 characters succeeds'
    );

    #
    # Check the name which had utf8 characters.
    #
    ok( ! $hub->weblog->_weblog_title_is_valid('あ' x 29),
       'Too-long weblog name which had utf8 fails'
    );
    ok( $hub->weblog->_weblog_title_is_valid('あ' x 28),
        'Weblog name of exactly 28 utf8 characters succeeds'
    );
}

WEBLOG_NAME_TO_ID: {
    my $hub = new_hub('admin');

    #
    # Check creating the page object.
    #
    ok( !defined($hub->weblog->_create_first_post('a' x 242)),
        "Createing Weblog page object fails"
    );

    #
    # Check creating the page object which had utf8 characters.
    #
    ok( !defined($hub->weblog->_create_first_post('あ' x 29)),
        'Createing Weblog page object which had utf8 characters fails'
    );

}

