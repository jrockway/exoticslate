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
 *       // OPTIONAL: use this function to change the way the result is
 *       // displayed in the input box
 *       displayAs: function (item) {
 *           return item.title;
 *       }
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

    var FETCH_COUNT = 20;
    var VIEW_COUNT = 5;

    var KEYCODES = {
        DOWN: 40,
        UP: 38,
        ENTER: 13,
        SHIFT: 16,
        ESC: 27,
        TAB: 9
    };

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
                if (e.keyCode == KEYCODES.ESC) {
                    $(input).val('').blur();
                    self.clearLookahead();
                }
                else if (e.keyCode == KEYCODES.ENTER) {
                    self.accept();
                }
                else if (e.keyCode == KEYCODES.DOWN) {
                    self.selectDown();
                }
                else if (e.keyCode == KEYCODES.UP) {
                    self.selectUp();
                }
                else if (e.keyCode != KEYCODES.TAB && e.keyCode != KEYCODES.SHIFT) {
                    self.onchange();
                }
                return false;
            })
            .unbind('keydown')
            .keydown(function(e) {
                if (self.lookahead && self.lookahead.is(':visible')) {
                    if (e.keyCode == KEYCODES.TAB) {
                        if (self._firstItem) {
                            self.accept(self._firstItem);
                        }
                        return false;
                    }
                    else if (e.keyCode == KEYCODES.ENTER) {
                        return false;
                    }
                }
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

    Lookahead.prototype.clearLookahead = function () {
        this._cache = {};
        this.hide();
    };

    Lookahead.prototype.getLookahead = function () {
        /* Subract the offsets of all absolutely positioned parents
         * so that we can position the lookahead directly below the
         * input element. I think jQuery's offset function should do
         * this for you, but maybe they'll fix it eventually...
         */
        var left = $(this.input).offset().left;
        var top = $(this.input).offset().top + $(this.input).height() + 10;

        if (!this.lookahead) {
            this.lookahead = $('<ul></ul>')
                .css({
                    overflow: 'hidden',
                    textAlign: 'left',
                    zIndex: 2500,
                    position: 'absolute',
                    background: '#B4DCEC',
                    border: '1px solid black',
                    display: 'none',
                    padding: '0px'
                })
                .prependTo('body');
        }

        this.lookahead.css({
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

    Lookahead.prototype.filterRE = function (val) {
        return new RegExp('\\b(' + val + ')', 'ig');
    };
    
    Lookahead.prototype.filterData = function (val, data) {
        var self = this;

        var filtered = [];
        var re = this.filterRE(val);

        $.each(data, function() {
            if (filtered.length >= VIEW_COUNT) return;

            var title = self.linkTitle(this);
            if (title.match(re)) {
                filtered.push({
                    title: title.replace(re, '<b>$1</b>'),
                    value: self.linkValue(this)
                });
            }
        });

        return filtered;
    };

    Lookahead.prototype.displayData = function (data) {
        var opts = this.opts;
        var lookahead = this.getLookahead();
        lookahead.html('');

        if (data.length) {
            this._firstItem = data[0];
            $.each(data, function (i) {
                var item = this || {};
                var li = $('<li></li>')
                    .css({ padding: '3px 5px' })
                    .appendTo(lookahead);
                $('<a href="#"></a>')
                    .html(item.title)
                    .attr('value', item.value)
                    .click(function () {
                        self.accept(item);
                        return false;
                    })
                    .appendTo(li);
            });
            this.show();
        }
        else {
            this.hide();
        }
    };

    Lookahead.prototype.show = function () {
        var lookahead = this.getLookahead();
        if (!lookahead.is(':visible')) {
            lookahead.fadeIn();
        }
    };

    Lookahead.prototype.hide = function () {
        var lookahead = this.getLookahead();
        if (lookahead.is(':visible')) {
            lookahead.fadeOut();
        }
    };

    Lookahead.prototype.accept = function (item) {
        this.clearLookahead();

        var value = item ? item.value : $(this.input).val();

        if (item) {
            if ($.isFunction(this.opts.displayAs))
                $(this.input).val(this.opts.displayAs(item));
            else
                $(this.input).val(item.value);
        }

        if (this.opts.onAccept) {
            this.opts.onAccept.call(this.input, value);
        }
    }

    Lookahead.prototype.select = function (el) {
        jQuery('li.selected', this.lookahead)
            .removeClass('selected')
            .css({ background: '' });
        el.addClass('selected').css({ background: '#7DBFDB' });
        $(this.input).val(el.children('a').attr('value'));
    }

    Lookahead.prototype.selectDown = function () {
        if (!this.lookahead) return;
        this.select(
            jQuery('li.selected', this.lookahead).length
            ? jQuery('li.selected', this.lookahead).next('li')
            : jQuery('li:first', this.lookahead)
        );
    };

    Lookahead.prototype.selectUp = function () {
        if (!this.lookahead) return;
        this.select(
            jQuery('li.selected', this.lookahead).length
            ? jQuery('li.selected', this.lookahead).prev('li')
            : jQuery('li:last', this.lookahead)
        );
    };

    Lookahead.prototype.storeCache = function (val, data) {
        this._cache = this._cache || {};
        this._cache[val] = data;
        this._prevVal = val;
    }

    Lookahead.prototype.getCached = function (val) {
        this._cache = this._cache || {};

        if (this._cache[val]) {
            // We've already done this query, so just return this data
            return this.filterData(val, this._cache[val])
        }
        else if (this._prevVal) {
            var re = this.filterRE(this._prevVal);
            if (val.match(re)) {
                // filter the previous data, but only return if we still
                // have at least the minimum or if filtering the data made
                // no difference
                var cached = this._cache[this._prevVal];
                if (cached) {
                    filtered = this.filterData(val, cached)
                    var use_cache = cached.length == filtered.length
                                 || filtered.length >= VIEW_COUNT;
                    if (use_cache) {
                        // save this for next time
                        this.storeCache(val, cached);
                        return filtered;
                    }
                }
            }
        }
        return [];
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

        var cached = this.getCached(val);
        if (cached.length) {
            this.displayData(cached);
            return;
        }

        var url = typeof(opts.url) == 'function' ? opts.url() : opts.url;

        var params = { order: 'alpha', count: FETCH_COUNT };
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
                self.storeCache(val, data);
                self._loading_lookahead = false;
                self.displayData(
                    self.filterData(val, data)
                );
            },
            error: function (xhr, textStatus, errorThrown) {
                var lookahead = self.getLookahead();
                self._loading_lookahead = false;
                if (opts.onError) {
                    var errorHandler = opts.onError[xhr.status]
                                    || opts.onError['default'];
                    if (errorHandler) {
                        if ($.isFunction(errorHandler)) {
                            lookahead.html(
                                errorHandler( xhr, textStatus, errorThrown )
                            );
                        }
                        else {
                            lookahead.html( errorHandler );
                        }
                        this.show();
                    }
                }
            }
        });
    };

})(jQuery);
