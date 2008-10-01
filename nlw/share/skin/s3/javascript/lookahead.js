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
    var lookaheads = [];

    Lookahead = function (input, opts) {
        if (!input) throw new Error("Missing input element");
        if (!opts.url) throw new Error("url missing");
        if (!opts.linkText) throw new Error("linkText missing");

        this.input = input;
        this.opts = opts;
        var self = this;

        $(this.input)
            .attr('autocomplete', 'off')
            .unbind('keyup')
            .keyup(function(e) {
                if (e.keyCode == 13) {
                    self.clearLookahead();
                }
                else {
                    if (self._loaded_exceptions) {
                        self.onchange();
                    }
                    else {
                        self.loadExceptions(function () {
                            self.onchange();
                        });
                    }
                }
                return false;
            })
            .blur(function() {
                self.clearLookahead();
            });
    }

    $.fn.lookahead = function(opts) {
        this.each(function(){
            lookaheads.push(new Lookahead(this, opts));
        });

        return this;
    };

    Lookahead.prototype = {};

    Lookahead.prototype.loadExceptions = function (callback) {
        if (this._loading_exceptions) return;
        this._loading_exceptions = true;
        this.exceptValues = {};

        var self = this;

        if (this.opts.exceptUrl) {
            $.ajax({
                url: this.opts.exceptUrl,
                dataType: 'json',
                success: function (items) {
                    self._loading_exceptions = false;
                    self._loaded_exceptions = true;
                    $.each(items, function (i) {
                        var value = self.linkTitle(this);
                        self.exceptValues[this.value.toLowerCase()] = 1;
                    });
                    if ($.isFunction(callback)) {
                        callback();
                    } 
                }
            });
        }
        else {
            this._loaded_exceptions = true;
            callback();
        }
    };

    Lookahead.prototype.clearLookahead = function () {
        if (this.lookahead)
            $(this.lookahead).fadeOut();
    };

    Lookahead.prototype.getLookahead = function () {
        /* Subract the offsets of all absolutely positioned parents
         * so that we can position the lookahead directly below the
         * input element. I think jQuery's offset function should do
         * this for you, but maybe they'll fix it eventually...
         */
        var left = $(this.input).offset().left;
        var top = $(this.input).offset().top + $(this.input).height() + 10;
        $.each( $(this.input).parents(), function (i) {
            if ($(this).css('position') == 'absolute') {
                left -= $(this).offset().left;
                top -= $(this).offset().top;
            }
        });

        if (!this.lookahead) {
            this.lookahead = $('<div />').insertAfter(this.input);
        }

        this.lookahead.css({
            position: 'absolute',
            background: '#B4DCEC',
            border: '1px solid black',
            display: 'none',
            padding: '5px',
            width: $(this.input).width() + 'px',
            left: left + 'px',
            top: top + 'px'
        });
        return this.lookahead;
    };

    Lookahead.prototype.linkTitle = function (item) {
        var lt = this.opts.linkText(item);
        return typeof (lt) == 'string' ? lt : lt[0];
    };

    Lookahead.prototype.linkValue = function (item) {
        var lt = this.opts.linkText(item);
        return typeof (lt) == 'string' ? lt : lt[1];
    };
    
    Lookahead.prototype.ajaxSuccess = function (data) {
        var self = this;
        var opts = this.opts;
        var lookahead = this.getLookahead();

        lookahead.html('');

        // Grep out all exceptions
        data = $.map(data, function(item) {
            return {
                title: self.linkTitle(item),
                value: self.linkValue(item)
            };
        });
        data = $.grep(data, function(item) {
            return !self.exceptValues[item.value.toLowerCase()];
        });

        if (data.length) {
            $.each(data, function (i) {
                var item = this;
                $('<a href="#">' + item.title + '</a>')
                    .click(function () {
                        $(self.input).val(item.value);
                        self.clearLookahead();
                        if (opts.onAccept) {
                            opts.onAccept.call(self.input, item.value);
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
    };


    Lookahead.prototype.onchange = function () {
        var self = this;
        var opts = this.opts;
        if (this._loading_lookahead) return;

        var val = $(this.input).val();
        if (!val) {
            this.clearLookahead()
            return;
        }

        // Use cached data if it exists
        this.cache = this.cache || {};
        if (this.cache[val]) {
            return this.ajaxSuccess(this.cache[val]);
        }

        var url = typeof(opts.url) == 'function' ? opts.url() : opts.url;

        var params = { order: 'alpha' };
        if (opts.filterValue) val = opts.filterValue(val);
        var filterName = opts.filterName || 'filter';
        params[filterName] = '\\b' + val;
        
        this._loading_lookahead = true;
        $.ajax({
            url: url,
            data: $.extend(params, opts.params),
            cache: false,
            dataType: 'json',
            success: function (data) {
                self.cache[val] = data;
                self._loading_lookahead = false;
                return self.ajaxSuccess(data);
            },
            error: function (xhr, textStatus, errorThrown) {
                var lookahead = self.getLookahead();
                self._loading_lookahead = false;
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
