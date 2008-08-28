(function() {

proto = Test.Base.newSubclass('Test.SocialCalc', 'Test.Visual');

proto.open_iframe_with_socialcalc = function(url, callback) {
    var self = this;
    this.open_iframe(url, function() {
        self.wait_for_socialcalc(callback);
    });
}

proto.wait_for_socialcalc = function(callback) {
    var self = this;
    this.$.poll(
        function() {
            return Boolean(
                self.iframe.contentWindow.SocialCalc &&
                self.iframe.contentWindow.SocialCalc.editor_setup_finished
            );
        },
        function() {
            callback.apply(self);
        },
        250, 15000
    );
}

})();
