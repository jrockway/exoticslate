var ST = ST || {};
ST.CreateContent = function () {}
var proto = ST.CreateContent.prototype = {};

proto.createContentLightbox = function () {
    var self = this;
    this.process('create_content_lightbox.tt2');
    this.sel = '#st-create-content-lightbox';
    this.show(
        false,
        function () {
        }
    );
}

proto.process = function (template) {
    Socialtext.loc = loc;
    jQuery('body').append(
        Jemplate.process(template, Socialtext)
    );
}

proto.show = function (do_redirect, callback) {
    var self = this;
    jQuery.showLightbox({
        content: this.sel,
        close: this.sel + ' .close',
        callback: callback 
    });

    // Clear errors from the previous time around: {bz: 1039}
    jQuery(self.sel + ' .error').html('');
}
