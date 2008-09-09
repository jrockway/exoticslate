(function($) { 

var proto = Test.Base.newSubclass('Test.Visual');

proto.init = function() {
    Test.Base.prototype.init.call(this);
    this.block_class = 'Test.Visual.Block';
    this.doc = window.document;
    this.asyncId = 0;
}

// This vicious hack replaces the guts of the Test.Harness. For some reason
// this fixture gets the Harness iframe to have its location messed up.
// We don't know why yet, but this is a workaround for now.
if (window.top.Test.Harness && ! window.top.Test.Harness.viciously_hacked) {
    window.top.Test.Harness.viciously_hacked = true;
    var runTest = window.top.Test.Harness.Browser.prototype.runTest;
    var path = '';
    window.top.Test.Harness.Browser.prototype.runTest =
        function (file, buffer) {
            if (! path)
                path = buffer.location.pathname.replace(/(.*)\/.*/, '$1');
            file = path + '/' + file;
            if (/\.html$/.test(file)) {
                buffer.location.replace(file);
            } else {
                runTest.apply([this, arguments]);
            }
        }
}

// Move to Test.Base
proto.diag = function() {
    this.builder.diag.apply(this.builder, arguments);
}

proto.runAsync = function(args) {
    if (args.plan)
        this.plan(args.plan);

    this.asyncSteps = args.steps;
    this.asyncStep = 0;

    this.beginAsync(this.nextStep()); 
}

proto.nextStep = function() {
    return this.asyncSteps[this.asyncStep++];
}

proto.callNextStep = function() {
    this.call_callback(this.nextStep());
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
                    if (callback)
                        self.call_callback(callback);
                }

            });
        }
    });
}

proto.test_iframe_html = 
    '<div class="iframe_info" style="padding-bottom: 5px">' +
    '<b>Size: <span>100 x 100</span> &nbsp;&nbsp;&nbsp;' + 
    'URL: <input style="width:400px" class="iframe_location" value="/" />' +
    '</b></div>'

proto.open_iframe = function(url, callback, options) {
    if (! (url && callback))
        throw("usage: open_iframe(url, callback, [options])");
    if (! options)
        options = {};

    if (!this.iframe) {
        this.iframe = $("<iframe />").prependTo("body").get(0);
        $(this.test_iframe_html).prependTo("body");
    }
    this.iframe.contentWindow.location = url;
    var $iframe = $(this.iframe);

    $iframe.height(options.h || 200);
    $iframe.width(options.w || "100%");

    $("div.iframe_info span").html($iframe.height() + "x" + $iframe.width());
    $("input.iframe_location").val(url);

    var self = this;
    $iframe.one("load", function() {
        self.doc = self.iframe.contentDocument;
        self.win = self.iframe.contentWindow;
        self.$ = self.iframe.contentWindow.jQuery;
        
        self.call_callback(callback);
    });
}

proto.setup_one_widget = function(params, callback) {
    var url = typeof(params) == 'string' ? params : params.url;
    if (typeof(params) == 'string') params = {};
    var self = this;
    var setup_widget = function() {
        self.iframe.contentWindow.location = url;
        $("input.iframe_location").val(url);
        $(self.iframe).one("load", function() {
            var widget = self._get_widget();
            if (params.noPoll) {
                self.call_callback(callback, [widget]);
                return;
            }
            self.$.poll(
                function() { return Boolean(widget.win.gadgets.loaded) },
                function() { self.call_callback(callback, [widget])}
            );
        });
    }
    this.open_iframe("/?action=clear_widgets", setup_widget);
}

proto.getWidget = function(widget_name, callback) {
    var widget = this._get_widget(widget_name);
    var self = this;
    this.$.poll(
        function() { return Boolean(widget.win.gadgets.loaded) },
        function() { self.call_callback(callback, [widget])}
    );
}

proto._get_widget = function(widget_name) {
    var query = widget_name ? 'iframe.' + widget_name : 'iframe';
    var iframe = this.$(query).get(0);
    if (! iframe) throw("getWidget failed");
    var widget = {
        'iframe': iframe,
        'win': iframe.contentWindow,
        '$': iframe.contentWindow.jQuery
    };
    return widget;
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

// XXX Local patch to make diagnostic output render correctly
// Eventually move this back up into Test.Builder

Test.Builder.prototype._setupOutput = function () {
    if (Test.PLATFORM == 'browser') {
        var top = Test.Builder.globalScope;
        var doc = top.document;
        var writer = function (msg) {
            // I'm sure that there must be a more efficient way to do this,
            // but if I store the node in a variable outside of this function
            // and refer to it via the closure, then things don't work right
            // --the order of output can become all screwed up (see
            // buffer.html).  I have no idea why this is.
            var body = doc.body || doc.getElementsByTagName("body")[0];
            var node = doc.getElementById('test_output')
                || doc.getElementById('test');
            if (!node) {
                node = document.createElement('pre');
                node.id = 'test_output';
                body.appendChild(node);
            }

            // This approach is neater, but causes buffering problems when
            // mixed with document.write. See tests/buffer.html.

            if (node.childNodes.length) {
                var span = document.createElement('span');
                span.innerHTML = msg;
                node.appendChild(span);
                return;
            }

            // If there was no text node, add one.
            node.appendChild(doc.createTextNode(msg));
            top.scrollTo(0, body.offsetHeight || body.scrollHeight);
            return;
        };

        this.output(writer);
        this.failureOutput(function (msg) {
            msg = msg
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;');
            writer('<span style="color: red; font-weight: bold">'
                   + msg + '</span>')
        });
        this.todoOutput(writer);
        this.endOutput(writer);

        if (top.alert.apply) {
            this.warnOutput(top.alert, top);
        } else {
            this.warnOutput(function (msg) { top.alert(msg); });
        }

    } else if (Test.PLATFORM == 'director') {
        // Macromedia-Adobe:Director MX 2004 Support
        // XXX Is _player a definitive enough object?
        // There may be an even more explicitly Director object.
        /*global trace */
        this.output(trace);       
        this.failureOutput(trace);
        this.todoOutput(trace);
        this.warnOutput(trace);

    } else if (Test.PLATFORM == 'wsh') {
        // Windows Scripting Host Support
        var printer = function (msg) {
			WScript.StdOut.writeline(msg);
		}
		this.output(printer);
		this.failureOutput(printer);
		this.todoOutput(printer);
		this.warnOutput(printer);

    } else if (Test.PLATFORM == 'interp') {
        // Command-line interpeter.
        var out = function (toOut) { print( toOut.replace(/\n$/, '') ); };
        this.output(out);
        this.failureOutput(out);
        this.todoOutput(out);
        this.warnOutput(out);
	}
    return this;
};
