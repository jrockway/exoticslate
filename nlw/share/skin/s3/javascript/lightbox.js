(function($){
    var opts;

    var _getPageScroll = function() { 
        var xScroll, yScroll;
        
        if (self.pageYOffset) {
          yScroll = self.pageYOffset;
          xScroll = self.pageXOffset;
        }
        else if (document.documentElement && document.documentElement.scrollTop) {  // Explorer 6 Strict.
          yScroll = document.documentElement.scrollTop;
          xScroll = document.documentElement.scrollLeft;
        }
        else if (document.body) {// All other Explorers.
          yScroll = document.body.scrollTop;
          xScroll = document.body.scrollLeft;
        }

        arrayPageScroll = [xScroll,yScroll];
        return arrayPageScroll;
    };

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
                    position: 'absolute',
                    zIndex: 2001,
                    padding: 0,
                    background: '#fff',
                    margin: 'auto',
                    border: "1px outset #555"
                })
                .appendTo('body');
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

        var arrayPageScroll = _getPageScroll();

        $('#lightbox')
            .css('width', opts.width || '520px')
            .append($(opts.content).show())
            .css({
                left: (arrayPageScroll[0] + (($(window).width() -
                        $('#lightbox').width()) / 2)) + 'px',
                top:  (arrayPageScroll[1] + (($(window).height() -
                        $('#lightbox').height()) / 2)) + 'px'
            });

        $('body').css('overflow', 'hidden');

        if (opts.close)
            $(opts.close).click(function () { $.hideLightbox() })

        $('#overlay').fadeIn(function () {
            $('#lightbox').fadeIn(function() {
                $(opts.focus).focus();
            })
        });
    };

    $.fn.hideLightbox = function() {
        if (opts) {
            $(opts.content).hide().appendTo('body');
            $('#overlay').fadeOut();
            $('#lightbox').hide();
            $('body').css('overflow', 'visible');
        }
    };
})(jQuery);
