// Watchlist

ST.Watchlist = function() {};

ST.Watchlist.prototype = {
    isBeingWatched: false,
    image: null,

    button_activate: function () {
        if (!this.isBeingWatched) {
            this.image.src = this._image_src('hover');
        }
        return false;
    },

    button_default: function () {
        if (this.isBeingWatched) {
            this.image.src = this._image_src('on');
        }
        else {
            this.image.src = this._image_src('off');
        }
        return false;
    },

    _image_src: function(type) {
        return nlw_make_static_path(
            '/images/st/pagetools/watch-' + type + '.gif'
        );
    },

    _toggle_watch_state: function () {
        var wiki_id = Socialtext.wiki_id || Page.wiki_id;
        var action = (this.isBeingWatched) ? 'remove_from' : 'add_to';
        var page_id = this.page_id || Page.page_id;
        var uri = '/' + wiki_id + '/index.cgi' +
                  '?action=' + action + '_watchlist;page=' + page_id;

        var ar = new Ajax.Request (
            uri,
            {
                method: 'get',
                onComplete: (function (req) {
                    if (req.responseText == '1' || req.responseText == '0') {
                        this.isBeingWatched = ! this.isBeingWatched;
                        this.button_default();
                    } else {
                        this._display_toggle_error();
                    }
                }).bind(this),
                onFailure: (function(req, jsonHeader) {
                    this._display_toggle_error();
                }).bind(this)
            }
        );
    },

    _display_toggle_error: function () {
        if (this.isBeingWatched) {
            alert('Could not remove page from watchlist');
        }
        else {
            alert('Could not add page to watchlist');
        }
    },

    _applyArgument: function (arg) {
        if (typeof this[arg.key] != 'undefined') {
            this[arg.key] = arg.value;
        }
    },

    _loadInterface: function (indicator) {
        this.image = $(indicator);
        if (this.image) {
            if (this.image.src.match(/watch-on/)) {
                this.isBeingWatched = true;
            }
            else {
                this.isBeingWatched = false;
            }

            Event.observe(indicator,  'click', this._toggle_watch_state.bind(this));
            Event.observe(indicator,  'mouseover', this.button_activate.bind(this));
            Event.observe(indicator,  'mouseout', this.button_default.bind(this));
        }
    }
};

if (Socialtext.box_javascript) {
    window.Watchlist = new ST.Watchlist();
    Event.observe(window, 'load', function() {
            window.Watchlist._loadInterface('st-watchlist-indicator');
        }
    );
}

Event.observe(window, 'load', function() {
    var toggles = document.getElementsByClassName('watchlist-list-toggle');
    for (var ii = 0; ii < toggles.length; ii++) {
        var toggle = toggles[ii];
        var page_id = toggle.getAttribute('alt');
        var wl = new ST.Watchlist();
        wl.page_id = page_id;
        wl._loadInterface(toggle);
    }
});
