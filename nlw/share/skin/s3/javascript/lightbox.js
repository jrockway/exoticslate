(function($){
    var opts;

    $.fn.lightbox = function(options){
        opts = options;
        this.each(function(){
            $(this).click(function(){
                $(this).lightbox.start();
                return false;
            });
        });
    };

    $.fn.lightbox.is_ie = function() {
        ua = navigator.userAgent.toLowerCase();
        is_ie = (
            ua.indexOf("msie") != -1 &&
            ua.indexOf("opera") == -1 &&
            ua.indexOf("webtv") == -1
        );
        return is_ie;
    };
    
    $.fn.lightbox.start = function() {
        var self = this;

        if (!$('lightbox').length) {
            $('body')
                .append(
                    $('<div id="overlay">'),
                    $('<div id="lightbox">')
                );
        }

        var width = jQuery(window).width();
        var height = jQuery(window).height();

        $('body').css('overflow', 'hidden');

        $('#lightbox')
            .append($(opts.content).fadeIn())
            .css({
                display: 'none',
                position: this.is_ie ? 'absolute': 'fixed',
                zIndex: 2001,
                padding: 0,
                background: '#fff',
                width: '520px',
                margin: '100px auto',
                border: "1px outset #555",
            })
            .css({
                left: ((width - $('#lightbox').width()) / 2) + 'px',
                top:  ((height - $('#lightbox').height()) /3) + 'px'
            });

        if (opts.close)
            jQuery(opts.close).click(function () { self.stop() })

        $('#overlay')
            .click(function () { self.stop() })
            .css({
                display: 'none',
                position: this.is_ie ? 'absolute': 'fixed',
                background: "#000",
                opacity: "0.5",
                filter :  "alpha(opacity=50)",
                top: 0,
                left: 0,
                width: "100%",
                height: "100%",
                zIndex: 2000,
                padding: 0,
                margin: 0
            });

        $('#overlay').show();
        $('#lightbox').show();
    };

    $.fn.lightbox.stop = function() {
        $(opts.content).hide().appendTo('body');
        $('#overlay').fadeOut(function() {
            $('#overlay').remove();
        });
        $('#lightbox').remove();
        $('body').css('overflow', 'visible');
    };
})(jQuery);
