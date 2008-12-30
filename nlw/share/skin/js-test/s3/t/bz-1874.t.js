var t = new Test.Visual();

t.plan(1);

var original = t.gensym();
var incipient = t.gensym();

t.runAsync([
    function() {
        t.put_page({
            workspace: 'admin',
            page_name: original,
            content: "{include: [" + incipient + "]}\n",
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe(
            "/lite/page/admin/" + original,
            t.nextStep()
        );
    },

    function() { 
        t.like(
            $('a.wiki-include-edit-link', t.doc).attr('href'),
            /\/lite\//,
            "The edit link goes to /lite/ when viewed inside /lite/"
        );

        t.endAsync();
    }
]);
