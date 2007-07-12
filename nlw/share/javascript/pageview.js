if (typeof ST == 'undefined') {
    ST = {};
}

// ST.Page calls
ST.Page = function (args) {
    $H(args).each(this._applyArgument.bind(this));
    Event.observe(window, 'load', this._loadInterface.bind(this));
};

ST.Page.prototype = {
    page_id: null,
    wiki_id: null,
    wiki_title: null,
    page_title: null,
    revision_id: null,
    comment_form_window_height: null,
    element: {
        toggleLink: 'st-page-boxes-toggle-link',
        accessories: 'st-page-boxes',
        underlay: 'st-page-boxes-underlay',
        pageEditing: 'st-page-editing',
        content: 'st-content-page-display'
    },
    hideAttributes: {
        onclick: 'showAccessories',
        text: '&gt;'
    },
    showAttributes: {
        onclick: 'hideAccessories',
        text: 'V'
    },

    restApiUri: function () {
        return '/data/workspaces/' + this.wiki_id + '/pages/' + this.page_id;
    },

    APIUri: function () {
        return '/page/' + this.wiki_id + '/' + this.page_id;
    },

    APIUriPageTag: function (tag) {
        return this.restApiUri() + '/tags/' + encodeURIComponent(tag);
    },

    APIUriPageTags: function () {
        return this.restApiUri() + '/tags';
    },

    UriPageTagDelete: function (id) {
        return this.APIUriPageTag(id);
    },

    UriPageAttachmentDelete: function (id) {
        return this. APIUriPageAttachment(id);
    },

    APIUriPageAttachment: function (id) {
        return this.AttachmentListUri + '/' + id;
    },

    AttachmentListUri: function () {
        return this.restApiUri() + '/attachments' + '?' + this.ieCacheFix();
    },

    ieCacheFix: function () {
        var date = new Date();
        return 'iecacheworkaround=' + date.toLocaleTimeString();
    },

    ContentUri: function () {
        return '/' + this.wiki_id + '/index.cgi';
    },

    active_page_exists: function (page_name) {
        page_name = trim(page_name);
        var uri = this.ContentUri();
        uri = uri + '?action=page_info;page_name=' + encodeURIComponent(page_name);
        var ar = new Ajax.Request (
            uri,
            {
                method: 'get',
                asynchronous: false,
                requestHeaders: ['Accept','text/javascript'],
                onFailure: (function(req, jsonHeader) {
                    alert('Could not retrieve the latest revision of the page');
                }).bind(this)
            }
        );
        var page_info = JSON.parse(ar.transport.responseText);
        return page_info.is_active;
    },

    refresh_page_content: function (force_update) {
        var uri = Page.restApiUri();
        uri = uri + '?verbose=1;link_dictionary=s2';
        uri = uri + '' + this.ieCacheFix()
        var request = new Ajax.Request (
            uri,
            {
                method: 'get',
                asynchronous: false,
                requestHeaders: ['Accept','application/json'],
                onFailure: (function(req, jsonHeader) {
                    alert('Could not retrieve the latest revision of the page');
                }).bind(this)
            }
        );

        if (request.transport.status == 403) {
            window.location = "/challenge";
            return;
        }

        if (request.transport.status == 200) {
            var page_info = JSON.parse(request.transport.responseText);
            if (page_info) {
                if ((Page.revision_id < page_info.revision_id) || force_update) {
                    $('st-page-content').innerHTML = page_info.html;
                    $('st-page-editing-revisionid').value = page_info.revision_id;
                    Page.revision_id = page_info.revision_id;
                    if ($('st-raw-wikitext-textarea')) {
                        $('st-raw-wikitext-textarea').value = Wikiwyg.is_safari
                            ? Wikiwyg.htmlUnescape(page_info.wikitext)
                            : page_info.wikitext;
                    }
                    var revisionNode = $('st-rewind-revision-count');
                    if (revisionNode) {
                        Element.update('st-rewind-revision-count', '&nbsp;&nbsp;' + page_info.revision_count);
                        Element.update('st-page-stats-revisions', page_info.revision_count + ' revisions');
                    }
                }
            }
        }
    },

    hideAccessories: function () {
        Cookie.set('st-page-accessories', 'hide');
        Element.hide(this.element.accessories);
        Element.update(this.element.toggleLink, this.hideAttributes.text);
        $(this.element.toggleLink).onclick = this[this.hideAttributes.onclick].bind(this);
        Element.setStyle('st-page-maincontent', {marginRight: '0px'});
    },

    showAccessories: function (leaveMarginAlone) {
        Cookie.set('st-page-accessories', 'show');
        Element.show(this.element.accessories);
        Element.update(this.element.toggleLink, this.showAttributes.text);
        $(this.element.toggleLink).onclick = this[this.showAttributes.onclick].bind(this);
        if (! Element.visible('st-pagetools')) {
            Element.setStyle('st-page-maincontent', {marginRight: '240px'});
        }
    },

    orientAccessories: function () {
        var s_height = $(this.element.accessories).offsetHeight;
        var s_width = $(this.element.accessories).offsetWidth;
        Element.setStyle(this.element.underlay, {height: s_height + 'px'});
        Element.setStyle(this.element.underlay, {width: s_width + 'px'});

        if (document.all) {
            var c_height = (
                 $(this.element.accessories).offsetHeight + (
                       $(this.element.accessories).offsetTop
                     - $(this.element.content).offsetTop
                 )
            );
            if ($(this.element.content).offsetHeight < c_height) {
                if (c_height > 0) {
                    $(this.element.content).style.height = c_height + 'px';
                }
            }
        }
    },

    installUnderlayOrienter: function () {
        /* We want to call it for the first time ASAP since it may
         * change the existing page layout */
        this.orientAccessories();
        setInterval(this.orientAccessories.bind(this), 1000);
    },

    _applyArgument: function (arg) {
        if (typeof this[arg.key] != 'undefined') {
            this[arg.key] = arg.value;
        }
    },

    _loadInterface: function () {
        var m = Cookie.get('st-page-accessories');
        if (m == null || m == 'show') {
            this.showAccessories();
        } else {
            this.hideAccessories();
        }
        this.installUnderlayOrienter();
    }
};

// ST.Page calls
ST.NavBar = function (args) {
    $H(args).each(this._applyArgument.bind(this));
    Event.observe(window, 'load', this._loadInterface.bind(this));
};

ST.NavBar.prototype = {
    element: {
        searchForm: 'st-search-form',
        searchButton: 'st-search-submit',
        searchField: 'st-search-term'
    },

    submit_search: function (arg) {
        $(this.element.searchForm).submit();
    },

    clear_search: function(arg) {
        if( $(this.element.searchField).value.match(/New\s*search/i) ) {
            $(this.element.searchField).value = "";
        }
    },

    _applyArgument: function (arg) {
        if (typeof this[arg.key] != 'undefined') {
            this[arg.key] = arg.value;
        }
    },

    _loadInterface: function () {
        var element = $(this.element.searchButton);
        if (! element) return;
        Event.observe(element, 'click', this.submit_search.bind(this));
        if (! $(this.element.searchField) ) return;
        Event.observe(this.element.searchField, 'click', this.clear_search.bind(this));
        Event.observe(this.element.searchField, 'focus', this.clear_search.bind(this));
    }
};
