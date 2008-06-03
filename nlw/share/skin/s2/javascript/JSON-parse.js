//------------------------------------------------------------------------------
// JSON Support
//------------------------------------------------------------------------------

/*
Copyright (c) 2005 JSON.org
*/
var JSON = function () {
    return {
        copyright: '(c)2005 JSON.org',
        license: 'http://www.crockford.com/JSON/license.html',
        parse: function (text) {
            try {
                if (text.length > 5 * 1024) {
                    return eval('(' + text + ')');
                }
                return !(/[^,:{}\[\]0-9.\-+Eaeflnr-u \n\r\t]/.test(
                        text.replace(/"(\\.|[^"\\])*"/g, ''))) &&
                    eval('(' + text + ')');
            } catch (e) {
                return false;
            }
        }
    };
}();
