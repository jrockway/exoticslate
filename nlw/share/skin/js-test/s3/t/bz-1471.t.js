var t = new Test.Visual();

t.plan(2);

var v = "VeryLongLineVeryLongLine"
      + "VeryLongLineVeryLongLine"
      + "VeryLongLine ";

t.runAsync([
    t.doCreatePage(
        v + v + v + v + v + "\n\n"
      + ".pre\n"
      + v + v + v + v + "\n"
      + ".pre\n"
    ),

    function() { 
        t.is(
            t.$('#contentLeft').offset().top,
            t.$('#contentRight').offset().top,
            "Mixed .pre and non-.pre long lines should not drop contentRight"
        );

        t.isnt(
            t.$('.wiki p:first').height(),
            t.$('.wiki pre:first').height(),
            "Reflow did not cause all paragraphs to abort linebreaking"
        );

        t.endAsync();
    }
]);
