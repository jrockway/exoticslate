var ST = window.ST = window.ST || {};
(function ($) {

ST.SimpleLightbox = function () {};
ST.SimpleLightbox.prototype = {
    show: function (title, msg) {
        $.showLightbox({
            html: Jemplate.process('simple.tt2', { loc: loc, msg: msg, title: title }),
            close: '#simple-lightbox .close'
        });
    }
}

})(jQuery);

function errorLightbox(error) {
    var lb = new ST.SimpleLightbox;
    lb.show(loc('Error'), error);
}

function successLightbox(msg) {
    var lb = new ST.SimpleLightbox;
    lb.show(loc('Success'), msg);
}
