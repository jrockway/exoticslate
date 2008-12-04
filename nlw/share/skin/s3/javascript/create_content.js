var ST = ST || {};
ST.CreateContent = function () {}
var proto = ST.CreateContent.prototype = {};

proto.from_blank_radio = function () { 
    return jQuery('#create-content-from-blank input[type=radio]');
}

proto.from_template_radio = function () { 
    return jQuery('#create-content-from-template input[type=radio]');
}

proto.from_template_select = function () { 
    return jQuery('#create-content-from-template select');
}

proto.from_page_radio = function () { 
    return jQuery('#create-content-from-page input[type=radio]');
}

proto.from_page_text = function () { 
    return jQuery('#create-content-from-page input[type=text]');
}

proto.get_from_page = function() {
    if (this.from_page_radio().is(':checked')) {
        return this.from_page_text().val();
    }
    else if (this.from_template_radio().is(':checked')) {
        return this.from_template_select().val();
    }
    else {
        return;
    }
}

proto.get_templates = function () {
    var self = this;
    this.from_template_select().html('');
    jQuery.ajax({
        url: Page.workspaceUrl() + '/tags/template/pages',
        cache: false,
        dataType: 'json',
        success: function (pages) {
            for (var i = 0,l=pages.length; i < l; i++) {
                jQuery('<option></option>')
                    .val(pages[i].page_id)
                    .html(pages[i].name)
                    .appendTo(self.from_template_select());
            }
        }
    });
}

proto.add_page_lookahead = function () {
    this.from_page_text().lookahead({
        url: Page.workspaceUrl() + '/pages',
        params: { minimal_pages: 1 },
        linkText: function (i) { return i.name }
    });
}

proto.selected_page_type = function () {
    if (jQuery('#st-create-content-lightbox #page-radio').is(":checked"))
        return "page";
    else if (
        jQuery('#st-create-content-lightbox #spreadsheet-radio').is(":checked"))
        return "spreadsheet";
}

proto.show = function () {
    var self = this;

    // Clear errors from the previous time around: {bz: 1039}
    jQuery('#st-create-content-lightbox .error').html('');

    // Bind radio buttons
    this.from_blank_radio().unbind('click').click(function () {
        self.from_template_select().attr('disabled', 'true');
        self.from_page_text().attr('disabled', 'true');
    });
    this.from_template_radio().unbind('click').click(function () {
        self.from_template_select().attr('disabled', '');
        self.from_page_text().attr('disabled', 'true');
    });
    this.from_page_radio().unbind('click').click(function () {
        self.from_template_select().attr('disabled', 'true');
        self.from_page_text().attr('disabled', '');
    });


    var default_from_page_text = loc('Start typing a page name...');
    this.from_page_text()
        .val(default_from_page_text)
        .unbind('click').click(function () {
            if (jQuery(this).val() == default_from_page_text) {
                jQuery(this).val('');
            }
        })

    this.get_templates();

    // Set the defaults
    this.from_blank_radio().click();
    this.add_page_lookahead();

    jQuery('#st-create-content-lightbox #st-create-content-form')
        .unbind('submit')
        .submit(function () {
            var url = self.create_url();
            if (url)
                document.location = url;    
            return false;
        });

    jQuery.showLightbox({
        content:'#st-create-content-lightbox',
        close:'#st-create-content-cancellink'
    });

}

proto.set_incipient_title = function (title) {
    this._incipient_title = title;
}

proto.create_url = function () {
    var type = this.selected_page_type();
    var url;
    if (this._incipient_title) {
        url = "?action=display;is_incipient=1;page_name="
            + this._incipient_title
    }
    else {
        url = "?action=new_page";
    }
    url += ";page_type=" + type;

    var template = this.get_from_page();
    if (template) {
        url += ';template=' + template;
    }

    return url;
}
