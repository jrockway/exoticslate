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
 *       filterValue: function (val) {
 *           return val + '.*(We)?blog$'
 *       },
 *
 *       // OPTIONAL: use a different filter argument than 'filter'
 *       filterName: 'title_filter',
 *
 *       // OPTIONAL: handler run when a value is accepted
 *       onAccept: function (val) {
 *       },
 *
 *       // NOT IMPLEMENTED: additional args to pass to the server
 *       args: { pageType: 'spreadsheet' }
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
                .keyup(function(e) {
                    if (e.keyCode == 13) {
                        $.fn.lookahead.clearLookahead(this);
                    }
                    else {
                        var input = this;
                        var lookahead = $.fn.lookahead.getLookahead(input);
                        if (lookahead.is(':visible')) {
                            $.fn.lookahead.onchange(input, opts);
                        }
                        else {
                            $.fn.lookahead.loadExceptions(opts, function () {
                                $.fn.lookahead.onchange(input, opts);
                            });
                        }
                    }
                    return false;
                })
                .blur(function() {
                    $.fn.lookahead.clearLookahead(this);
                });
        });

        return this;
    };

    $.fn.lookahead.loadExceptions = function (opts, callback) {
        opts.exceptValues = {};
        if (opts.exceptUrl) {
            $.ajax({
                url: opts.exceptUrl,
                dataType: 'json',
                success: function (items) {
                    $.each(items, function (i) {
                        var value = $.fn.lookahead.linkTitle(this,opts);
                        opts.exceptValues[this.value.toLowerCase()] = 1;
                    });
                    if ($.isFunction(callback)) {
                        callback();
                    } 
                }
            });
        }
        else {
            callback();
        }
    }

    $.fn.lookahead.clearLookahead = function (input) {
        if (input.lh)
            $(input.lh).fadeOut();
    };

    $.fn.lookahead.getLookahead = function (input) {
        var lh;
        if (lh = input.lh) return lh;
        var lh = $('<div />')
            .css({
                position: $.browser.msie ? 'relative' : 'absolute',
                background: '#B4DCEC',
                border: '1px solid black',
                display: 'none',
                padding: '5px',
                width: $(input).width() + 'px',
                left: input.offsetLeft + 'px'
            })
            .insertAfter(input);
        return input.lh = lh;
    }

    $.fn.lookahead.linkTitle = function (item, opts) {
        var lt = opts.linkText(item);
        return typeof (lt) == 'string' ? lt : lt[0];
    }

    $.fn.lookahead.linkValue = function (item, opts) {
        var lt = opts.linkText(item);
        return typeof (lt) == 'string' ? lt : lt[1];
    }

    $.fn.lookahead.onchange = function (input, opts) {
        var self = this;
        var val = $(input).val();
        if (!val) {
            this.clearLookahead(input)
            return;
        }
        var lookahead = this.getLookahead(input);
        try {
            this.ajax.abort()
        }
        catch (e) {}
        var url = typeof(opts.url) == 'function' ? opts.url() : opts.url;
        if (opts.filterValue) val = opts.filterValue(val);
        var filterName = opts.filterName || 'filter';
        this.ajax = $.ajax({
            url: url + '?order=alpha;' + filterName + '=\\b' + val,
            cache: false,
            dataType: 'json',
            success: function (data) {
                lookahead.html('');

                // Grep out all exceptions
                data = $.map(data, function(item) {
                    return {
                        title: self.linkTitle(item, opts),
                        value: self.linkValue(item, opts)
                    };
                });
                data = $.grep(data, function(item) {
                    return !opts.exceptValues[item.value.toLowerCase()];
                });

                if (data.length) {
                    $.each(data, function (i) {
                        var item = this;
                        $('<a href="#">' + item.title + '</a>')
                            .click(function () {
                                $(input).val(item.value);
                                self.clearLookahead(input);
                                if (opts.onAccept) {
                                    opts.onAccept.call(input, item.value);
                                }
                                return false;
                            })
                            .appendTo(lookahead);
                        if (i+1 < data.length)
                            lookahead.append(',<br/>')
                    })
                    lookahead.fadeIn();
                }
                else {
                    lookahead.fadeOut();
                }
            },
            error: function (xhr, textStatus, errorThrown) {
                if (opts.onError) {
                    var errorHandler = opts.onError[xhr.status] || opts.onError['default'];
                    if (errorHandler) {
                        if ($.isFunction(errorHandler)) {
                            lookahead.html( errorHandler( xhr, textStatus, errorThrown ) );
                        }
                        else {
                            lookahead.html( errorHandler );
                        }
                        lookahead.fadeIn();
                    }
                }
            }
        });
    };

})(jQuery);
