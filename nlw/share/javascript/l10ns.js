var LocalizedStrings = {"zj":{"You must select two revisions to compare.":"y\u304a\u3046 m\u3046s7 S\u3048L\u3048C7 7W\u304a r\u3048v\u3044s\u3044\u304aNs 7\u304a C\u304aMp\u3042r\u3048.","You cannot compare a revision to itself.":"y\u304a\u3046 c\u3042nN\u304a7 C\u304aMp\u3042r\u3048 \u3042 R\u3048V\u3044S\u3044\u304an 7\u304a \u30447S\u3048Lf."},"zz":{"You must select two revisions to compare.":"y0u mUs7 S3L3C7 7W0 r3vIsI0Ns 70 C0Mp4r3.","You cannot compare a revision to itself.":"y0u c4nN07 C0Mp4r3 4 R3ViSi0n 70 I7S3Lf."}};

function loc() {
    var locale = Socialtext.loc_lang;
    var dict = LocalizedStrings[locale] || new Array;
    var str = arguments[0] || "";
    var l10n = dict[str];

    if (!l10n) {
        var nstr = str.replace(/\"/g, "\\\"");
        l10n = dict[nstr] || str;
    }

    /* If the hash-lookup failed, convert [_1] into %1 and try again. */
    if (!l10n) {
        var nstr = str.replace(/\[_(\d+)\]/g, "%$1");
        l10n = dict[nstr] || str;
    }

    /* Convert both %1 and [_1] style vars into the given arguments */
    for (var i = 1; i < arguments.length; i++) {
        var rx = new RegExp("\\[_" + i + "\\]", "g");
        var rx2 = new RegExp("%" + i + "", "g");
        l10n = l10n.replace(rx, arguments[i]);
        l10n = l10n.replace(rx2, arguments[i]);
    }

    return l10n;
}

