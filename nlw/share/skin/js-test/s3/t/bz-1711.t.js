(function($) {

var t = new Test.Visual();

t.plan(3);

var pageName = "bz_1711_" + t.gensym();

var doClickAddTagButton = function() { 
    return function() {
        t.$('#st-tags-addlink').click();
        t.poll(function(){
            return t.$('#st-tags-field').is(':visible');
        }, function () { t.callNextStep(1000) } );
    };
};

var doSubmitAddTagForm = function(tag) {
    return function() {
        t.$('#st-tags-field').val(tag);
        t.$('#st-tags-form').submit();
        t.poll(function(){
            t.scrollTo(t.$('a.addTagButton').offset().top);
            return t.$('a.addTagButton').is(':visible');
        }, function () { t.callNextStep() } );
    };
};

var testOffsets = function() { 
    return function() {
        t.scrollTo(t.$('#st-tags-field').offset().top);
        t.ok(
            t.$('#st-tags-field').offset().left
                < t.$('#st-tags-addbutton-link').offset().left,
            "Adding a tag: Input and button does not wrap inbetween"
        );
        t.callNextStep();
    };
};
t.runAsync([
    function() {
        t.put_page({
            workspace: 'admin',
            page_name: pageName,
            content: "fnord\n",
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe(
            "/admin/index.cgi?" + pageName,
            t.nextStep(),
            {w: '1024px'}
        );
    },

    doClickAddTagButton(),
    testOffsets(),
    doSubmitAddTagForm('Hello World'),
            
    doClickAddTagButton(),
    testOffsets(),
    doSubmitAddTagForm('xxx'),

    doClickAddTagButton(),
    testOffsets(),
    
    function() { 
        t.endAsync();
    }
]);

})(jQuery);
