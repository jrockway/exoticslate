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
}

proto.open_iframe = function(url, options) {
    if (! options)
        options = {};

    var asyncId = this.builder.beginAsync(60000);

    this.iframe = $("<iframe />").prependTo("body").get(0);
    this.iframe.contentWindow.location = url;
    var $iframe = $(this.iframe);

    var self = this;
    $iframe.bind("load", function() {
        self.doc = self.iframe.contentDocument;
        if (self.runTests)
            self.runTests.apply(self, [self]);

        self.builder.endAsync(asyncId);
    });

    $iframe.height(options.h || 200);
    $iframe.width(options.w || 900);
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
