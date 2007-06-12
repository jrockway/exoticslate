var LocalizedStrings = {"jp":{"You cannot compare a revision to itself.":"それ自身と修正を比較することができない。"},"es":{"You must select two revisions to compare.":"Elija dos revisiones para compararlos.","You cannot compare a revision to itself.":"No puede comparar una revisión a su misma."}};

function loc(str) {
    var locale = Socialtext.loc_lang;
    var dict = LocalizedStrings[locale] || new Array;
    return dict[str] || str;
}

