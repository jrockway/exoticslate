/*
 * Lookahead implementation in jQuery
 *
 * Usage:
 *
 * jQuery('#my-input')
 *    .lookahead({
 *       // submit the input element form on click
 *       submitOnClick: true,
 *
 *       // REST url to fetch the suggestion list from
 *       url: '/data/workspaces',
 *
 *       // Function called on each list item which turns the item hash
 *       // into an array containing the link title and value
 *       linkText: function (item) {
 *           return [ item.title, item.value ];
 *       }
 *    });
 */

(function($){
    var opts;

    $.fn.lookahead = function(options) {
        opts = options;

        if (!opts.url) throw new Error("url missing");
        if (!opts.linkText) throw new Error("linkText missing");

        this.each(function(){
            $(this)
                .attr('autocomplete', 'off')
                .keyup(function() {
                    $.fn.lookahead.onchange(this);
                    return false;
                })
                .blur(function () {
                    $.fn.lookahead.clearLookahead(this);
                });
        });
    };

    $.fn.lookahead.clearLookahead = function (input) {
        if (input.lh)
            jQuery(input.lh).fadeOut();
    };

    $.fn.lookahead.getLookahead = function (input) {
        var lh;
        if (lh = input.lh) return lh;
        var lh = jQuery('<div>')
            .css({
                position: 'relative',
                background: '#BBBBFF',
                border: '1px solid black',
                display: 'none',
                padding: '5px'
            })
            .width(jQuery(input).width())
            .insertAfter(input);
        return input.lh = lh;
    }

    $.fn.lookahead.onchange = function (input) {
        var val = jQuery(input).val();
        if (!val) {
            this.clearLookahead(input)
            return;
        }
        var lookahead = this.getLookahead(input);
        this.ajax = null;
        this.ajax = jQuery.getJSON(
            opts.url + '?order=alpha;filter=\\b' + val,
            function (data) {
                if (data.length) {
                    lookahead.html('');
                    jQuery.each(data, function (i) {
                        var lt = opts.linkText(this);
                        lookahead.append(
                            jQuery('<a>')
                                .attr('href', '#')
                                .html(lt[0])
                                .click(function () {
                                    jQuery(input).val(lt[1]);
                                    if (opts.submitOnClick) {
                                        jQuery(input).parent('form').submit();
                                    }
                                    return false;
                                })
                        );
                        if (i+1 < data.length)
                            lookahead.append(', ')
                    })
                    lookahead.fadeIn();
                }
            }
        );
    };

})(jQuery);
