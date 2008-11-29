(function($) {

var t = new Test.Visual();

t.plan(3);

var pageName = "bz_1711_" + Math.random();

var doClickAddTagButton = function() { 
    t.scrollTo(t.$('#st-tags-addlink').offset().top);
    t.$('#st-tags-addlink').click();
    t.poll(function(){
        return t.$('#st-tags-field').is(':visible');
    }, function () { t.callNextStep(1000) } );
};

var testOffsets = function() { 
    t.ok(
        t.$('#st-tags-field').offset().left
            < t.$('#st-tags-addbutton-link').offset().left,
        "Adding a tag: Input and button does not wrap inbetween"
    );

    t.callNextStep();
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

    doClickAddTagButton,
    testOffsets,
            
    function() { 
        t.$('#st-tags-field').val('Hello World');
        t.$('#st-tags-form').submit();
        t.poll(function(){
            return t.$('a.addTagButton').is(':visible');
        }, function () { t.callNextStep() } );
    },
    
    doClickAddTagButton,
    testOffsets,
            
    function() { 
        t.$('#st-tags-field').val('xxx');
        t.$('#st-tags-form').submit();
        t.poll(function(){
            return t.$('a.addTagButton').is(':visible');
        }, function () { t.callNextStep() } );
    },

    doClickAddTagButton,
    testOffsets,
    
    function() { 
        t.endAsync();
    }
]);

})(jQuery);
