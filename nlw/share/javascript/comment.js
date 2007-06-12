if (typeof ST == 'undefined') {
    ST = {};
}

ST.Comment = function () {
    Event.observe(window, 'load', function () {
        var comment_button = $('st-comment-button-link');
        if (comment_button) {
            if (! comment_button.href.match(/#$/)) {
                return;
            }

            Event.observe('st-comment-button-link', 'click', function () {
                ST.Comment.launchCommentInterface({
                    page_name: Page.page_id,
                    action: 'display',
                    height: Page.comment_form_window_height
                });
                return false;
            });
            var below_fold_comment_link = $('st-edit-actions-below-fold-comment');
            if (below_fold_comment_link) {
                if (! below_fold_comment_link.href.match(/#$/)) {
                    return;
                }

                Event.observe('st-edit-actions-below-fold-comment', 'click', function () {
                    ST.Comment.launchCommentInterface({
                        page_name: Page.page_id,
                        action: 'display',
                        height: Page.comment_form_window_height
                    });
                    return false;
                });
            }
        }
    });
};

ST.Comment.launchCommentInterface = function (args) {
    var display_width = (window.offsetWidth || document.body.clientWidth || 600);
    var page_name     = args.page_name;
    var action        = args.action;
    var height        = args.height;
    var comment_window = window.open(
        'index.cgi?action=enter_comment;page_name=' + page_name + ';caller_action=' + action,
        '_blank',
        'toolbar=no, location=no, directories=no, status=no, menubar=no, titlebar=no, scrollbars=yes, resizable=yes, width=' + display_width + ', height=' + height + ', left=' + 50 + ', top=' + 200
    );

    if ( navigator.userAgent.toLowerCase().indexOf("safari") != -1 ) {
        window.location.reload();
    }

    return false;
};

Comment = new ST.Comment ();
