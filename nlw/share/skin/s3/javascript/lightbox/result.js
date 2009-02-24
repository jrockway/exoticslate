var ST = window.ST = window.ST || {};
(function ($) {

ST.DashboardAdminResult = function () {};
ST.DashboardAdminResult.prototype = new ST.DashboardLightbox;

ST.DashboardAdminResult.prototype.showResult = function (title, msg) {
    $.showLightbox({
        html: this.process('result.tt2', { msg: msg, title: title }),
        close: '#result-lightbox .close'
    });
};

})(jQuery);
