var ST = window.ST = window.ST || {};
(function ($) {

ST.SimpleLightbox = function () {};
ST.SimpleLightbox.prototype = {
    show: function (title, msg, cb) {
        $.showLightbox({
            html: Jemplate.process('simple.tt2', { loc: loc, msg: msg, title: title }),
            close: '#simple-lightbox .close'
        });
        
        if (cb) {
            $('#simple-lightbox .close').unbind('click').click(cb);
        }
    }
}

})(jQuery);

function errorLightbox(error, cb) {
    var lb = new ST.SimpleLightbox;
    lb.show(loc('Error'), error, cb);
}

function successLightbox(msg, cb) {
    var lb = new ST.SimpleLightbox;
    lb.show(loc('Success'), msg, cb);
}
