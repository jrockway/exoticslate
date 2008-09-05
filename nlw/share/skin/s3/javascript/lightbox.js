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

        pageScroll = { left: xScroll, top: yScroll };
        return pageScroll;
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
                    fontSize: '11px',
                    fontFamily: 'Verdana, Arial, sans-serif',
                    padding: 0,
                    background: '#fff',
                    margin: 'auto',
                    border: "1px outset #555"
                })
                .appendTo('body');
        }

        var pageScroll = _getPageScroll();

        if (!$('#overlay').size()) {
            $('<div id="overlay">')
                .click(function () { $.hideLightbox() })
                .css({
                    display: 'none',
                    position: 'absolute',
                    background: "#000",
                    opacity: "0.5",
                    filter: "alpha(opacity=50)",
                    zIndex: 2000,
                    padding: 0,
                    margin: 0
                })
                .appendTo('body');
        }

        var arrayPageScroll = _getPageScroll();

        $('#lightbox')
            .css('width', opts.width || '520px')
            .append(opts.html || $(opts.content).show())
            .css({
                left: (pageScroll.left + (($(window).width() -
                        $('#lightbox').width()) / 2)) + 'px',
                top:  (pageScroll.top + (($(window).height() -
                        $('#lightbox').height()) / 2)) + 'px'
            });

        $('body').css('overflow', 'hidden');

        if (opts.close)
            $(opts.close).click(function () { $.hideLightbox() })

        $('#overlay')
            .css({
                top: pageScroll.top,
                left: pageScroll.left,
                width: $(window).width(),
                height: $(window).height()
            })
            .fadeIn(function () {
                $('#lightbox').fadeIn(function() {
                    $(opts.focus).focus();
                    if ($.isFunction(opts.callback))
                        opts.callback();
                })
            });
    };

    $.fn.hideLightbox = function() {
        if (opts) {
            $('#lightbox').trigger('unload');
            if (opts.content)
                $(opts.content).hide().appendTo('body');
            $('#overlay').fadeOut();
            $('#lightbox').html('').hide();
            $('body').css('overflow', 'visible');
        }
    };
})(jQuery);
