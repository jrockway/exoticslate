/*
 * Lookahead implementation in jQuery
 *
 * Usage:
 *
 * jQuery('#my-input')
 *    .lookahead({
 *       // REST url to fetch the suggestion list from
 *       url: '/data/workspaces',
 *
 *       // OR a function that returns the rest url
 *       url: function () { return '/data/workspaces' },
 *
 *       // Function called on each list item which turns the item hash
 *       // into an array containing the link title and value
 *       // or a value to use both as the link title and value
 *       linkText: function (item) {
 *           return [ item.title, item.value ];
 *           // OR
 *           return item.value;
 *       }
 *
 *       // OPTIONAL: modify the value before searching
 *       filter: function (val) {
 *           return val + '.*(We)?blog$'
 *       }
 *
 *       // OPTIONAL: handler run when a value is accepted
 *       onAccept: function (val) {
 *       }
 *
 *       // OPTIONAL: submit the input element form on click
 *       submitOnClick: true,
 *
 *    });
 */

(function($){
    $.fn.lookahead = function(opts) {
        if (!opts.url) throw new Error("url missing");
        if (!opts.linkText) throw new Error("linkText missing");

        this.each(function(){
            $(this)
                .attr('autocomplete', 'off')
                .unbind('keyup')
                .keyup(function() {
                    $.fn.lookahead.onchange(this, opts);
                    return false;
                })
                .blur(function () {
                    $.fn.lookahead.clearLookahead(this);
                });
        });

        return this;
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
                position: 'absolute',
                background: '#B4DCEC',
                border: '1px solid black',
                display: 'none',
                padding: '5px',
                width: jQuery(input).width() + 'px',
                left: input.offsetLeft + 'px',
            })
            .insertAfter(input);
        return input.lh = lh;
    }

    $.fn.lookahead.onchange = function (input, opts) {
        var self = this;
        var val = jQuery(input).val();
        if (!val) {
            this.clearLookahead(input)
            return;
        }
        var lookahead = this.getLookahead(input);
        if (this.ajax && this.ajax.abort)
            this.ajax.abort();
        var url = typeof(opts.url) == 'function' ? opts.url() : opts.url;
        if (opts.filter) val = opts.filter(val);
        this.ajax = jQuery.getJSON(
            url + '?order=alpha;filter=\\b' + val,
            function (data) {
                if (data.length) {
                    lookahead.html('');
                    jQuery.each(data, function (i) {
                        var lt = opts.linkText(this);
                        var title = typeof(lt) == 'string' ? lt : lt[0];
                        var value = typeof(lt) == 'string' ? lt : lt[1];
                        lookahead.append(
                            jQuery('<a>')
                                .attr('href', '#')
                                .html(title)
                                .click(function () {
                                    jQuery(input).val(value);
                                    self.clearLookahead(input);
                                    if (opts.onAccept) {
                                        opts.onAccept.call(input, value);
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
