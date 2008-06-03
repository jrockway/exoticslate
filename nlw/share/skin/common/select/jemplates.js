/*
   This JavaScript code was generated by Jemplate, the JavaScript
   Template Toolkit. Any changes made to this file will be lost the next
   time the templates are compiled.

   Copyright 2006 - Ingy döt Net - All rights reserved.
*/

if (typeof(Jemplate) == 'undefined')
    throw('Jemplate.js must be loaded before any Jemplate template files');

Jemplate.templateMap['select.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<div>\n    <h3 style="margin-top: 0;">Select a Socialtext Skin:</h3>\n    <form id="skin-select-form" onsubmit="return false;">\n        <select name="skin-name">\n            ';
//line 7 "select.html"

// FOREACH 
(function() {
    var list = stash.get('skins');
    list = new Jemplate.Iterator(list);
    var retval = list.get_first();
    var value = retval[0];
    var done = retval[1];
    var oldloop;
    try { oldloop = stash.get('loop') } finally {}
    stash.set('loop', list);
    try {
        while (! done) {
            stash.data['skin'] = value;
output += '\n            <option value="';
//line 6 "select.html"
output += stash.get('skin');
output += '">';
//line 6 "select.html"
output += stash.get('skin');
output += '</option>\n            ';;
            retval = list.get_next();
            value = retval[0];
            done = retval[1];
        }
    }
    catch(e) {
        throw(context.set_error(e, output));
    }
    stash.set('loop', oldloop);
})();

output += '\n        </select>\n        <br />\n        <br />\n        <input name="select" type="submit" value="Select" />&nbsp;\n        <input name="cancel" type="submit" value="Cancel" />\n    </form>\n    <p style="font-size: smaller; font-weight: bold; font-style: italic;">Note: this will change the Socialtext Skin only for your browser and only on this particular workspace. Nobody else will be affected and you can change it back at any time.</p>\n</div>\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

