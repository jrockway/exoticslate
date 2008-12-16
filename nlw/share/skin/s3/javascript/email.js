// Regular expression for validating email addresses. Not perfect,
// but close enough to eliminate the majority of invalid addresses,
// which erring on the side of caution. Adapted from here:
//
// http://fightingforalostcause.net/misc/2006/compare-email-regex.php
//
var EMAIL_ADDRESS_REGEX = new RegExp(
    "^"
    + "([a-zA-Z0-9_'+*$%\\^&!\\.\\-])+"
    + "@"
    + "(([a-zA-Z0-9\\-])+\\.)+"
    + "([a-zA-Z0-9:]{2,4})+"
    + "$"
    , "i"
);

function email_page_check_address(email_address) {
    return EMAIL_ADDRESS_REGEX.test(email_address);
}
