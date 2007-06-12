// Pop up a new HTML window
function query_popup(url, width, height, left, top) {
    if (!width) width = 400;
    if (!height) height = 275;
    if (!left) left = 400-width/2;
    if (!top) top = 280-height/2;
    window.open(url, '_blank', 'toolbar=no, location=no, directories=no, status=no, menubar=no, titlebar=no, scrollbars=yes, resizable=yes, width=' + width + ', height=' + height + ', left=' + left + ', top=' + top);
}

function help_popup(url, width, height, left, top) {
    if (!width) width = 520;
    if (!height) height = 300;
    if (!left) left = 400-width/2;
    if (!top) top = 280-height/2;
    window.open(url, '_blank', 'toolbar=no, location=no, directories=no, status=no, menubar=no, titlebar=no, scrollbars=yes, resizable=yes, width=' + width + ', height=' + height + ', left=' + left + ', top=' + top);
}

function trim(value) {
    var ltrim = /\s*((\s*\S+)*)/;
    var rtrim = /((\s*\S+)*)\s*/;
    return value.replace(rtrim, "$1").replace(ltrim, "$1");
};

function is_reserved_pagename(pagename) {
    if (pagename && pagename.length > 0) {
        var name = trim(pagename.toLowerCase());
        return name == 'untitled page';
    }
    else {
        return false;
    }
}

function confirm_delete(pageid) {
    if (confirm('Are you sure you want to delete this page?')) {
        location = 'index.cgi?action=delete_page;page_name=' + pageid;
    }
}
