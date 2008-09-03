/* 
This test is for this task: https://www2.socialtext.net/dev-tasks/index.cgi?story_watchlist_and_revisions_icons_are_updated_for_s3_design
Instead of testing any visual requirements, it's only testing if a.revision and a.watch are under #controlsRight.

*/
(function($) {

var t = new Test.Visual();

t.plan(2);

t.beginAsync(step1);

function step1() {
    t.open_iframe("/admin/index.cgi?admin_wiki", step2);
}

function step2() {
    t.is(
        t.$("#controlsRight ul li a.watch").size(),
        1,
        "There is a watch link under #controlsRight"
    );

    t.is(
        t.$("#controlsRight ul li a.revision").size(),
        1,
        "There is a revision link under #controlsRight"
    );

    t.endAsync();
};

})(jQuery);
