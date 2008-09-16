(function() {

var t = new Test.Visual();

t.plan(1);

t.runAsync([
    function() {
        t.open_iframe("/admin/index.cgi?admin_wiki", t.nextStep());
    },

    function() {
        t.ok(
            t.$("#st-pagetools-newspreadsheet").length,
            "SocialCalc is enabled for the admin workspace"
        );

        t.endAsync();
    }
]);

})();
