proto = new Subclass('Test.Visual', 'Test.Base');

proto.doc = window.document;

proto.init = function() {
    Test.Base.prototype.init.call(this);
    this.block_class = 'Test.Visual.Block';
}

proto.open = function(url, cb) {
    var asyncId = this.builder.beginAsync(60000);

    this.iframe = jQuery("<iframe />").prependTo("body").get(0);
    this.iframe.contentWindow.location = url;

    var self = this;
    jQuery(this.iframe).bind("load", function() {
        self.doc = self.iframe.contentDocument;
        cb.apply(self, [self]);

        self.builder.endAsync(asyncId);
    });
}

// Test functions go here...
proto.elements_do_not_overlap = function(selector1, selector2, reason) {
    var element1 = this._get_selector_element(selector1);
    var element2 = this._get_selector_element(selector2);

    var $e1 = jQuery(element1);
    var $e2 = jQuery(element2);

    var off1 = $e1.offset();
    var off2 = $e2.offset();

    if (
        (off1.top + $e1.height() > off2.top) &&
        (off1.left + $e1.width() > off2.left)
        ) {
        this.fail(reason);
        return;
    }

    this.pass(reason);
}

proto._get_selector_element = function(selector) {
    var $result = jQuery(selector, this.doc);
    if ($result.length <= 0)
        throw("Nothing found for selector: '" + selector +"'");
    if ($result.length >= 2) {
        throw(String($result.length) + " elements found for selector: '" +
            selector +"'"
        );
    }
    return $result.get(0);
}

proto = Subclass('Test.Visual.Block', 'Test.Base.Block');

proto.init = function() {
    Test.Base.Block.prototype.init.call(this);
    this.filter_object = new Test.Visual.Filter();
}

proto = new Subclass('Test.Visual.Filter', 'Test.Base.Filter');

// Filter functions go here...
