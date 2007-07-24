
if (Socialtext.box_javascript) {
    createPageObject();
    window.Attachments = new ST.Attachments ();
    window.Tags = new ST.Tags ();
    window.TagQueue = new ST.TagQueue ();
    window.Watchlist = new ST.Watchlist();
    Event.observe(window, 'load',
        function() {
            window.Watchlist._loadInterface('st-watchlist-indicator');
        }
    );
}

window.NavBar = new ST.NavBar ();

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
