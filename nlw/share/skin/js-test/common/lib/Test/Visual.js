// Class Test.Visual
(function(className, $) {
var proto = (Test.Visual = function() {
    this.init.apply(this, arguments);
    this.className = className;
}).prototype = new Test.Base();

proto.init = function() {
    Test.Base.prototype.init.call(this);
    this.block_class = 'Test.Visual.Block';
    this.doc = window.document;
    this.asyncId = 0;
}

proto.create_user = function(params) {
    $.ajax({
        url: "/data/users",
        type: 'POST',
        contentType: 'application/json',
        data: JSON.stringify({
            username: params.username,
            password: params.password,
            email_address: params.email_address
        }),
        success: params.callback
    });
}

proto.login = function(params) {
    if (!params) params = {};

    var username = (params.username || 'devnull1@socialtext.com');
    var password = (params.password || 'd3vnu11l');

    this.beginAsync({internal: true});

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
                success: params.callback
            });
        }
    });
}

proto.open_iframe = function(url, options) {
    if (! options)
        options = {};

    this.beginAsync({internal: true});

    this.iframe = $("<iframe />").prependTo("body").get(0);
    this.iframe.contentWindow.location = url;
    var $iframe = $(this.iframe);

    var self = this;
    $iframe.one("load", function() {
        self.doc = self.iframe.contentDocument;
        if (self.runTests)
            self.runTests.apply(self, [self]);
        
        self.endAsync({internal: true});
    });

    $iframe.height(options.h || 200);
    $iframe.width(options.w || 900);
}

proto.beginAsync = function(params) {
    if (!params) params = {};
    if (!params.timeout) params.timeout = 30000;
    if (this.asyncId) return;

    if (! params.internal)
        this.userAsync = true;

    this.asyncId = this.builder.beginAsync(params.timeout);
}

proto.endAsync = function(params) {
    if (!params) params = {};
    if (params.internal && this.userAsync) return;
    this.builder.endAsync(this.asyncId);
}

proto.bindLoad = function(cb) {
    var self = this;
    $(this.iframe).bind("load", function() {
        $(this.contentDocument).ready(function() {
            cb.apply(self);
        });
    });
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

proto.$ = function(selector) {
    return this.iframe.contentWindow.jQuery( selector );
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

})('Test.Visual', jQuery);


// Class Test.Visual.Block
(function(className) {
var proto = (Test.Visual.Block = function() {
    this.init.apply(this, arguments);
    this.className = className;
}).prototype = new Test.Base.Block();

proto.init = function() {
    Test.Base.Block.prototype.init.call(this);
    this.filter_object = new Test.Visual.Filter();
}

})('Test.Visual.Block');


// Class Test.Visual.Filter
(function(className) {
var proto = (Test.Visual.Filter = function() {
    this.init.apply(this, arguments);
    this.className = className;
}).prototype = new Test.Base.Filter();

// Filter functions go here...

})('Test.Visual.Filter');
