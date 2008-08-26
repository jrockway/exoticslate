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
    var id = setInterval(function() {
        if (
            self.iframe.contentWindow.SocialCalc &&
            self.iframe.contentWindow.SocialCalc.editor_setup_finished
        ) {
            clearInterval(id);
            callback.apply(self);
        }
    }, 250);
}

})();
