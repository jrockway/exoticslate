if (typeof LocalizedStrings == 'undefined')
    LocalizedStrings = {};

// TODO: this needs to be able to do 'quant' like TT's loc()
// Example: loc('[quant,_1,user]', '1') == '1 user'
//          loc('[quant,_1,user]', '2') == '2 users'

function loc() {
    var locale = Socialtext.loc_lang;
    var dict = LocalizedStrings[locale] || new Array;
    var str = arguments[0] || "";
    var l10n = dict[str];
    var nstr = "";

    if (!l10n) {
        /* If the hash-lookup failed, convert " into \\\" and try again. */
        nstr = str.replace(/\"/g, "\\\"");
        l10n = dict[nstr];
        if (!l10n) {
            /* If the hash-lookup failed, convert [_1] into %1 and try again. */
            nstr = nstr.replace(/\[_(\d+)\]/g, "%$1");
            l10n = dict[nstr] || str;
        }
    }

    l10n = l10n.replace(/\\\"/g, "\"");

    /* Convert both %1 and [_1] style vars into the given arguments */
    for (var i = 1; i < arguments.length; i++) {
        var rx = new RegExp("\\[_" + i + "\\]", "g");
        var rx2 = new RegExp("%" + i + "", "g");
        l10n = l10n.replace(rx, arguments[i]);
        l10n = l10n.replace(rx2, arguments[i]);
    }

    return l10n;
}
