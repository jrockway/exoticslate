(function () {
    
/* TODO We tried to create a subclass by hand, but failed :( */
// if (!Test) Test = {};
// 
// if (!Test.Performance) {
//     Test.Performance = function() {
//         try {
//             this.init();
//         }
//         catch(e) {
//             console.log(e);
//         }
//     };
// }
// 
// Test.Performance.prototype = Test.Base;
// var proto = Test.Performance.prototype;

var proto = Subclass("Test.Performance", "Test.Base");

proto.init = function() {
    Test.Base.prototype.init.call(this);
    this.block_class = 'Test.Performance.Block';
}

var types = {
    json: "/data/workspaces/help-en/pages/",
    html: "/data/workspaces/help-en/pages/",
    wikitext: "/data/workspaces/help-en/pages/"
};

var accept = {
    json: "application/json",
    html: "text/html",
    wikitext: "text/x.socialtext-wiki"
};

proto.test_page_load = function(page_name, time) {
    page_id = page_name.toLowerCase();

    for (var type in accept) {
        this.timedLoad(
            types[type] + page_id + "/?accept=" + accept[type],
            time,
            page_name + "/" + type
        );
    }
}

proto.timedLoad = function(url, expectedTime, desc) {
    if (! expectedTime) expectedTime = 1000;
    if (! desc) desc = "";

    var start = new Date();
    Ajax.get(url); 
    var end = new Date();
    var difference = end.getTime() - start.getTime();

    this.ok(
        difference <= expectedTime,
        desc + " - '" + url + "' loaded in " + difference + "ms" +
        " - less than " + String(expectedTime) + "ms"
    );
}

proto.ok = function(result, desc) {
    this.builder.ok(result, desc);
}

})();
