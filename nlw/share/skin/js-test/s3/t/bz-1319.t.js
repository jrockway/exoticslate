(function($) {

var t = new Test.Visual();

t.plan(1);

t.runAsync([
    function() {
        t.open_iframe("/admin/index.cgi?bz_1319_" + Math.random(), t.nextStep(), { w: '500px' });
    },
            
    function() { 
        setTimeout(function(){
            t.is(
                t.$('#st-editing-tools-edit').offset().top,
                t.$('#controlsRight').offset().top,
                'controlsRight did not drop down to reveal a giant blue bar.'
            );

            t.endAsync();
        }, 2500);
    }
]);

})(jQuery);
