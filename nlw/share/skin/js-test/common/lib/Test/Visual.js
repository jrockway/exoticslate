(function($) { 

var proto = Test.Base.newSubclass('Test.Visual');

proto.init = function() {
    Test.Base.prototype.init.call(this);
    this.block_class = 'Test.Visual.Block';
    this.doc = window.document;
    this.asyncId = 0;
}

// Move to Test.Base
proto.diag = function() {
    return;
    this.builder.diag.apply(this.builder, arguments);
}

proto.is_no_harness = function() {
    if (window.top.Test.Harness) {
        this.builder.diag(
            "Can't run test " + (this.builder.CurrTest + 1) + " in the harness"
        );
        this.builder.skip(arguments[2]);
    }
    else
        this.is.apply(this, arguments);
}

/*
Create a new user and optionally add to a workspace.

- params:
  - username
  - password
  - email_address
  - workspace (optional)
  - callback: required function of what to do afterwards
*/
proto.create_user = function(params, callback) {
    var self = this;

    var add_to_workspace = function() {
        $.ajax({
            url: "/data/workspaces/" + params.workspace + '/users',
            type: 'POST',
            contentType: 'application/json',
            data: JSON.stringify({
                username: params.username,
                rolename: "member",
                send_confirmation_invitation: 0
            }),
            success: function() {
                self.call_callback(callback);
            }
        });
    }

    var callback2 = params.workspace
        ? add_to_workspace
        : callback;

    $.ajax({
        url: "/data/users",
        type: 'POST',
        contentType: 'application/json',
        data: JSON.stringify({
            username: params.username,
            password: params.password,
            email_address: params.email_address
        }),
        success: function() {
            self.call_callback(callback2);
        }
    });
}

/*
Put a (new) page to a workspace.

- params:
  - email_address
  - workspace
  - page_name
  - content
  - callback: required function of what to do afterwards
*/
proto.put_page = function(params) {
    var self = this;

    var workspace = params.workspace;
    var page_name = encodeURIComponent(params.page_name);

    $.ajax({
        url: "/data/workspaces/" + workspace + "/pages/" + page_name,
        type: 'PUT',
        contentType: 'application/json',
        data: params.content, 
        beforeSend: function(xhr) {
            xhr.setRequestHeader("Content-Type", "text/x.socialtext-wiki");
        },
        success: function() {
            if( $.isFunction(params.callback) )
                self.call_callback(params.callback);
        }
    });
}


proto.login = function(params, callback) {
    var username = (params.username || 'devnull1@socialtext.com');
    var password = (params.password || 'd3vnu11l');

    var self = this;
    $.ajax({
        url: "/nlw/submit/logout",
        complete: function() {
            $.ajax({
                url: "/nlw/submit/login",
                type: 'POST',
                data: {
                    'username': username,
                    'password': password
                },
                success: function() {
                    self.call_callback(callback);
                }

            });
        }
    });
}

proto.open_iframe = function(url, callback, options) {
    if (! (url && callback))
        throw("usage: open_iframe(url, callback, [options])");
    if (! options)
        options = {};

    if (!this.iframe)
        this.iframe = $("<iframe />").prependTo("body").get(0);
    this.iframe.contentWindow.location = url;
    var $iframe = $(this.iframe);

    $iframe.height(options.h || 200);
    $iframe.width(options.w || "100%");

    var height = $iframe.height();
    var width = $iframe.width();

    if ($("div.iframe_info").length == 0) {
        $(
            '<div class="iframe_info" style="padding-bottom: 5px">' +
            '<b>Size: <span>' + height + 'x' + width + '</span> &nbsp;&nbsp;&nbsp;' + 
            'URL: ' +
            '<input style="width:400px" class="iframe_location" value="' +
            url +'" />' +
            '</b></div>'
        ).prependTo("body");
    }
    else {
        $("div.iframe_info span").html(height + "x" + width);
        $("input.iframe_location").val(url);
    }

    var self = this;
    $iframe.one("load", function() {
        self.doc = self.iframe.contentDocument;
        self.win = self.iframe.contentWindow;
        self.$ = self.iframe.contentWindow.jQuery;
        
        self.call_callback(callback);
    });
}

proto.setup_one_widget = function(url, callback) {
    if (! (url && callback))
        throw("usage: setup_one_widget(url, callback)");
    var self = this;
    var setup_widget = function() {
        self.iframe.contentWindow.location = url;
        $(self.iframe).one("load", function() {
            var iframe = self.$('iframe').get(0);
            if (! iframe) throw("setup_one_widget failed");
            var widget = {
                'iframe': iframe,
                '$': iframe.contentWindow.jQuery
            };
            self.call_callback(callback, [widget]);
        });
    }
    this.open_iframe("/?action=clear_widgets", setup_widget);
}

proto.create_anonymous_user_and_login = function(params, callback) {
    if (!params.password) params.password = 'd3vnu11l';

    var ts = (new Date()).getTime();
    this.anonymous_username = 'user' + ts + '@example.com';
    var email_address = 'email' + ts + '@example.com';

    if (!params.username) params.username = this.anonymous_username;
    if (!params.email_address) params.email_address = email_address;

    var self = this;
    this.create_user(
        params,
        function() {
            self.login(params, callback);
        }
    );
}

proto.call_callback = function(callback, args) {
    if (!args) args = [];
    if (! this.asyncId)
        throw("You forgot to call beginAsync()");
    callback.apply(this, args);
}

proto.beginAsync = function(callback, timeout) {
    if (!timeout) timeout = 60000;
    if (this.asyncId)
        throw("beginAsync already called");
    this.asyncId = this.builder.beginAsync(timeout);
    var self = this;
    setTimeout(
        function() {
            if (self.asyncId)
                throw("Test timed out. Did you forget to call endAsync?");
        },
        timeout
    );
    if (callback)
        this.call_callback(callback);
}

proto.endAsync = function() {
    if (! this.asyncId)
        throw("endAsync called out of order");
    this.builder.endAsync(this.asyncId);
    this.asyncId = 0;
}

proto.scrollTo = function(vertical, horizontal) {
    if (!horizontal) horizontal = 0;
    this.iframe.contentWindow.scrollTo(horizontal, vertical);
}

proto.bindLoad = function(cb) {
    var self = this;
    $(this.iframe).bind("load", function() {
        $(this.contentDocument).ready(function() {
            cb.apply(self);
        });
    });
}

// Maybe extend jQuery with this.
// Uses hairy jQuery internals cargo culting.
proto.callEventHandler = function(query, event) {
    var elem = this.$(query)[0];
    var handle = this.$.data(elem, "handle");
    var data = this.$.makeArray();
    data.unshift({
        type: event,
        target: elem,
        preventDefault: function(){},
        stopPropagation: function(){},
        timeStamp: null
    });

    if (handle)
        var val = handle.apply( elem, data );

    return val;
}

proto.elements_do_not_overlap = function(selector1, selector2, name) {
    var $e1 = $(this._get_selector_element(selector1));
    var $e2 = $(this._get_selector_element(selector2));

    var r1 = $e1.offset();
    r1.bottom = r1.top + $e1.height();
    r1.right = r1.left + $e1.width();

    var r2 = $e2.offset();
    r2.bottom = r2.top + $e2.height();
    r2.right = r2.left + $e2.width();

    if ((r1.bottom > r2.top) &&
        (r1.top < r2.bottom) &&
        (r1.right > r2.left) &&
        (r1.left < r2.right))
    {
        this.fail(name);
        return;
    }

    this.pass(name);
}

proto._get_selector_element = function(selector) {
    var $result = $(selector, this.doc);
    if ($result.length <= 0)
        throw("Nothing found for selector: '" + selector + "'");
    if ($result.length >= 2) {
        throw(String($result.length) + " elements found for selector: '" +
            selector + "'"
        );
    }
    return $result.get(0);
}

})(jQuery);
