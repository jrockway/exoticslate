var ST = ST || {};
ST.CreateContent = function () {}
var proto = ST.CreateContent.prototype = {};
proto.visible_types = {
    wiki: loc('Page')
};

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

proto.choices = function () {
    return jQuery('#st-create-content-lightbox .choice input');
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

proto.update_templates = function () {
    var self = this;
    var type = this.selected_page_type();
    var visible_type = self.visible_types[type] || type;
    var template = loc('template');
    jQuery.ajax({
        url: Page.workspaceUrl() + '/tags/' + template + '/pages?type=' + type,
        cache: false,
        dataType: 'json',
        success: function (pages) {
            self.from_template_select().html('');
            if (!pages.length) {
                if (self.from_template_radio().is(':checked')) {
                    self.from_blank_radio().click();
                }
                self.from_template_radio().attr('disabled', 'disabled');
                var error = loc(
                    "No [_1] pages tagged '[_2]' could be found",
                    type, template
                );

                self.from_template_select()
                    .html('<option selected="true">'+error+'</option>')
                    .attr('disabled', 'disabled')
                    .css({'font-style': 'italic'});
            }
            else {
                self.from_template_radio().attr('disabled', '');
                self.from_template_select()
                    .attr('disabled', '')
                    .css({'font-style': 'normal'});
                for (var i = 0,l=pages.length; i < l; i++) {
                    jQuery('<option></option>')
                        .val(pages[i].page_id)
                        .html(pages[i].name)
                        .appendTo(self.from_template_select());
                }
            }
        }
    });
}

proto.create_page_lookahead = function () {
    var self = this;
    var workspace_url = Page.workspaceUrl();
    this.from_page_text().lookahead({
        url: function () {
            return workspace_url + '/pages?type=' +
                self.selected_page_type();
        },
        params: { minimal_pages: 1 },
        linkText: function (i) { return i.name }
    });
}

proto.selected_page_type = function () {
    var self = this;
    var page_type = 'wiki';
    this.choices().each(function () {
        if (jQuery(this).is(":checked")) {
            page_type = jQuery(this).val();
            self.visible_types[page_type] = loc(jQuery(this).html());
        }
    });
    return page_type;
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
    this.choices().unbind('click').click(function () {
        self.update_templates();
    });

    var default_from_page_text = loc('Start typing a page name...');
    this.from_page_text()
        .val(default_from_page_text)
        .unbind('click').click(function () {
            if (jQuery(this).val() == default_from_page_text) {
                jQuery(this).val('');
            }
        })

    // Set the defaults
    this.from_blank_radio().click();
    this.update_templates();
    this.create_page_lookahead();

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
