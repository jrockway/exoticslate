(function($){
    var opts;

    $.hideLightbox = function() {
        $(this).hideLightbox();
    };

    $.showLightbox = function(options) {
        opts = options;
        $(this).showLightbox();
    };

    $.fn.showLightbox = function() {
        if (!$('#lightbox').size()) {
            $('<div id="lightbox">')
                .css({
                    display: 'none',
                    position: $.browser.msie ? 'absolute': 'fixed',
                    zIndex: 2001,
                    padding: 0,
                    background: '#fff',
                    width: '520px',
                    margin: '100px auto',
                    border: "1px outset #555",
                })
                .appendTo('body')
                .css({
                    left: (($(window).width() -
                            $('#lightbox').width()) / 2) + 'px',
                    top:  (($(window).height() -
                            $('#lightbox').height()) /5) + 'px'
                });
        }
        if (!$('#overlay').size()) {
            $('<div id="overlay">')
                .click(function () { $.hideLightbox() })
                .css({
                    display: 'none',
                    position: $.browser.msie ? 'absolute': 'fixed',
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
                })
                .appendTo('body');
        }

        $('body').css('overflow', 'hidden');

        if (opts.close)
            $(opts.close).click(function () { $.hideLightbox() })

        $('#overlay').fadeIn(function () {
            $('#lightbox').append($(opts.content).show()).fadeIn();
        });
    };

    $.fn.hideLightbox = function() {
        $(opts.content).hide().appendTo('body');
        $('#overlay').fadeOut()
        $('#lightbox').hide();
        $('body').css('overflow', 'visible');
    };
})(jQuery);
