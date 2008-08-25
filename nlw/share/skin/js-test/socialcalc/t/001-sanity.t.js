(function() {

var t = tt = new Test.Visual();

t.plan(1);

t.beginAsync(step1);

function step1() {
    t.open_iframe("/admin/index.cgi?admin_wiki", step2);
}

function step2() {
    t.ok(
        t.$("#st-pagetools-newspreadsheet").length,
        "SocialCalc is enabled for the admin workspace"
    );

    t.endAsync();
}

})();
