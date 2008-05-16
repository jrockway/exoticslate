
function linked_tag(context) { return '<a target="_top" href="/data/tags/'+context.tag+'">'+context.tag+'</a>';}
function linked_person(actor) { return linked_person_name(actor.fields.name);};
function linked_person_name(name) { return '<a target="_top" href="/data/people/'+name+'">'+name+'</a>'};
function linked_page(context) { return '<a target="_top" href="/'+context.workspace_name+'/index.cgi?'+context.page_name+'">'+context.page_name+' ['+context.workspace_name+']</a>'};

var constructors = {
    'default': {
        'sentence': "%(actor)s performed %(action)s on %(object)s" },
    'edit_page': {
        'sentence': "%(actor)s has edited %(context)s.",
        'context_func': linked_page },
    'comment_page': {
        'sentence': "%(actor)s has commented on %(context)s.",
        'context_func': linked_page },
    'tag_page': {
        'sentence': "%(actor)s has tagged %(context)s.",
        //'sentence': "%(actor)s has tagged %(context)s with %(object)s.",
        'context_func': linked_page },
    'upload_file_page': {
        'sentence': "%(actor)s has uploaded a file to %(context)s.",
        //'sentence': "%(actor)s has uploaded %(object)s to %(context)s.",
        'context_func': linked_page },
}

// The following function borrowed from http://delete.me.uk/2005/03/iso8601.html
Date.prototype.setISO8601 = function (string) {
    var regexp = "([0-9]{4})(-([0-9]{2})(-([0-9]{2})" +
        "(T([0-9]{2}):([0-9]{2})(:([0-9]{2})(\.([0-9]+))?)?" +
        "(Z|(([-+])([0-9]{2}):([0-9]{2})))?)?)?)?";
    var d = string.match(new RegExp(regexp));

    var offset = 0;
    var date = new Date(d[1], 0, 1);

    if (d[3]) { date.setMonth(d[3] - 1); }
    if (d[5]) { date.setDate(d[5]); }
    if (d[7]) { date.setHours(d[7]); }
    if (d[8]) { date.setMinutes(d[8]); }
    if (d[10]) { date.setSeconds(d[10]); }
    if (d[12]) { date.setMilliseconds(Number("0." + d[12]) * 1000); }
    if (d[14]) {
        offset = (Number(d[16]) * 60) + Number(d[17]);
        offset *= ((d[15] == '-') ? 1 : -1);
    }

    offset -= date.getTimezoneOffset();
    var time = (Number(date) + (offset * 60 * 1000));
    this.setTime(Number(time));
}

function identity(x)
{
    return x;
}

// The following 2 functions inspired by http://trac.typosphere.org/browser/trunk/public/javascripts/typo.js
function prettyDateDelta(minutes)
{
    minutes = Math.abs(minutes);
    if (minutes < 1) return "less than a minute";
    if (minutes < 50) return String(minutes) + " minute" + ((minutes==1)?"":"s");
    if (minutes < 90) return "about one hour";
    if (minutes < 1080) return String(Math.round(minutes/60)) + " hours";
    if (minutes < 1440) return "one day";
    if (minutes < 2880) return "about one day";
    return String(Math.round(minutes/1440)) + " days";
}

function getAgoString(then)
{
    var now = Number(new Date());
    then = Number(then);
    var delta_minutes = Math.floor((now-then) / (60 * 1000));
    return prettyDateDelta(delta_minutes) + " ago";
}

function madlib_render_event(evt, highlight)
{
    var then=new Date();
    then.setISO8601(evt.timestamp);
    var actor=evt.actor;
    var action=evt.action;
    var object=evt.object;
    var context=evt.context;

    var constructor=constructors[evt.action];
    if (constructor==undefined)
    {
        constructor=constructors['default'];
    }
    
    var actor_func=constructor['actor_func'];
    var action_func=constructor['action_func'];
    var object_func=constructor['object_func'];
    var context_func=constructor['context_func'];
    if (actor_func==undefined) {actor_func=linked_person};
    if (action_func==undefined) {action_func=identity};
    if (object_func==undefined) {object_func=identity};
    if (context_func==undefined) {context_func=identity};
    // TODO: Fix when context doesn't exist? don't want to cargo cult
    //   'context': context and context_func( context ) or {}

    var sentence=constructors[evt.action]['sentence'];
    sentence=sentence.replace("%(actor)s", actor_func(actor));
    sentence=sentence.replace("%(action)s", action_func(action));
    sentence=sentence.replace("%(object)s", object_func(object));
    sentence=sentence.replace("%(context)s", context_func(context));
    var sstring="";
    if (!highlight)
    {
        sstring='class="oddrow"';
    }

    return "<li "+sstring+">"+sentence+" ("+getAgoString(then)+")</li>";
}
