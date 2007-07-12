// BEGIN ../../../js-modules/Wikiwyg-copy/lib/Wikiwyg/Debug.js
/*==============================================================================
This Wikiwyg mode supports a textarea editor with toolbar buttons.

COPYRIGHT:

    Copyright (c) 2005 Socialtext Corporation 
    655 High Street
    Palo Alto, CA 94301 U.S.A.
    All rights reserved.

Wikiwyg is free software. 

This library is free software; you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or (at
your option) any later version.

This library is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
General Public License for more details.

    http://www.gnu.org/copyleft/lesser.txt

 =============================================================================*/

// Like alert but uses confirm and throw in case you are looped
function XXX(msg) {
    if (! confirm(msg))
        throw("terminated...");
    return msg;
}

// A JSON dumper that uses XXX
function JJJ(obj) {
    XXX(JSON.stringify(obj));
    return obj;
}


// A few handy debugging functions
(function() {

var klass = Debug = function() {};

klass.sort_object_keys = function(o) {
    var a = [];
    for (p in o) a.push(p);
    return a.sort();
}

klass.dump_keys = function(o) {
    var a = klass.sort_object_keys(o);
    var str='';
    for (p in a)
        str += a[p] + "\t";
    XXX(str);
}

klass.dump_object_into_screen = function(o) {
    var a = klass.sort_object_keys(o);
    var str='';
    for (p in a) {
        var i = a[p];
        try {
            str += a[p] + ': ' + o[i] + '\n';
        } catch(e) {
            // alert('Died on key "' + i + '":\n' + e.message);
        }
    }
    document.write('<xmp>' + str + '</xmp>');
}

})();

// BEGIN main.js
/* 
COPYRIGHT NOTICE:
    Copyright (c) 2004-2005 Socialtext Corporation 
    235 Churchill Ave 
    Palo Alto, CA 94301 U.S.A.
    All rights reserved.
*/

function foreach(list, func) {
    for (var ii = 0; ii < list.length; ii++)
        func(list[ii]);
}

function elem(id) {
    return document.getElementById(id);
}

function exists(object, key) {
    return (typeof object[key] != 'undefined') ;
}

function assertEquals(a, b, desc) {
    // TODO figure out what the calling line was, or else just start using
    // easily-greppable "desc"s
    if (typeof(a) != typeof(b)) {
        alert(
             desc + " failed:\n"
             + 'typeof('+a+') != typeof('+b+')\n'
             + '('+typeof(a)+' vs. '+typeof(b)+')'
        );
    }
    if (a+'' != b+'')
        alert(desc + " failed: '" + a + "' != '" + b + "'");
}

// TODO Replace this stuff with AddEvent
// var onload_functions = new Array()
var onload_functions = [];
function push_onload_function(func) {
    onload_functions.push(func);
}

function call_onload_functions() {
    while (func = onload_functions.shift()) {
        func();
    }
}

function html_escape(string) {
    string = string.toString();
    string = string.replace(/&/g, '&amp;');
    string = string.replace(/</g, '&lt;');
    string = string.replace(/>/g, '&gt;');
    return string;
}

function escape_plus(string) {
    return encodeURIComponent(string);
}

// http://daniel.glazman.free.fr/weblog/newarchive/2003_06_01_glazblogarc.html#s95320189
document.getDivsByClassName = function(needle) {
    var my_array = document.getElementsByTagName('div');
    var retvalue = new Array();
    var i;
    var j;

    for (i = 0, j = 0; i < my_array.length; i++) {
        var c = " " + my_array[i].className + " ";
        if (c.indexOf(" " + needle + " ") != -1)
             retvalue[j++] = my_array[i];
    }
    return retvalue;
}

// -- Less generic stuff below... ---

// TODO - Class.NLW
function toolbar_warning(element, warning) {
    var old_html = element.innerHTML;
    element.innerHTML = warning;
    element.style.color = 'red';
    return old_html;
}

function set_main_frame_margin() {
    var spacer = document.getElementById('page-container-top-control');
    var fixed_bar = document.getElementById('fixed-bar');

    if (fixed_bar) {
        var new_top_margin = fixed_bar.offsetHeight;
        if (Browser.isIE)
            new_top_margin += 2;

        spacer.style.display = 'block';
        spacer.style.height = new_top_margin + 'px';
    }
}
push_onload_function(set_main_frame_margin);
window.onresize = set_main_frame_margin;

function nlw_name_to_id(name) {
    if (name == '')
        return '';
    return encodeURI(
        name.replace(/[^A-Za-z0-9_+\u00C0-\u00FF]/g, '_')
            .replace(/_+/g, '_')
            .replace(/^_*(.*?)_*$/g, '$1')
            .replace(/^0$/, '_')
            .replace(/^$/, '_')
            .toLocaleLowerCase()
    );
}

function check_revisions(form) {
    var r1;
    var r2;
    
    var old_id = form.old_revision_id;
    if (old_id) {
        for (var i = 0; i < old_id.length; i++) {
            if (old_id[i].checked) {
                 r1 = old_id[i].value;
            }
        }
    }
    else {
        r1 = -1;
    }

    var new_id = form.new_revision_id;
    if (new_id) {
        for (var i = 0; i < new_id.length; i++) {
            if (new_id[i].checked) {
                r2 = new_id[i].value;
            }
        }
    }
    else {
        r2 = -1;
    }

    if ((! r1) || (! r2)) {
        alert('You must select two revisions to compare.');
        return false;
    }

    if (r1 == r2) {
        alert('You cannot compare a revision to itself.');
        return false;
    }

    return true;
}

// Dummy JSAN.use since we preload classes
JSAN = {};
JSAN.use = function() {};

if (typeof(Socialtext) == 'undefined') {
    Socialtext = {};
}

Socialtext.clear_untitled = function(input) {
    if (input.value == 'Untitled Page')
        input.value = '';
}
// BEGIN ../../../js-modules/prototype/dist/prototype.js
/*  Prototype JavaScript framework, version 1.4.0
 *  (c) 2005 Sam Stephenson <sam@conio.net>
 *
 *  Prototype is freely distributable under the terms of an MIT-style license.
 *  For details, see the Prototype web site: http://prototype.conio.net/
 *
/*--------------------------------------------------------------------------*/

var Prototype = {
  Version: '1.4.0',
  ScriptFragment: '(?:<script.*?>)((\n|\r|.)*?)(?:<\/script>)',

  emptyFunction: function() {},
  K: function(x) {return x}
}

var Class = {
  create: function() {
    return function() {
      this.initialize.apply(this, arguments);
    }
  }
}

var Abstract = new Object();

Object.extend = function(destination, source) {
  for (property in source) {
    destination[property] = source[property];
  }
  return destination;
}

Object.inspect = function(object) {
  try {
    if (object == undefined) return 'undefined';
    if (object == null) return 'null';
    return object.inspect ? object.inspect() : object.toString();
  } catch (e) {
    if (e instanceof RangeError) return '...';
    throw e;
  }
}

Function.prototype.bind = function() {
  var __method = this, args = $A(arguments), object = args.shift();
  return function() {
    return __method.apply(object, args.concat($A(arguments)));
  }
}

Function.prototype.bindAsEventListener = function(object) {
  var __method = this;
  return function(event) {
    return __method.call(object, event || window.event);
  }
}

Object.extend(Number.prototype, {
  toColorPart: function() {
    var digits = this.toString(16);
    if (this < 16) return '0' + digits;
    return digits;
  },

  succ: function() {
    return this + 1;
  },

  times: function(iterator) {
    $R(0, this, true).each(iterator);
    return this;
  }
});

var Try = {
  these: function() {
    var returnValue;

    for (var i = 0; i < arguments.length; i++) {
      var lambda = arguments[i];
      try {
        returnValue = lambda();
        break;
      } catch (e) {}
    }

    return returnValue;
  }
}

/*--------------------------------------------------------------------------*/

var PeriodicalExecuter = Class.create();
PeriodicalExecuter.prototype = {
  initialize: function(callback, frequency) {
    this.callback = callback;
    this.frequency = frequency;
    this.currentlyExecuting = false;

    this.registerCallback();
  },

  registerCallback: function() {
    setInterval(this.onTimerEvent.bind(this), this.frequency * 1000);
  },

  onTimerEvent: function() {
    if (!this.currentlyExecuting) {
      try {
        this.currentlyExecuting = true;
        this.callback();
      } finally {
        this.currentlyExecuting = false;
      }
    }
  }
}

/*--------------------------------------------------------------------------*/

function $() {
  var elements = new Array();

  for (var i = 0; i < arguments.length; i++) {
    var element = arguments[i];
    if (typeof element == 'string')
      element = document.getElementById(element);

    if (arguments.length == 1)
      return element;

    elements.push(element);
  }

  return elements;
}
Object.extend(String.prototype, {
  stripTags: function() {
    return this.replace(/<\/?[^>]+>/gi, '');
  },

  stripScripts: function() {
    return this.replace(new RegExp(Prototype.ScriptFragment, 'img'), '');
  },

  extractScripts: function() {
    var matchAll = new RegExp(Prototype.ScriptFragment, 'img');
    var matchOne = new RegExp(Prototype.ScriptFragment, 'im');
    return (this.match(matchAll) || []).map(function(scriptTag) {
      return (scriptTag.match(matchOne) || ['', ''])[1];
    });
  },

  evalScripts: function() {
    return this.extractScripts().map(eval);
  },

  escapeHTML: function() {
    var div = document.createElement('div');
    var text = document.createTextNode(this);
    div.appendChild(text);
    return div.innerHTML;
  },

  unescapeHTML: function() {
    var div = document.createElement('div');
    div.innerHTML = this.stripTags();
    return div.childNodes[0] ? div.childNodes[0].nodeValue : '';
  },

  toQueryParams: function() {
    var pairs = this.match(/^\??(.*)$/)[1].split('&');
    return pairs.inject({}, function(params, pairString) {
      var pair = pairString.split('=');
      params[pair[0]] = pair[1];
      return params;
    });
  },

  toArray: function() {
    return this.split('');
  },

  camelize: function() {
    var oStringList = this.split('-');
    if (oStringList.length == 1) return oStringList[0];

    var camelizedString = this.indexOf('-') == 0
      ? oStringList[0].charAt(0).toUpperCase() + oStringList[0].substring(1)
      : oStringList[0];

    for (var i = 1, len = oStringList.length; i < len; i++) {
      var s = oStringList[i];
      camelizedString += s.charAt(0).toUpperCase() + s.substring(1);
    }

    return camelizedString;
  },

  inspect: function() {
    return "'" + this.replace('\\', '\\\\').replace("'", '\\\'') + "'";
  }
});

String.prototype.parseQuery = String.prototype.toQueryParams;

var $break    = new Object();
var $continue = new Object();

var Enumerable = {
  each: function(iterator) {
    var index = 0;
    try {
      this._each(function(value) {
        try {
          iterator(value, index++);
        } catch (e) {
          if (e != $continue) throw e;
        }
      });
    } catch (e) {
      if (e != $break) throw e;
    }
  },

  all: function(iterator) {
    var result = true;
    this.each(function(value, index) {
      result = result && !!(iterator || Prototype.K)(value, index);
      if (!result) throw $break;
    });
    return result;
  },

  any: function(iterator) {
    var result = true;
    this.each(function(value, index) {
      if (result = !!(iterator || Prototype.K)(value, index))
        throw $break;
    });
    return result;
  },

  collect: function(iterator) {
    var results = [];
    this.each(function(value, index) {
      results.push(iterator(value, index));
    });
    return results;
  },

  detect: function (iterator) {
    var result;
    this.each(function(value, index) {
      if (iterator(value, index)) {
        result = value;
        throw $break;
      }
    });
    return result;
  },

  findAll: function(iterator) {
    var results = [];
    this.each(function(value, index) {
      if (iterator(value, index))
        results.push(value);
    });
    return results;
  },

  grep: function(pattern, iterator) {
    var results = [];
    this.each(function(value, index) {
      var stringValue = value.toString();
      if (stringValue.match(pattern))
        results.push((iterator || Prototype.K)(value, index));
    })
    return results;
  },

  include: function(object) {
    var found = false;
    this.each(function(value) {
      if (value == object) {
        found = true;
        throw $break;
      }
    });
    return found;
  },

  inject: function(memo, iterator) {
    this.each(function(value, index) {
      memo = iterator(memo, value, index);
    });
    return memo;
  },

  invoke: function(method) {
    var args = $A(arguments).slice(1);
    return this.collect(function(value) {
      return value[method].apply(value, args);
    });
  },

  max: function(iterator) {
    var result;
    this.each(function(value, index) {
      value = (iterator || Prototype.K)(value, index);
      if (value >= (result || value))
        result = value;
    });
    return result;
  },

  min: function(iterator) {
    var result;
    this.each(function(value, index) {
      value = (iterator || Prototype.K)(value, index);
      if (value <= (result || value))
        result = value;
    });
    return result;
  },

  partition: function(iterator) {
    var trues = [], falses = [];
    this.each(function(value, index) {
      ((iterator || Prototype.K)(value, index) ?
        trues : falses).push(value);
    });
    return [trues, falses];
  },

  pluck: function(property) {
    var results = [];
    this.each(function(value, index) {
      results.push(value[property]);
    });
    return results;
  },

  reject: function(iterator) {
    var results = [];
    this.each(function(value, index) {
      if (!iterator(value, index))
        results.push(value);
    });
    return results;
  },

  sortBy: function(iterator) {
    return this.collect(function(value, index) {
      return {value: value, criteria: iterator(value, index)};
    }).sort(function(left, right) {
      var a = left.criteria, b = right.criteria;
      return a < b ? -1 : a > b ? 1 : 0;
    }).pluck('value');
  },

  toArray: function() {
    return this.collect(Prototype.K);
  },

  zip: function() {
    var iterator = Prototype.K, args = $A(arguments);
    if (typeof args.last() == 'function')
      iterator = args.pop();

    var collections = [this].concat(args).map($A);
    return this.map(function(value, index) {
      iterator(value = collections.pluck(index));
      return value;
    });
  },

  inspect: function() {
    return '#<Enumerable:' + this.toArray().inspect() + '>';
  }
}

Object.extend(Enumerable, {
  map:     Enumerable.collect,
  find:    Enumerable.detect,
  select:  Enumerable.findAll,
  member:  Enumerable.include,
  entries: Enumerable.toArray
});
var $A = Array.from = function(iterable) {
  if (!iterable) return [];
  if (iterable.toArray) {
    return iterable.toArray();
  } else {
    var results = [];
    for (var i = 0; i < iterable.length; i++)
      results.push(iterable[i]);
    return results;
  }
}

Object.extend(Array.prototype, Enumerable);

Array.prototype._reverse = Array.prototype.reverse;

Object.extend(Array.prototype, {
  _each: function(iterator) {
    for (var i = 0; i < this.length; i++)
      iterator(this[i]);
  },

  clear: function() {
    this.length = 0;
    return this;
  },

  first: function() {
    return this[0];
  },

  last: function() {
    return this[this.length - 1];
  },

  compact: function() {
    return this.select(function(value) {
      return value != undefined || value != null;
    });
  },

  flatten: function() {
    return this.inject([], function(array, value) {
      return array.concat(value.constructor == Array ?
        value.flatten() : [value]);
    });
  },

  without: function() {
    var values = $A(arguments);
    return this.select(function(value) {
      return !values.include(value);
    });
  },

  indexOf: function(object) {
    for (var i = 0; i < this.length; i++)
      if (this[i] == object) return i;
    return -1;
  },

  reverse: function(inline) {
    return (inline !== false ? this : this.toArray())._reverse();
  },

  /* ingy says no
  shift: function() {
    var result = this[0];
    for (var i = 0; i < this.length - 1; i++)
      this[i] = this[i + 1];
    this.length--;
    return result;
  },
  */

  inspect: function() {
    return '[' + this.map(Object.inspect).join(', ') + ']';
  }
});
var Hash = {
  _each: function(iterator) {
    for (key in this) {
      var value = this[key];
      if (typeof value == 'function') continue;

      var pair = [key, value];
      pair.key = key;
      pair.value = value;
      iterator(pair);
    }
  },

  keys: function() {
    return this.pluck('key');
  },

  values: function() {
    return this.pluck('value');
  },

  merge: function(hash) {
    return $H(hash).inject($H(this), function(mergedHash, pair) {
      mergedHash[pair.key] = pair.value;
      return mergedHash;
    });
  },

  toQueryString: function() {
    return this.map(function(pair) {
      return pair.map(encodeURIComponent).join('=');
    }).join('&');
  },

  inspect: function() {
    return '#<Hash:{' + this.map(function(pair) {
      return pair.map(Object.inspect).join(': ');
    }).join(', ') + '}>';
  }
}

function $H(object) {
  var hash = Object.extend({}, object || {});
  Object.extend(hash, Enumerable);
  Object.extend(hash, Hash);
  return hash;
}
ObjectRange = Class.create();
Object.extend(ObjectRange.prototype, Enumerable);
Object.extend(ObjectRange.prototype, {
  initialize: function(start, end, exclusive) {
    this.start = start;
    this.end = end;
    this.exclusive = exclusive;
  },

  _each: function(iterator) {
    var value = this.start;
    do {
      iterator(value);
      value = value.succ();
    } while (this.include(value));
  },

  include: function(value) {
    if (value < this.start)
      return false;
    if (this.exclusive)
      return value < this.end;
    return value <= this.end;
  }
});

var $R = function(start, end, exclusive) {
  return new ObjectRange(start, end, exclusive);
}

var Ajax = {
  getTransport: function() {
    return Try.these(
      function() {return new ActiveXObject('Msxml2.XMLHTTP')},
      function() {return new ActiveXObject('Microsoft.XMLHTTP')},
      function() {return new XMLHttpRequest()}
    ) || false;
  },

  activeRequestCount: 0
}

Ajax.Responders = {
  responders: [],

  _each: function(iterator) {
    this.responders._each(iterator);
  },

  register: function(responderToAdd) {
    if (!this.include(responderToAdd))
      this.responders.push(responderToAdd);
  },

  unregister: function(responderToRemove) {
    this.responders = this.responders.without(responderToRemove);
  },

  dispatch: function(callback, request, transport, json) {
    this.each(function(responder) {
      if (responder[callback] && typeof responder[callback] == 'function') {
        try {
          responder[callback].apply(responder, [request, transport, json]);
        } catch (e) {}
      }
    });
  }
};

Object.extend(Ajax.Responders, Enumerable);

Ajax.Responders.register({
  onCreate: function() {
    Ajax.activeRequestCount++;
  },

  onComplete: function() {
    Ajax.activeRequestCount--;
  }
});

Ajax.Base = function() {};
Ajax.Base.prototype = {
  setOptions: function(options) {
    this.options = {
      method:       'post',
      asynchronous: true,
      parameters:   ''
    }
    Object.extend(this.options, options || {});
  },

  responseIsSuccess: function() {
    return this.transport.status == undefined
        || this.transport.status == 0
        || (this.transport.status >= 200 && this.transport.status < 300);
  },

  responseIsFailure: function() {
    return !this.responseIsSuccess();
  }
}

Ajax.Request = Class.create();
Ajax.Request.Events =
  ['Uninitialized', 'Loading', 'Loaded', 'Interactive', 'Complete'];

Ajax.Request.prototype = Object.extend(new Ajax.Base(), {
  initialize: function(url, options) {
    this.transport = Ajax.getTransport();
    this.setOptions(options);
    this.request(url);
  },

  request: function(url) {
    var parameters = this.options.parameters || '';
    if (parameters.length > 0) parameters += '&_=';

    try {
      this.url = url;
      if (this.options.method == 'get' && parameters.length > 0)
        this.url += (this.url.match(/\?/) ? '&' : '?') + parameters;

      Ajax.Responders.dispatch('onCreate', this, this.transport);

      this.transport.open(this.options.method, this.url,
        this.options.asynchronous);

      if (this.options.asynchronous) {
        this.transport.onreadystatechange = this.onStateChange.bind(this);
        setTimeout((function() {this.respondToReadyState(1)}).bind(this), 10);
      }

      this.setRequestHeaders();

      var body = this.options.postBody ? this.options.postBody : parameters;
      this.transport.send(this.options.method == 'post' ? body : null);

    } catch (e) {
      this.dispatchException(e);
    }
  },

  setRequestHeaders: function() {
    var requestHeaders =
      ['X-Requested-With', 'XMLHttpRequest',
       'X-Prototype-Version', Prototype.Version];

    if (this.options.method == 'post') {
      requestHeaders.push('Content-type',
        'application/x-www-form-urlencoded');

      /* Force "Connection: close" for Mozilla browsers to work around
       * a bug where XMLHttpReqeuest sends an incorrect Content-length
       * header. See Mozilla Bugzilla #246651.
       */
      if (this.transport.overrideMimeType)
        requestHeaders.push('Connection', 'close');
    }

    if (this.options.requestHeaders)
      requestHeaders.push.apply(requestHeaders, this.options.requestHeaders);

    for (var i = 0; i < requestHeaders.length; i += 2)
      this.transport.setRequestHeader(requestHeaders[i], requestHeaders[i+1]);
  },

  onStateChange: function() {
    var readyState = this.transport.readyState;
    if (readyState != 1)
      this.respondToReadyState(this.transport.readyState);
  },

  header: function(name) {
    try {
      return this.transport.getResponseHeader(name);
    } catch (e) {}
  },

  evalJSON: function() {
    try {
      return eval(this.header('X-JSON'));
    } catch (e) {}
  },

  evalResponse: function() {
    try {
      return eval(this.transport.responseText);
    } catch (e) {
      this.dispatchException(e);
    }
  },

  respondToReadyState: function(readyState) {
    var event = Ajax.Request.Events[readyState];
    var transport = this.transport, json = this.evalJSON();

    if (event == 'Complete') {
      try {
        (this.options['on' + this.transport.status]
         || this.options['on' + (this.responseIsSuccess() ? 'Success' : 'Failure')]
         || Prototype.emptyFunction)(transport, json);
      } catch (e) {
        this.dispatchException(e);
      }

      if ((this.header('Content-type') || '').match(/^text\/javascript/i))
        this.evalResponse();
    }

    try {
      (this.options['on' + event] || Prototype.emptyFunction)(transport, json);
      Ajax.Responders.dispatch('on' + event, this, transport, json);
    } catch (e) {
      this.dispatchException(e);
    }

    /* Avoid memory leak in MSIE: clean up the oncomplete event handler */
    if (event == 'Complete')
      this.transport.onreadystatechange = Prototype.emptyFunction;
  },

  dispatchException: function(exception) {
    (this.options.onException || Prototype.emptyFunction)(this, exception);
    Ajax.Responders.dispatch('onException', this, exception);
  }
});

Ajax.Updater = Class.create();

Object.extend(Object.extend(Ajax.Updater.prototype, Ajax.Request.prototype), {
  initialize: function(container, url, options) {
    this.containers = {
      success: container.success ? $(container.success) : $(container),
      failure: container.failure ? $(container.failure) :
        (container.success ? null : $(container))
    }

    this.transport = Ajax.getTransport();
    this.setOptions(options);

    var onComplete = this.options.onComplete || Prototype.emptyFunction;
    this.options.onComplete = (function(transport, object) {
      this.updateContent();
      onComplete(transport, object);
    }).bind(this);

    this.request(url);
  },

  updateContent: function() {
    var receiver = this.responseIsSuccess() ?
      this.containers.success : this.containers.failure;
    var response = this.transport.responseText;

    if (!this.options.evalScripts)
      response = response.stripScripts();

    if (receiver) {
      if (this.options.insertion) {
        new this.options.insertion(receiver, response);
      } else {
        Element.update(receiver, response);
      }
    }

    if (this.responseIsSuccess()) {
      if (this.onComplete)
        setTimeout(this.onComplete.bind(this), 10);
    }
  }
});

Ajax.PeriodicalUpdater = Class.create();
Ajax.PeriodicalUpdater.prototype = Object.extend(new Ajax.Base(), {
  initialize: function(container, url, options) {
    this.setOptions(options);
    this.onComplete = this.options.onComplete;

    this.frequency = (this.options.frequency || 2);
    this.decay = (this.options.decay || 1);

    this.updater = {};
    this.container = container;
    this.url = url;

    this.start();
  },

  start: function() {
    this.options.onComplete = this.updateComplete.bind(this);
    this.onTimerEvent();
  },

  stop: function() {
    this.updater.onComplete = undefined;
    clearTimeout(this.timer);
    (this.onComplete || Prototype.emptyFunction).apply(this, arguments);
  },

  updateComplete: function(request) {
    if (this.options.decay) {
      this.decay = (request.responseText == this.lastText ?
        this.decay * this.options.decay : 1);

      this.lastText = request.responseText;
    }
    this.timer = setTimeout(this.onTimerEvent.bind(this),
      this.decay * this.frequency * 1000);
  },

  onTimerEvent: function() {
    this.updater = new Ajax.Updater(this.container, this.url, this.options);
  }
});
document.getElementsByClassName = function(className, parentElement) {
  var children = ($(parentElement) || document.body).getElementsByTagName('*');
  return $A(children).inject([], function(elements, child) {
    if (child.className.match(new RegExp("(^|\\s)" + className + "(\\s|$)")))
      elements.push(child);
    return elements;
  });
}

/*--------------------------------------------------------------------------*/

if (!window.Element) {
  var Element = new Object();
}

Object.extend(Element, {
  visible: function(element) {
    return $(element).style.display != 'none';
  },

  toggle: function() {
    for (var i = 0; i < arguments.length; i++) {
      var element = $(arguments[i]);
      Element[Element.visible(element) ? 'hide' : 'show'](element);
    }
  },

  hide: function() {
    for (var i = 0; i < arguments.length; i++) {
      var element = $(arguments[i]);
      element.style.display = 'none';
    }
  },

  show: function() {
    for (var i = 0; i < arguments.length; i++) {
      var element = $(arguments[i]);
      element.style.display = '';
    }
  },

  remove: function(element) {
    element = $(element);
    element.parentNode.removeChild(element);
  },

  update: function(element, html) {
    $(element).innerHTML = html.stripScripts();
    setTimeout(function() {html.evalScripts()}, 10);
  },

  getHeight: function(element) {
    element = $(element);
    return element.offsetHeight;
  },

  classNames: function(element) {
    return new Element.ClassNames(element);
  },

  hasClassName: function(element, className) {
    if (!(element = $(element))) return;
    return Element.classNames(element).include(className);
  },

  addClassName: function(element, className) {
    if (!(element = $(element))) return;
    return Element.classNames(element).add(className);
  },

  removeClassName: function(element, className) {
    if (!(element = $(element))) return;
    return Element.classNames(element).remove(className);
  },

  // removes whitespace-only text node children
  cleanWhitespace: function(element) {
    element = $(element);
    for (var i = 0; i < element.childNodes.length; i++) {
      var node = element.childNodes[i];
      if (node.nodeType == 3 && !/\S/.test(node.nodeValue))
        Element.remove(node);
    }
  },

  empty: function(element) {
    return $(element).innerHTML.match(/^\s*$/);
  },

  scrollTo: function(element) {
    element = $(element);
    var x = element.x ? element.x : element.offsetLeft,
        y = element.y ? element.y : element.offsetTop;
    window.scrollTo(x, y);
  },

  getStyle: function(element, style) {
    element = $(element);
    var value = element.style[style.camelize()];
    if (!value) {
      if (document.defaultView && document.defaultView.getComputedStyle) {
        var css = document.defaultView.getComputedStyle(element, null);
        value = css ? css.getPropertyValue(style) : null;
      } else if (element.currentStyle) {
        value = element.currentStyle[style.camelize()];
      }
    }

    if (window.opera && ['left', 'top', 'right', 'bottom'].include(style))
      if (Element.getStyle(element, 'position') == 'static') value = 'auto';

    return value == 'auto' ? null : value;
  },

  setStyle: function(element, style) {
    element = $(element);
    for (name in style)
      element.style[name.camelize()] = style[name];
  },

  getDimensions: function(element) {
    element = $(element);
    if (Element.getStyle(element, 'display') != 'none')
      return {width: element.offsetWidth, height: element.offsetHeight};

    // All *Width and *Height properties give 0 on elements with display none,
    // so enable the element temporarily
    var els = element.style;
    var originalVisibility = els.visibility;
    var originalPosition = els.position;
    els.visibility = 'hidden';
    els.position = 'absolute';
    els.display = '';
    var originalWidth = element.clientWidth;
    var originalHeight = element.clientHeight;
    els.display = 'none';
    els.position = originalPosition;
    els.visibility = originalVisibility;
    return {width: originalWidth, height: originalHeight};
  },

  makePositioned: function(element) {
    element = $(element);
    var pos = Element.getStyle(element, 'position');
    if (pos == 'static' || !pos) {
      element._madePositioned = true;
      element.style.position = 'relative';
      // Opera returns the offset relative to the positioning context, when an
      // element is position relative but top and left have not been defined
      if (window.opera) {
        element.style.top = 0;
        element.style.left = 0;
      }
    }
  },

  undoPositioned: function(element) {
    element = $(element);
    if (element._madePositioned) {
      element._madePositioned = undefined;
      element.style.position =
        element.style.top =
        element.style.left =
        element.style.bottom =
        element.style.right = '';
    }
  },

  makeClipping: function(element) {
    element = $(element);
    if (element._overflow) return;
    element._overflow = element.style.overflow;
    if ((Element.getStyle(element, 'overflow') || 'visible') != 'hidden')
      element.style.overflow = 'hidden';
  },

  undoClipping: function(element) {
    element = $(element);
    if (element._overflow) return;
    element.style.overflow = element._overflow;
    element._overflow = undefined;
  }
});

var Toggle = new Object();
Toggle.display = Element.toggle;

/*--------------------------------------------------------------------------*/

Abstract.Insertion = function(adjacency) {
  this.adjacency = adjacency;
}

Abstract.Insertion.prototype = {
  initialize: function(element, content) {
    this.element = $(element);
    this.content = content.stripScripts();

    if (this.adjacency && this.element.insertAdjacentHTML) {
      try {
        this.element.insertAdjacentHTML(this.adjacency, this.content);
      } catch (e) {
        if (this.element.tagName.toLowerCase() == 'tbody') {
          this.insertContent(this.contentFromAnonymousTable());
        } else {
          throw e;
        }
      }
    } else {
      this.range = this.element.ownerDocument.createRange();
      if (this.initializeRange) this.initializeRange();
      this.insertContent([this.range.createContextualFragment(this.content)]);
    }

    setTimeout(function() {content.evalScripts()}, 10);
  },

  contentFromAnonymousTable: function() {
    var div = document.createElement('div');
    div.innerHTML = '<table><tbody>' + this.content + '</tbody></table>';
    return $A(div.childNodes[0].childNodes[0].childNodes);
  }
}

var Insertion = new Object();

Insertion.Before = Class.create();
Insertion.Before.prototype = Object.extend(new Abstract.Insertion('beforeBegin'), {
  initializeRange: function() {
    this.range.setStartBefore(this.element);
  },

  insertContent: function(fragments) {
    fragments.each((function(fragment) {
      this.element.parentNode.insertBefore(fragment, this.element);
    }).bind(this));
  }
});

Insertion.Top = Class.create();
Insertion.Top.prototype = Object.extend(new Abstract.Insertion('afterBegin'), {
  initializeRange: function() {
    this.range.selectNodeContents(this.element);
    this.range.collapse(true);
  },

  insertContent: function(fragments) {
    fragments.reverse(false).each((function(fragment) {
      this.element.insertBefore(fragment, this.element.firstChild);
    }).bind(this));
  }
});

Insertion.Bottom = Class.create();
Insertion.Bottom.prototype = Object.extend(new Abstract.Insertion('beforeEnd'), {
  initializeRange: function() {
    this.range.selectNodeContents(this.element);
    this.range.collapse(this.element);
  },

  insertContent: function(fragments) {
    fragments.each((function(fragment) {
      this.element.appendChild(fragment);
    }).bind(this));
  }
});

Insertion.After = Class.create();
Insertion.After.prototype = Object.extend(new Abstract.Insertion('afterEnd'), {
  initializeRange: function() {
    this.range.setStartAfter(this.element);
  },

  insertContent: function(fragments) {
    fragments.each((function(fragment) {
      this.element.parentNode.insertBefore(fragment,
        this.element.nextSibling);
    }).bind(this));
  }
});

/*--------------------------------------------------------------------------*/

Element.ClassNames = Class.create();
Element.ClassNames.prototype = {
  initialize: function(element) {
    this.element = $(element);
  },

  _each: function(iterator) {
    this.element.className.split(/\s+/).select(function(name) {
      return name.length > 0;
    })._each(iterator);
  },

  set: function(className) {
    this.element.className = className;
  },

  add: function(classNameToAdd) {
    if (this.include(classNameToAdd)) return;
    this.set(this.toArray().concat(classNameToAdd).join(' '));
  },

  remove: function(classNameToRemove) {
    if (!this.include(classNameToRemove)) return;
    this.set(this.select(function(className) {
      return className != classNameToRemove;
    }).join(' '));
  },

  toString: function() {
    return this.toArray().join(' ');
  }
}

Object.extend(Element.ClassNames.prototype, Enumerable);
var Field = {
  clear: function() {
    for (var i = 0; i < arguments.length; i++)
      $(arguments[i]).value = '';
  },

  focus: function(element) {
    $(element).focus();
  },

  present: function() {
    for (var i = 0; i < arguments.length; i++)
      if ($(arguments[i]).value == '') return false;
    return true;
  },

  select: function(element) {
    $(element).select();
  },

  activate: function(element) {
    element = $(element);
    element.focus();
    if (element.select)
      element.select();
  }
}

/*--------------------------------------------------------------------------*/

var Form = {
  serialize: function(form) {
    var elements = Form.getElements($(form));
    var queryComponents = new Array();

    for (var i = 0; i < elements.length; i++) {
      var queryComponent = Form.Element.serialize(elements[i]);
      if (queryComponent)
        queryComponents.push(queryComponent);
    }

    return queryComponents.join('&');
  },

  getElements: function(form) {
    form = $(form);
    var elements = new Array();

    for (tagName in Form.Element.Serializers) {
      var tagElements = form.getElementsByTagName(tagName);
      for (var j = 0; j < tagElements.length; j++)
        elements.push(tagElements[j]);
    }
    return elements;
  },

  getInputs: function(form, typeName, name) {
    form = $(form);
    var inputs = form.getElementsByTagName('input');

    if (!typeName && !name)
      return inputs;

    var matchingInputs = new Array();
    for (var i = 0; i < inputs.length; i++) {
      var input = inputs[i];
      if ((typeName && input.type != typeName) ||
          (name && input.name != name))
        continue;
      matchingInputs.push(input);
    }

    return matchingInputs;
  },

  disable: function(form) {
    var elements = Form.getElements(form);
    for (var i = 0; i < elements.length; i++) {
      var element = elements[i];
      element.blur();
      element.disabled = 'true';
    }
  },

  enable: function(form) {
    var elements = Form.getElements(form);
    for (var i = 0; i < elements.length; i++) {
      var element = elements[i];
      element.disabled = '';
    }
  },

  findFirstElement: function(form) {
    return Form.getElements(form).find(function(element) {
      return element.type != 'hidden' && !element.disabled &&
        ['input', 'select', 'textarea'].include(element.tagName.toLowerCase());
    });
  },

  focusFirstElement: function(form) {
    Field.activate(Form.findFirstElement(form));
  },

  reset: function(form) {
    $(form).reset();
  }
}

Form.Element = {
  serialize: function(element) {
    element = $(element);
    var method = element.tagName.toLowerCase();
    var parameter = Form.Element.Serializers[method](element);

    if (parameter) {
      var key = encodeURIComponent(parameter[0]);
      if (key.length == 0) return;

      if (parameter[1].constructor != Array)
        parameter[1] = [parameter[1]];

      return parameter[1].map(function(value) {
        return key + '=' + encodeURIComponent(value);
      }).join('&');
    }
  },

  getValue: function(element) {
    element = $(element);
    var method = element.tagName.toLowerCase();
    var parameter = Form.Element.Serializers[method](element);

    if (parameter)
      return parameter[1];
  }
}

Form.Element.Serializers = {
  input: function(element) {
    switch (element.type.toLowerCase()) {
      case 'submit':
      case 'hidden':
      case 'password':
      case 'text':
        return Form.Element.Serializers.textarea(element);
      case 'checkbox':
      case 'radio':
        return Form.Element.Serializers.inputSelector(element);
    }
    return false;
  },

  inputSelector: function(element) {
    if (element.checked)
      return [element.name, element.value];
  },

  textarea: function(element) {
    return [element.name, element.value];
  },

  select: function(element) {
    return Form.Element.Serializers[element.type == 'select-one' ?
      'selectOne' : 'selectMany'](element);
  },

  selectOne: function(element) {
    var value = '', opt, index = element.selectedIndex;
    if (index >= 0) {
      opt = element.options[index];
      value = opt.value;
      if (!value && !('value' in opt))
        value = opt.text;
    }
    return [element.name, value];
  },

  selectMany: function(element) {
    var value = new Array();
    for (var i = 0; i < element.length; i++) {
      var opt = element.options[i];
      if (opt.selected) {
        var optValue = opt.value;
        if (!optValue && !('value' in opt))
          optValue = opt.text;
        value.push(optValue);
      }
    }
    return [element.name, value];
  }
}

/*--------------------------------------------------------------------------*/

var $F = Form.Element.getValue;

/*--------------------------------------------------------------------------*/

Abstract.TimedObserver = function() {}
Abstract.TimedObserver.prototype = {
  initialize: function(element, frequency, callback) {
    this.frequency = frequency;
    this.element   = $(element);
    this.callback  = callback;

    this.lastValue = this.getValue();
    this.registerCallback();
  },

  registerCallback: function() {
    setInterval(this.onTimerEvent.bind(this), this.frequency * 1000);
  },

  onTimerEvent: function() {
    var value = this.getValue();
    if (this.lastValue != value) {
      this.callback(this.element, value);
      this.lastValue = value;
    }
  }
}

Form.Element.Observer = Class.create();
Form.Element.Observer.prototype = Object.extend(new Abstract.TimedObserver(), {
  getValue: function() {
    return Form.Element.getValue(this.element);
  }
});

Form.Observer = Class.create();
Form.Observer.prototype = Object.extend(new Abstract.TimedObserver(), {
  getValue: function() {
    return Form.serialize(this.element);
  }
});

/*--------------------------------------------------------------------------*/

Abstract.EventObserver = function() {}
Abstract.EventObserver.prototype = {
  initialize: function(element, callback) {
    this.element  = $(element);
    this.callback = callback;

    this.lastValue = this.getValue();
    if (this.element.tagName.toLowerCase() == 'form')
      this.registerFormCallbacks();
    else
      this.registerCallback(this.element);
  },

  onElementEvent: function() {
    var value = this.getValue();
    if (this.lastValue != value) {
      this.callback(this.element, value);
      this.lastValue = value;
    }
  },

  registerFormCallbacks: function() {
    var elements = Form.getElements(this.element);
    for (var i = 0; i < elements.length; i++)
      this.registerCallback(elements[i]);
  },

  registerCallback: function(element) {
    if (element.type) {
      switch (element.type.toLowerCase()) {
        case 'checkbox':
        case 'radio':
          Event.observe(element, 'click', this.onElementEvent.bind(this));
          break;
        case 'password':
        case 'text':
        case 'textarea':
        case 'select-one':
        case 'select-multiple':
          Event.observe(element, 'change', this.onElementEvent.bind(this));
          break;
      }
    }
  }
}

Form.Element.EventObserver = Class.create();
Form.Element.EventObserver.prototype = Object.extend(new Abstract.EventObserver(), {
  getValue: function() {
    return Form.Element.getValue(this.element);
  }
});

Form.EventObserver = Class.create();
Form.EventObserver.prototype = Object.extend(new Abstract.EventObserver(), {
  getValue: function() {
    return Form.serialize(this.element);
  }
});
if (!window.Event) {
  var Event = new Object();
}

Object.extend(Event, {
  KEY_BACKSPACE: 8,
  KEY_TAB:       9,
  KEY_RETURN:   13,
  KEY_ESC:      27,
  KEY_LEFT:     37,
  KEY_UP:       38,
  KEY_RIGHT:    39,
  KEY_DOWN:     40,
  KEY_DELETE:   46,

  element: function(event) {
    return event.target || event.srcElement;
  },

  isLeftClick: function(event) {
    return (((event.which) && (event.which == 1)) ||
            ((event.button) && (event.button == 1)));
  },

  pointerX: function(event) {
    return event.pageX || (event.clientX +
      (document.documentElement.scrollLeft || document.body.scrollLeft));
  },

  pointerY: function(event) {
    return event.pageY || (event.clientY +
      (document.documentElement.scrollTop || document.body.scrollTop));
  },

  stop: function(event) {
    if (event.preventDefault) {
      event.preventDefault();
      event.stopPropagation();
    } else {
      event.returnValue = false;
      event.cancelBubble = true;
    }
  },

  // find the first node with the given tagName, starting from the
  // node the event was triggered on; traverses the DOM upwards
  findElement: function(event, tagName) {
    var element = Event.element(event);
    while (element.parentNode && (!element.tagName ||
        (element.tagName.toUpperCase() != tagName.toUpperCase())))
      element = element.parentNode;
    return element;
  },

  observers: false,

  _observeAndCache: function(element, name, observer, useCapture) {
    if (!this.observers) this.observers = [];
    if (element.addEventListener) {
      this.observers.push([element, name, observer, useCapture]);
      element.addEventListener(name, observer, useCapture);
    } else if (element.attachEvent) {
      this.observers.push([element, name, observer, useCapture]);
      element.attachEvent('on' + name, observer);
    }
  },

  unloadCache: function() {
    if (!Event.observers) return;
    for (var i = 0; i < Event.observers.length; i++) {
      Event.stopObserving.apply(this, Event.observers[i]);
      Event.observers[i][0] = null;
    }
    Event.observers = false;
  },

  observe: function(element, name, observer, useCapture) {
    var element = $(element);
    useCapture = useCapture || false;

    if (name == 'keypress' &&
        (navigator.appVersion.match(/Konqueror|Safari|KHTML/)
        || element.attachEvent))
      name = 'keydown';

    this._observeAndCache(element, name, observer, useCapture);
  },

  stopObserving: function(element, name, observer, useCapture) {
    var element = $(element);
    useCapture = useCapture || false;

    if (name == 'keypress' &&
        (navigator.appVersion.match(/Konqueror|Safari|KHTML/)
        || element.detachEvent))
      name = 'keydown';

    if (element.removeEventListener) {
      element.removeEventListener(name, observer, useCapture);
    } else if (element.detachEvent) {
      element.detachEvent('on' + name, observer);
    }
  }
});

/* prevent memory leaks in IE */
Event.observe(window, 'unload', Event.unloadCache, false);
var Position = {
  // set to true if needed, warning: firefox performance problems
  // NOT neeeded for page scrolling, only if draggable contained in
  // scrollable elements
  includeScrollOffsets: false,

  // must be called before calling withinIncludingScrolloffset, every time the
  // page is scrolled
  prepare: function() {
    this.deltaX =  window.pageXOffset
                || document.documentElement.scrollLeft
                || document.body.scrollLeft
                || 0;
    this.deltaY =  window.pageYOffset
                || document.documentElement.scrollTop
                || document.body.scrollTop
                || 0;
  },

  realOffset: function(element) {
    var valueT = 0, valueL = 0;
    do {
      valueT += element.scrollTop  || 0;
      valueL += element.scrollLeft || 0;
      element = element.parentNode;
    } while (element);
    return [valueL, valueT];
  },

  cumulativeOffset: function(element) {
    var valueT = 0, valueL = 0;
    do {
      valueT += element.offsetTop  || 0;
      valueL += element.offsetLeft || 0;
      element = element.offsetParent;
    } while (element);
    return [valueL, valueT];
  },

  positionedOffset: function(element) {
    var valueT = 0, valueL = 0;
    do {
      valueT += element.offsetTop  || 0;
      valueL += element.offsetLeft || 0;
      element = element.offsetParent;
      if (element) {
        p = Element.getStyle(element, 'position');
        if (p == 'relative' || p == 'absolute') break;
      }
    } while (element);
    return [valueL, valueT];
  },

  offsetParent: function(element) {
    if (element.offsetParent) return element.offsetParent;
    if (element == document.body) return element;

    while ((element = element.parentNode) && element != document.body)
      if (Element.getStyle(element, 'position') != 'static')
        return element;

    return document.body;
  },

  // caches x/y coordinate pair to use with overlap
  within: function(element, x, y) {
    if (this.includeScrollOffsets)
      return this.withinIncludingScrolloffsets(element, x, y);
    this.xcomp = x;
    this.ycomp = y;
    this.offset = this.cumulativeOffset(element);

    return (y >= this.offset[1] &&
            y <  this.offset[1] + element.offsetHeight &&
            x >= this.offset[0] &&
            x <  this.offset[0] + element.offsetWidth);
  },

  withinIncludingScrolloffsets: function(element, x, y) {
    var offsetcache = this.realOffset(element);

    this.xcomp = x + offsetcache[0] - this.deltaX;
    this.ycomp = y + offsetcache[1] - this.deltaY;
    this.offset = this.cumulativeOffset(element);

    return (this.ycomp >= this.offset[1] &&
            this.ycomp <  this.offset[1] + element.offsetHeight &&
            this.xcomp >= this.offset[0] &&
            this.xcomp <  this.offset[0] + element.offsetWidth);
  },

  // within must be called directly before
  overlap: function(mode, element) {
    if (!mode) return 0;
    if (mode == 'vertical')
      return ((this.offset[1] + element.offsetHeight) - this.ycomp) /
        element.offsetHeight;
    if (mode == 'horizontal')
      return ((this.offset[0] + element.offsetWidth) - this.xcomp) /
        element.offsetWidth;
  },

  clone: function(source, target) {
    source = $(source);
    target = $(target);
    target.style.position = 'absolute';
    var offsets = this.cumulativeOffset(source);
    target.style.top    = offsets[1] + 'px';
    target.style.left   = offsets[0] + 'px';
    target.style.width  = source.offsetWidth + 'px';
    target.style.height = source.offsetHeight + 'px';
  },

  page: function(forElement) {
    var valueT = 0, valueL = 0;

    var element = forElement;
    do {
      valueT += element.offsetTop  || 0;
      valueL += element.offsetLeft || 0;

      // Safari fix
      if (element.offsetParent==document.body)
        if (Element.getStyle(element,'position')=='absolute') break;

    } while (element = element.offsetParent);

    element = forElement;
    do {
      valueT -= element.scrollTop  || 0;
      valueL -= element.scrollLeft || 0;
    } while (element = element.parentNode);

    return [valueL, valueT];
  },

  clone: function(source, target) {
    var options = Object.extend({
      setLeft:    true,
      setTop:     true,
      setWidth:   true,
      setHeight:  true,
      offsetTop:  0,
      offsetLeft: 0
    }, arguments[2] || {})

    // find page position of source
    source = $(source);
    var p = Position.page(source);

    // find coordinate system to use
    target = $(target);
    var delta = [0, 0];
    var parent = null;
    // delta [0,0] will do fine with position: fixed elements,
    // position:absolute needs offsetParent deltas
    if (Element.getStyle(target,'position') == 'absolute') {
      parent = Position.offsetParent(target);
      delta = Position.page(parent);
    }

    // correct by body offsets (fixes Safari)
    if (parent == document.body) {
      delta[0] -= document.body.offsetLeft;
      delta[1] -= document.body.offsetTop;
    }

    // set position
    if(options.setLeft)   target.style.left  = (p[0] - delta[0] + options.offsetLeft) + 'px';
    if(options.setTop)    target.style.top   = (p[1] - delta[1] + options.offsetTop) + 'px';
    if(options.setWidth)  target.style.width = source.offsetWidth + 'px';
    if(options.setHeight) target.style.height = source.offsetHeight + 'px';
  },

  absolutize: function(element) {
    element = $(element);
    if (element.style.position == 'absolute') return;
    Position.prepare();

    var offsets = Position.positionedOffset(element);
    var top     = offsets[1];
    var left    = offsets[0];
    var width   = element.clientWidth;
    var height  = element.clientHeight;

    element._originalLeft   = left - parseFloat(element.style.left  || 0);
    element._originalTop    = top  - parseFloat(element.style.top || 0);
    element._originalWidth  = element.style.width;
    element._originalHeight = element.style.height;

    element.style.position = 'absolute';
    element.style.top    = top + 'px';;
    element.style.left   = left + 'px';;
    element.style.width  = width + 'px';;
    element.style.height = height + 'px';;
  },

  relativize: function(element) {
    element = $(element);
    if (element.style.position == 'relative') return;
    Position.prepare();

    element.style.position = 'relative';
    var top  = parseFloat(element.style.top  || 0) - (element._originalTop || 0);
    var left = parseFloat(element.style.left || 0) - (element._originalLeft || 0);

    element.style.top    = top + 'px';
    element.style.left   = left + 'px';
    element.style.height = element._originalHeight;
    element.style.width  = element._originalWidth;
  }
}

// Safari returns margins on body which is incorrect if the child is absolutely
// positioned.  For performance reasons, redefine Position.cumulativeOffset for
// KHTML/WebKit only.
if (/Konqueror|Safari|KHTML/.test(navigator.userAgent)) {
  Position.cumulativeOffset = function(element) {
    var valueT = 0, valueL = 0;
    do {
      valueT += element.offsetTop  || 0;
      valueL += element.offsetLeft || 0;
      if (element.offsetParent == document.body)
        if (Element.getStyle(element, 'position') == 'absolute') break;

      element = element.offsetParent;
    } while (element);

    return [valueL, valueT];
  }
}// BEGIN ../../../js-modules/Ajax/lib/Ajax.js
/*==============================================================================
Ajax - Simple Ajax Support Library

DESCRIPTION:

This library defines simple cross-browser functions for rudimentary Ajax
support.

AUTHORS:

    Ingy döt Net <ingy@cpan.org>
    Kang-min Liu <gugod@gugod.org>
    Chris Dent <cdent@burningchrome.com>

COPYRIGHT:

Copyright Ingy döt Net 2006. All rights reserved.

Ajax.js is free software. 

This library is free software; you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or (at
your option) any later version.

This library is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
General Public License for more details.

    http://www.gnu.org/copyleft/lesser.txt

 =============================================================================*/

/* NOTE: This code has been made to coexist with prototype.js which is
 * notorious for NOT PLAYING WELL WITH OTHERS! However, this library must be
 * imported *after* prototype.js, or it will be clobbered. :\
 */

if (! this.Ajax) Ajax = {};

Ajax.VERSION = '0.10';

// The simple user interface function to GET/PUT/POST. If no callback is
// used, the function is synchronous.

Ajax.get = function(url, callback, params) {
    if (! params) params = {};
    params.url = url;
    params.onComplete = callback;
    return (new Ajax.Req()).get(params);
}

Ajax.put = function(url, data, callback, params) {
    if (! params) params = {};
    params.url = url;
    params.data = data;
    params.onComplete = callback;
    return (new Ajax.Req()).put(params);
}

Ajax.post = function(url, data, callback, params) {
    if (! params) params = {};
    params.url = url;
    params.data = data;
    params.onComplete = callback;
    if (! params.contentType)
        params.contentType = 'application/x-www-form-urlencoded';
    return (new Ajax.Req()).post(params);
}

if (this.Ajax.Req)
    throw("Oh no, somebody else is using the Ajax.Req namespace!");

Ajax.Req = function () {};
proto = Ajax.Req.prototype;

// Allows one to override with something more drastic.
// Can even be done "on the fly" using a bookmarklet.
// As an example, the test suite overrides this to test error conditions.
proto.die = function(e) { throw(e) };

// Object interface
proto.get = function(params) {
    return this._send(params, 'GET', 'Accept');
}

proto.put = function(params) {
    return this._send(params, 'PUT', 'Content-Type');
}

proto.post = function(params) {
    return this._send(params, 'POST', 'Content-Type');
}

// Set up the Ajax object with a working XHR object.
proto._init_object = function(params) {
    for (key in params) {
        if (! key.match(/^url|data|onComplete|contentType$/))
            throw("Invalid Ajax parameter: " + key);
        this[key] = params[key];
    }

    if (! this.contentType)
        this.contentType = 'application/json';

    if (! this.url)
        throw("'url' required for Ajax get/post method");

    if (this.request)
        throw("Don't yet support multiple requests on the same Ajax object");

    this.request = new XMLHttpRequest();

    if (! this.request)
        return this.die("Your browser doesn't do Ajax");
    if (this.request.readyState != 0)
        return this.die("Ajax readyState should be 0");

    return this;
}

proto._send = function(params, request_type, header) {
    this._init_object(params);
    this.request.open(request_type, this.url, Boolean(this.onComplete));
    this.request.setRequestHeader(header, this.contentType);

    var self = this;
    if (this.onComplete) {
        this.request.onreadystatechange = function() {
            self._check_asynchronous();
        };
    }
    this.request.send(this.data);
    return Boolean(this.onComplete)
        ? this
        : this._check_synchronous();
}

// TODO Allow handlers for various readyStates and statusCodes.
// Make these be the default handlers.
proto._check_status = function() {
    var status = String(this.request.status);
    if (!status.match('^20[0-9]')) {
        return this.die(
            'Ajax request for "' + this.url +
            '" failed with status: ' + status
        );
    }
}

proto._check_synchronous = function() {
    this._check_status();
    return this.request.responseText;
}

proto._check_asynchronous = function() {
    if (this.request.readyState != 4) return;
    this._check_status();
    this.onComplete(this.request.responseText);
}

// IE support
if (window.ActiveXObject && !window.XMLHttpRequest) {
    window.XMLHttpRequest = function() {
        var name = (navigator.userAgent.toLowerCase().indexOf('msie 5') != -1)
            ? 'Microsoft.XMLHTTP' : 'Msxml2.XMLHTTP';
        return new ActiveXObject(name);
    }
}
// BEGIN ../../../js-modules/template.js
/**
 * TrimPath Template. Release 1.0.38.
 * Copyright (C) 2004, 2005 Metaha.
 * 
 * TrimPath Template is licensed under the GNU General Public License
 * and the Apache License, Version 2.0, as follows:
 *
 * This program is free software; you can redistribute it and/or 
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * 
 * This program is distributed WITHOUT ANY WARRANTY; without even the 
 * implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
 * See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 * http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
var TrimPath;

// TODO: Debugging mode vs stop-on-error mode - runtime flag.
// TODO: Handle || (or) characters and backslashes.
// TODO: Add more modifiers.

(function() {               // Using a closure to keep global namespace clean.
    if (TrimPath == null)
        TrimPath = new Object();
    if (TrimPath.evalEx == null)
        TrimPath.evalEx = function(src) { return eval(src); };

    var UNDEFINED;
    if (Array.prototype.pop == null)  // IE 5.x fix from Igor Poteryaev.
        Array.prototype.pop = function() {
            if (this.length === 0) {return UNDEFINED;}
            return this[--this.length];
        };
    if (Array.prototype.push == null) // IE 5.x fix from Igor Poteryaev.
        Array.prototype.push = function() {
            for (var i = 0; i < arguments.length; ++i) {this[this.length] = arguments[i];}
            return this.length;
        };

    TrimPath.parseTemplate = function(tmplContent, optTmplName, optEtc) {
        if (optEtc == null)
            optEtc = TrimPath.parseTemplate_etc;
        var funcSrc = parse(tmplContent, optTmplName, optEtc);
        var func = TrimPath.evalEx(funcSrc, optTmplName, 1);
        if (func != null)
            return new optEtc.Template(optTmplName, tmplContent, funcSrc, func, optEtc);
        return null;
    }
    
    try {
        String.prototype.process = function(context, optFlags) {
            var template = TrimPath.parseTemplate(this, null);
            if (template != null)
                return template.process(context, optFlags);
            return this;
        }
    } catch (e) { // Swallow exception, such as when String.prototype is sealed.
    }
    
    TrimPath.parseTemplate_etc = {};            // Exposed for extensibility.
    TrimPath.parseTemplate_etc.statementTag = "forelse|for|if|elseif|else|var|macro";
    TrimPath.parseTemplate_etc.statementDef = { // Lookup table for statement tags.
        "if"     : { delta:  1, prefix: "if (", suffix: ") {", paramMin: 1 },
        "else"   : { delta:  0, prefix: "} else {" },
        "elseif" : { delta:  0, prefix: "} else if (", suffix: ") {", paramDefault: "true" },
        "/if"    : { delta: -1, prefix: "}" },
        "for"    : { delta:  1, paramMin: 3, 
                     prefixFunc : function(stmtParts, state, tmplName, etc) {
                        if (stmtParts[2] != "in")
                            throw new etc.ParseError(tmplName, state.line, "bad for loop statement: " + stmtParts.join(' '));
                        var iterVar = stmtParts[1];
                        var listVar = "__LIST__" + iterVar;
                        return [ "var ", listVar, " = ", stmtParts[3], ";",
                             // Fix from Ross Shaull for hash looping, make sure that we have an array of loop lengths to treat like a stack.
                             "var __LENGTH_STACK__;",
                             "if (typeof(__LENGTH_STACK__) == 'undefined' || !__LENGTH_STACK__.length) __LENGTH_STACK__ = new Array();", 
                             "__LENGTH_STACK__[__LENGTH_STACK__.length] = 0;", // Push a new for-loop onto the stack of loop lengths.
                             "if ((", listVar, ") != null) { ",
                             "var ", iterVar, "_ct = 0;",       // iterVar_ct variable, added by B. Bittman     
                             "for (var ", iterVar, "_index in ", listVar, ") { ",
                             iterVar, "_ct++;",
                             "if (typeof(", listVar, "[", iterVar, "_index]) == 'function') {continue;}", // IE 5.x fix from Igor Poteryaev.
                             "__LENGTH_STACK__[__LENGTH_STACK__.length - 1]++;",
                             "var ", iterVar, " = ", listVar, "[", iterVar, "_index];" ].join("");
                     } },
        "forelse" : { delta:  0, prefix: "} } if (__LENGTH_STACK__[__LENGTH_STACK__.length - 1] == 0) { if (", suffix: ") {", paramDefault: "true" },
        "/for"    : { delta: -1, prefix: "} }; delete __LENGTH_STACK__[__LENGTH_STACK__.length - 1];" }, // Remove the just-finished for-loop from the stack of loop lengths.
        "var"     : { delta:  0, prefix: "var ", suffix: ";" },
        "macro"   : { delta:  1, 
                      prefixFunc : function(stmtParts, state, tmplName, etc) {
                          var macroName = stmtParts[1].split('(')[0];
                          return [ "var ", macroName, " = function", 
                                   stmtParts.slice(1).join(' ').substring(macroName.length),
                                   "{ var _OUT_arr = []; var _OUT = { write: function(m) { if (m) _OUT_arr.push(m); } }; " ].join('');
                     } }, 
        "/macro"  : { delta: -1, prefix: " return _OUT_arr.join(''); };" }
    }
    TrimPath.parseTemplate_etc.modifierDef = {
        "eat"        : function(v)    { return ""; },
        "escape"     : function(s)    { return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); },
        "capitalize" : function(s)    { return String(s).toUpperCase(); },
        "default"    : function(s, d) { return s != null ? s : d; }
    }
    TrimPath.parseTemplate_etc.modifierDef.h = TrimPath.parseTemplate_etc.modifierDef.escape;

    TrimPath.parseTemplate_etc.Template = function(tmplName, tmplContent, funcSrc, func, etc) {
        this.process = function(context, flags) {
            if (context == null)
                context = {};
            if (context._MODIFIERS == null)
                context._MODIFIERS = {};
            if (context.defined == null)
                context.defined = function(str) { return (context[str] != undefined); };
            for (var k in etc.modifierDef) {
                if (context._MODIFIERS[k] == null)
                    context._MODIFIERS[k] = etc.modifierDef[k];
            }
            if (flags == null)
                flags = {};
            var resultArr = [];
            var resultOut = { write: function(m) { resultArr.push(m); } };
            try {
                func(resultOut, context, flags);
            } catch (e) {
                if (flags.throwExceptions == true)
                    throw e;
                var result = new String(resultArr.join("") + "[ERROR: " + e.toString() + (e.message ? '; ' + e.message : '') + "]");
                result["exception"] = e;
                return result;
            }
            return resultArr.join("");
        }
        this.name       = tmplName;
        this.source     = tmplContent; 
        this.sourceFunc = funcSrc;
        this.toString   = function() { return "TrimPath.Template [" + tmplName + "]"; }
    }
    TrimPath.parseTemplate_etc.ParseError = function(name, line, message) {
        this.name    = name;
        this.line    = line;
        this.message = message;
    }
    TrimPath.parseTemplate_etc.ParseError.prototype.toString = function() { 
        return ("TrimPath template ParseError in " + this.name + ": line " + this.line + ", " + this.message);
    }
    
    var parse = function(body, tmplName, etc) {
        body = cleanWhiteSpace(body);
        var funcText = [ "var TrimPath_Template_TEMP = function(_OUT, _CONTEXT, _FLAGS) { with (_CONTEXT) {" ];
        var state    = { stack: [], line: 1 };                              // TODO: Fix line number counting.
        var endStmtPrev = -1;
        while (endStmtPrev + 1 < body.length) {
            var begStmt = endStmtPrev;
            // Scan until we find some statement markup.
            begStmt = body.indexOf("{", begStmt + 1);
            while (begStmt >= 0) {
                var endStmt = body.indexOf('}', begStmt + 1);
                var stmt = body.substring(begStmt, endStmt);
                var blockrx = stmt.match(/^\{(cdata|minify|eval)/); // From B. Bittman, minify/eval/cdata implementation.
                if (blockrx) {
                    var blockType = blockrx[1]; 
                    var blockMarkerBeg = begStmt + blockType.length + 1;
                    var blockMarkerEnd = body.indexOf('}', blockMarkerBeg);
                    if (blockMarkerEnd >= 0) {
                        var blockMarker;
                        if( blockMarkerEnd - blockMarkerBeg <= 0 ) {
                            blockMarker = "{/" + blockType + "}";
                        } else {
                            blockMarker = body.substring(blockMarkerBeg + 1, blockMarkerEnd);
                        }                        
                        
                        var blockEnd = body.indexOf(blockMarker, blockMarkerEnd + 1);
                        if (blockEnd >= 0) {                            
                            emitSectionText(body.substring(endStmtPrev + 1, begStmt), funcText);
                            
                            var blockText = body.substring(blockMarkerEnd + 1, blockEnd);
                            if (blockType == 'cdata') {
                                emitText(blockText, funcText);
                            } else if (blockType == 'minify') {
                                emitText(scrubWhiteSpace(blockText), funcText);
                            } else if (blockType == 'eval') {
                                if (blockText != null && blockText.length > 0) // From B. Bittman, eval should not execute until process().
                                    funcText.push('_OUT.write( (function() { ' + blockText + ' })() );');
                            }
                            begStmt = endStmtPrev = blockEnd + blockMarker.length - 1;
                        }
                    }                        
                } else if (body.charAt(begStmt - 1) != '$' &&               // Not an expression or backslashed,
                           body.charAt(begStmt - 1) != '\\') {              // so check if it is a statement tag.
                    var offset = (body.charAt(begStmt + 1) == '/' ? 2 : 1); // Close tags offset of 2 skips '/'.
                                                                            // 10 is larger than maximum statement tag length.
                    if (body.substring(begStmt + offset, begStmt + 10 + offset).search(TrimPath.parseTemplate_etc.statementTag) == 0) 
                        break;                                              // Found a match.
                }
                begStmt = body.indexOf("{", begStmt + 1);
            }
            if (begStmt < 0)                              // In "a{for}c", begStmt will be 1.
                break;
            var endStmt = body.indexOf("}", begStmt + 1); // In "a{for}c", endStmt will be 5.
            if (endStmt < 0)
                break;
            emitSectionText(body.substring(endStmtPrev + 1, begStmt), funcText);
            emitStatement(body.substring(begStmt, endStmt + 1), state, funcText, tmplName, etc);
            endStmtPrev = endStmt;
        }
        emitSectionText(body.substring(endStmtPrev + 1), funcText);
        if (state.stack.length != 0)
            throw new etc.ParseError(tmplName, state.line, "unclosed, unmatched statement(s): " + state.stack.join(","));
        funcText.push("}}; TrimPath_Template_TEMP");
        return funcText.join("");
    }
    
    var emitStatement = function(stmtStr, state, funcText, tmplName, etc) {
        var parts = stmtStr.slice(1, -1).split(' ');
        var stmt = etc.statementDef[parts[0]]; // Here, parts[0] == for/if/else/...
        if (stmt == null) {                    // Not a real statement.
            emitSectionText(stmtStr, funcText);
            return;
        }
        if (stmt.delta < 0) {
            if (state.stack.length <= 0)
                throw new etc.ParseError(tmplName, state.line, "close tag does not match any previous statement: " + stmtStr);
            state.stack.pop();
        } 
        if (stmt.delta > 0)
            state.stack.push(stmtStr);

        if (stmt.paramMin != null &&
            stmt.paramMin >= parts.length)
            throw new etc.ParseError(tmplName, state.line, "statement needs more parameters: " + stmtStr);
        if (stmt.prefixFunc != null)
            funcText.push(stmt.prefixFunc(parts, state, tmplName, etc));
        else 
            funcText.push(stmt.prefix);
        if (stmt.suffix != null) {
            if (parts.length <= 1) {
                if (stmt.paramDefault != null)
                    funcText.push(stmt.paramDefault);
            } else {
                for (var i = 1; i < parts.length; i++) {
                    if (i > 1)
                        funcText.push(' ');
                    funcText.push(parts[i]);
                }
            }
            funcText.push(stmt.suffix);
        }
    }

    var emitSectionText = function(text, funcText) {
        if (text.length <= 0)
            return;
        var nlPrefix = 0;               // Index to first non-newline in prefix.
        var nlSuffix = text.length - 1; // Index to first non-space/tab in suffix.
        while (nlPrefix < text.length && (text.charAt(nlPrefix) == '\n'))
            nlPrefix++;
        while (nlSuffix >= 0 && (text.charAt(nlSuffix) == ' ' || text.charAt(nlSuffix) == '\t'))
            nlSuffix--;
        if (nlSuffix < nlPrefix)
            nlSuffix = nlPrefix;
        if (nlPrefix > 0) {
            funcText.push('if (_FLAGS.keepWhitespace == true) _OUT.write("');
            var s = text.substring(0, nlPrefix).replace('\n', '\\n'); // A macro IE fix from BJessen.
            if (s.charAt(s.length - 1) == '\n')
            	s = s.substring(0, s.length - 1);
            funcText.push(s);
            funcText.push('");');
        }
        var lines = text.substring(nlPrefix, nlSuffix + 1).split('\n');
        for (var i = 0; i < lines.length; i++) {
            emitSectionTextLine(lines[i], funcText);
            if (i < lines.length - 1)
                funcText.push('_OUT.write("\\n");\n');
        }
        if (nlSuffix + 1 < text.length) {
            funcText.push('if (_FLAGS.keepWhitespace == true) _OUT.write("');
            var s = text.substring(nlSuffix + 1).replace('\n', '\\n');
            if (s.charAt(s.length - 1) == '\n')
            	s = s.substring(0, s.length - 1);
            funcText.push(s);
            funcText.push('");');
        }
    }
    
    var emitSectionTextLine = function(line, funcText) {
        var endMarkPrev = '}';
        var endExprPrev = -1;
        while (endExprPrev + endMarkPrev.length < line.length) {
            var begMark = "${", endMark = "}";
            var begExpr = line.indexOf(begMark, endExprPrev + endMarkPrev.length); // In "a${b}c", begExpr == 1
            if (begExpr < 0)
                break;
            if (line.charAt(begExpr + 2) == '%') {
                begMark = "${%";
                endMark = "%}";
            }
            var endExpr = line.indexOf(endMark, begExpr + begMark.length);         // In "a${b}c", endExpr == 4;
            if (endExpr < 0)
                break;
            emitText(line.substring(endExprPrev + endMarkPrev.length, begExpr), funcText);                
            // Example: exprs == 'firstName|default:"John Doe"|capitalize'.split('|')
            var exprArr = line.substring(begExpr + begMark.length, endExpr).replace(/\|\|/g, "#@@#").split('|');
            for (var k in exprArr) {
                if (exprArr[k].replace) // IE 5.x fix from Igor Poteryaev.
                    exprArr[k] = exprArr[k].replace(/#@@#/g, '||');
            }
            funcText.push('_OUT.write(');
            emitExpression(exprArr, exprArr.length - 1, funcText); 
            funcText.push(');');
            endExprPrev = endExpr;
            endMarkPrev = endMark;
        }
        emitText(line.substring(endExprPrev + endMarkPrev.length), funcText); 
    }
    
    var emitText = function(text, funcText) {
        if (text == null ||
            text.length <= 0)
            return;
        text = text.replace(/\\/g, '\\\\');
        text = text.replace(/\n/g, '\\n');
        text = text.replace(/"/g,  '\\"');
        funcText.push('_OUT.write("');
        funcText.push(text);
        funcText.push('");');
    }
    
    var emitExpression = function(exprArr, index, funcText) {
        // Ex: foo|a:x|b:y1,y2|c:z1,z2 is emitted as c(b(a(foo,x),y1,y2),z1,z2)
        var expr = exprArr[index]; // Ex: exprArr == [firstName,capitalize,default:"John Doe"]
        if (index <= 0) {          // Ex: expr    == 'default:"John Doe"'
            funcText.push(expr);
            return;
        }
        var parts = expr.split(':');
        funcText.push('_MODIFIERS["');
        funcText.push(parts[0]); // The parts[0] is a modifier function name, like capitalize.
        funcText.push('"](');
        emitExpression(exprArr, index - 1, funcText);
        if (parts.length > 1) {
            funcText.push(',');
            funcText.push(parts[1]);
        }
        funcText.push(')');
    }

    var cleanWhiteSpace = function(result) {
        result = result.replace(/\t/g,   "    ");
        result = result.replace(/\r\n/g, "\n");
        result = result.replace(/\r/g,   "\n");
        result = result.replace(/^(\s*\S*(\s+\S+)*)\s*$/, '$1'); // Right trim by Igor Poteryaev.
        return result;
    }

    var scrubWhiteSpace = function(result) {
        result = result.replace(/^\s+/g,   "");
        result = result.replace(/\s+$/g,   "");
        result = result.replace(/\s+/g,   " ");
        result = result.replace(/^(\s*\S*(\s+\S+)*)\s*$/, '$1'); // Right trim by Igor Poteryaev.
        return result;
    }

    // The DOM helper functions depend on DOM/DHTML, so they only work in a browser.
    // However, these are not considered core to the engine.
    //
    TrimPath.parseDOMTemplate = function(elementId, optDocument, optEtc) {
        if (optDocument == null)
            optDocument = document;
        var element = optDocument.getElementById(elementId);
        var content = element.value;     // Like textarea.value.
        if (content == null)
            content = element.innerHTML; // Like textarea.innerHTML.
        content = content.replace(/&lt;/g, "<").replace(/&gt;/g, ">");
        return TrimPath.parseTemplate(content, elementId, optEtc);
    }

    TrimPath.processDOMTemplate = function(elementId, context, optFlags, optDocument, optEtc) {
        return TrimPath.parseDOMTemplate(elementId, optDocument, optEtc).process(context, optFlags);
    }
}) ();
// BEGIN ../../../js-modules/DOM-Ready/lib/DOM/Ready.js
if ( typeof DOM == "undefined" ) DOM = {};

DOM.Ready = {};

DOM.Ready.VERSION = '0.14';

DOM.Ready.finalTimeout = 15;
DOM.Ready.timerInterval = 50;

/* This works for Mozilla */
if ( document.addEventListener ) {
    document.addEventListener
        ( "DOMContentLoaded", function () { DOM.Ready._isDone = 1; }, false );
}

DOM.Ready._checkDOMReady = function () {
    if ( DOM.Ready._isReady ) return DOM.Ready._isReady;

    if (    typeof document.getElementsByTagName != 'undefined'
         && typeof document.getElementById != 'undefined' 
         && ( document.getElementsByTagName('body')[0] != null
              || document.body != null ) ) {

        DOM.Ready._isReady = 1;
    }

    return DOM.Ready._isReady;

};

DOM.Ready._checkDOMDone = function () {
    /* IE (and Opera?) only */
    if ( document.readyState
         && ( document.readyState == "interactive"
              || document.readyState == "complete" ) ) {
        return 1;
    }

    return DOM.Ready._isDone;
};

DOM.Ready.onDOMReady = function (callback) {
    if ( DOM.Ready._checkDOMReady() ) {
        callback();
    }
    else {
        DOM.Ready._onDOMReadyCallbacks.push(callback);
    }
}

DOM.Ready.onDOMDone = function (callback) {
    if ( DOM.Ready._checkDOMDone() ) {
        callback();
    }
    else {
        DOM.Ready._onDOMDoneCallbacks.push(callback);
    }
}

DOM.Ready.onIdReady = function ( id, callback ) {
    if ( DOM.Ready._checkDOMReady() ) {
        var elt = document.getElementById(id);
        if (elt) {
            callback(elt);
            return;
        }
    }

    var callback_array = DOM.Ready._onIdReadyCallbacks[id];
    if ( ! callback_array ) {
        callback_array = [];
    }
    callback_array.push(callback);

    DOM.Ready._onIdReadyCallbacks[id] = callback_array;
}

DOM.Ready._runDOMReadyCallbacks = function () {
    for ( var i = 0; i < DOM.Ready._onDOMReadyCallbacks.length; i++ ) {
        DOM.Ready._onDOMReadyCallbacks[i]();
    }

    DOM.Ready._onDOMReadyCallbacks = [];
}

DOM.Ready._runDOMDoneCallbacks = function () {
    for ( var i = 0; i < DOM.Ready._onDOMDoneCallbacks.length; i++ ) {
        DOM.Ready._onDOMDoneCallbacks[i]();
    }

    DOM.Ready._onDOMDoneCallbacks = [];
}

DOM.Ready._runIdCallbacks = function () {
    for ( var id in DOM.Ready._onIdReadyCallbacks ) {
        // protect against changes to Object (ala prototype's extend)
        if ( ! DOM.Ready._onIdReadyCallbacks.hasOwnProperty(id) ) {
            continue;
        }

        var elt = document.getElementById(id);

        if (elt) {
            for ( var i = 0; i < DOM.Ready._onIdReadyCallbacks[id].length; i++) {
                DOM.Ready._onIdReadyCallbacks[id][i](elt);
            }

            delete DOM.Ready._onIdReadyCallbacks[id];
        }
    }
}

DOM.Ready._runReadyCallbacks = function () {
    if ( DOM.Ready._inRunReadyCallbacks ) return;

    DOM.Ready._inRunReadyCallbacks = 1;

    if ( DOM.Ready._checkDOMReady() ) {
        DOM.Ready._runDOMReadyCallbacks();

        DOM.Ready._runIdCallbacks();
    }

    if ( DOM.Ready._checkDOMDone() ) {
        DOM.Ready._runDOMDoneCallbacks();
    }

    DOM.Ready._timePassed += DOM.Ready._lastTimerInterval;

    if ( ( DOM.Ready._timePassed / 1000 ) >= DOM.Ready.finalTimeout ) {
        DOM.Ready._stopTimer();
    }

    DOM.Ready._inRunReadyCallbacks = 0;
}

DOM.Ready._startTimer = function () {
    DOM.Ready._lastTimerInterval = DOM.Ready.timerInterval;
    DOM.Ready._intervalId = setInterval( DOM.Ready._runReadyCallbacks, DOM.Ready.timerInterval );
};

DOM.Ready._stopTimer = function () {
    clearInterval( DOM.Ready._intervalId );
    DOM.Ready._intervalId = null;
}

DOM.Ready._resetClass = function () {
    DOM.Ready._stopTimer();

    DOM.Ready._timePassed = 0;

    DOM.Ready._isReady = 0;
    DOM.Ready._isDone = 0;

    DOM.Ready._onDOMReadyCallbacks = [];
    DOM.Ready._onDOMDoneCallbacks = [];
    DOM.Ready._onIdReadyCallbacks = {};

    DOM.Ready._startTimer();
}

DOM.Ready._resetClass();

DOM.Ready.runCallbacks = function () { DOM.Ready._runReadyCallbacks() };


/*

*/
// BEGIN ../../../js-modules/DOM-Events/lib/DOM/Events.js
/**

=head1 NAME

DOM.Events - Event registration abstraction layer

=head1 SYNOPSIS

  JSAN.use("DOM.Events");

  function handleClick(e) {
      e.currentTarget.style.backgroundColor = "#68b";
  }

  DOM.Events.addListener(window, "load", function () {
      alert("The page is loaded.");
  });

  DOM.Events.addListener(window, "load", function () {
      // this listener won't interfere with the first one
      var divs = document.getElementsByTagName("div");
      for(var i=0; i<divs.length; i++) {
          DOM.Events.addListener(divs[i], "click", handleClick);
      }
  });

=head1 DESCRIPTION

This library lets you use a single interface to listen for and handle all DOM events
to reduce browser-specific code branching.  It also helps in dealing with Internet
Explorer's memory leak problem by automatically unsetting all event listeners when
the page is unloaded (for IE only).

=cut

*/

(function () {
	if(typeof DOM == "undefined") DOM = {};
	DOM.Events = {};
	
    DOM.Events.VERSION = "0.02";
	DOM.Events.EXPORT = [];
	DOM.Events.EXPORT_OK = ["addListener", "removeListener"];
	DOM.Events.EXPORT_TAGS = {
		":common": DOM.Events.EXPORT,
		":all": [].concat(DOM.Events.EXPORT, DOM.Events.EXPORT_OK)
	};
	
	// list of event listeners set by addListener
	// offset 0 is null to prevent 0 from being used as a listener identifier
	var listenerList = [null];
	
/**

=head2 Functions

All functions are kept inside the namespace C<DOM.Events> and aren't exported
automatically.

=head3 addListener( S<I<HTMLElement> element,> S<I<string> eventType,>
S<I<Function> handler> S<[, I<boolean> makeCompatible = true] )>

Registers an event listener/handler on an element.  The C<eventType> string should
I<not> be prefixed with "on" (e.g. "mouseover" not "onmouseover"). If C<makeCompatible>
is C<true> (the default), the handler is put inside a wrapper that lets you handle the
events using parts of the DOM Level 2 Events model, even in Internet Explorer (and
behave-alikes). Specifically:

=over

=item *

The event object is passed as the first argument to the event handler, so you don't
have to access it through C<window.event>.

=item *

The event object has the properties C<target>, C<currentTarget>, and C<relatedTarget>
and the methods C<preventDefault()> and C<stopPropagation()> that behave as described
in the DOM Level 2 Events specification (for the most part).

=item *

If possible, the event object for mouse events will have the properties C<pageX> and
C<pageY> that contain the mouse's position relative to the document at the time the
event occurred.

=item *

If you attempt to set a duplicate event handler on an element, the duplicate will
still be added (this is different from the DOM2 Events model, where duplicates are
discarded).

=back

If C<makeCompatible> is C<false>, the arguments are simply passed to the browser's
native event registering facilities, which means you'll have to deal with event
incompatibilities yourself. However, if you don't need to access the event information,
doing it this way can be slightly faster and it gives you the option of unsetting the
handler with a different syntax (see below).

The return value is a positive integer identifier for the listener that can be used to
unregister it later on in your script.

=cut

*/
    
	DOM.Events.addListener = function(elt, ev, func, makeCompatible) {
		var usedFunc = func;
        var id = listenerList.length;
		if(makeCompatible == true || makeCompatible == undefined) {
			usedFunc = makeCompatibilityWrapper(elt, ev, func);
		}
		if(elt.addEventListener) {
			elt.addEventListener(ev, usedFunc, false);
			listenerList[id] = [elt, ev, usedFunc];
			return id;
		}
		else if(elt.attachEvent) {
			elt.attachEvent("on" + ev, usedFunc);
			listenerList[id] = [elt, ev, usedFunc];
			return id;
		}
		else return false;
	};
	
/**

=head3 removeListener( S<I<integer> identifier> )

Unregisters the event listener associated with the given identifier so that it will
no longer be called when the event fires.

  var listener = DOM.Events.addListener(myElement, "mousedown", myHandler);
  // later on ...
  DOM.Events.removeListener(listener);

=head3 removeListener( S<I<HTMLElement> element,> S<I<string> eventType,> S<I<Function> handler )>

This alternative syntax can be also be used to unset an event listener, but it can only
be used if C<makeCompatible> was C<false> when it was set.

=cut

*/

	DOM.Events.removeListener = function() {
		var elt, ev, func;
		if(arguments.length == 1 && listenerList[arguments[0]]) {
			elt  = listenerList[arguments[0]][0];
			ev   = listenerList[arguments[0]][1];
			func = listenerList[arguments[0]][2];
			delete listenerList[arguments[0]];
		}
		else if(arguments.length == 3) {
			elt  = arguments[0];
			ev   = arguments[1];
			func = arguments[2];
		}
		else return;
		
		if(elt.removeEventListener) {
			elt.removeEventListener(ev, func, false);
		}
		else if(elt.detachEvent) {
			elt.detachEvent("on" + ev, func);
		}
	};
	
    var rval;
    
    function makeCompatibilityWrapper(elt, ev, func) {
        return function (e) {
            rval = true;
            if(e == undefined && window.event != undefined)
                e = window.event;
            if(e.target == undefined && e.srcElement != undefined)
                e.target = e.srcElement;
            if(e.currentTarget == undefined)
                e.currentTarget = elt;
            if(e.relatedTarget == undefined) {
                if(ev == "mouseover" && e.fromElement != undefined)
                    e.relatedTarget = e.fromElement;
                else if(ev == "mouseout" && e.toElement != undefined)
                    e.relatedTarget = e.toElement;
            }
            if(e.pageX == undefined) {
                if(document.body.scrollTop != undefined) {
                    e.pageX = e.clientX + document.body.scrollLeft;
                    e.pageY = e.clientY + document.body.scrollTop;
                }
                if(document.documentElement != undefined
                && document.documentElement.scrollTop != undefined) {
                    if(document.documentElement.scrollTop > 0
                    || document.documentElement.scrollLeft > 0) {
                        e.pageX = e.clientX + document.documentElement.scrollLeft;
                        e.pageY = e.clientY + document.documentElement.scrollTop;
                    }
                }
            }
            if(e.stopPropagation == undefined)
                e.stopPropagation = IEStopPropagation;
            if(e.preventDefault == undefined)
                e.preventDefault = IEPreventDefault;
            if(e.cancelable == undefined) e.cancelable = true;
            func(e);
            return rval;
        };
    }
    
    function IEStopPropagation() {
        if(window.event) window.event.cancelBubble = true;
    }
    
    function IEPreventDefault() {
        rval = false;
    }

	function cleanUpIE () {
		for(var i=0; i<listenerList.length; i++) {
			var listener = listenerList[i];
			if(listener) {
				var elt = listener[0];
                var ev = listener[1];
                var func = listener[2];
				elt.detachEvent("on" + ev, func);
			}
		}
        listenerList = null;
	}

	if(!window.addEventListener && window.attachEvent) {
		window.attachEvent("onunload", cleanUpIE);
	}

})();

/**

=head1 SEE ALSO

DOM Level 2 Events Specification,
L<http://www.w3.org/TR/DOM-Level-2-Events/>

Understanding and Solving Internet Explorer Leak Patterns,
L<http://msdn.microsoft.com/library/default.asp?url=/library/en-us/IETechCol/dnwebgen/ie_leak_patterns.asp>

=head1 AUTHOR

Justin Constantino, <F<goflyapig@gmail.com>>.

=head1 COPYRIGHT

  Copyright (c) 2005 Justin Constantino.  All rights reserved.
  This module is free software; you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public Licence.

=cut

*/// BEGIN ../../../js-modules/Widget-SortableTable/lib/Widget/SortableTable.js
JSAN.use("DOM.Ready");
JSAN.use("DOM.Events");

if ( typeof Widget == "undefined" ) Widget = {};

Widget.SortableTable = function (params) {
    this._initialize(params);
};

Widget.SortableTable.VERSION = "0.21";

Widget.SortableTable.prototype._initialize = function (params) {
    if ( ! params ) {
        throw new Error("Cannot create a new Widget.SortableTable without parameters");
    }

    if ( ! params.tableId ) {
        throw new Error("Widget.SortableTable requires a tableId parameter");
    }

    this._initialSortColumn = params.initialSortColumn;
    if ( ! this._initialSortColumn ) {
        this._initialSortColumn = 0;
    }
    this._col_specs = [];
    if ( params.columnSpecs ) {
        for ( var i = 0; i < params.columnSpecs.length; i++ ) {
            if ( params.columnSpecs[i] ) {
                this._col_specs[i] = params.columnSpecs[i];
            }
        }
    }

    this._noInitialSort = params.noInitialSort;

    this._onSortRowCallback = params.onSortRowCallback;

    if ( ! params.secondarySortColumn ) {
        this._secondarySortColumn = 0;
    }
    else {
        this._secondarySortColumn = params.secondarySortColumn;
    }

    var self = this;
    DOM.Ready.onIdReady( params.tableId,
                         function (elt) { self._instrumentTable(elt) }
                       );
};

Widget.SortableTable._seenId = {};

Widget.SortableTable.prototype._instrumentTable = function (table) {
    this._table = table;

    var head = table.rows[0];

    if ( ! head ) {
        return;
    }

    for ( var i = 0; i < head.cells.length; i++ ) {
        if ( this._col_specs[i] && this._col_specs[i].skip ) {
            continue;
        }

        if ( ! Widget.SortableTable._seenId[ table.id ] ) {
            this._makeColumnSortable( head.cells[i], i );
        }

        this._removeCSSClass( head.cells[i], "w-st-desc-column-header" );
        this._removeCSSClass( head.cells[i], "w-st-asc-column-header" );
        this._addCSSClass( head.cells[i], "w-st-unsorted-column-header" );
    }

    if ( this._noInitialSort ) {
        this._setRowCSS();
    }
    else {
        this.sortOnColumn( this._initialSortColumn );
    }

    Widget.SortableTable._seenId[ table.id ] = true;
};

Widget.SortableTable.prototype._makeColumnSortable = function (cell, idx) {
    var href = document.createElement("a");
    href.setAttribute( "href", "#" );
    href.setAttribute( "onClick", "return false;" );
    href.className = "w-st-resort-column";

    this._moveChildTree( cell, href );
    cell.appendChild(href);

    var self = this;
    DOM.Events.addListener( href,
                            "click",
                            function () { self.sortOnColumn(idx); return false; }
                          );
};

Widget.SortableTable.prototype._moveChildTree = function (from, to) {
    if ( document.implementation.hasFeature( "Range", "2.0" ) ) {
        var range = document.createRange();
        range.selectNodeContents(from);

        to.appendChild( range.extractContents() );
    }
    else {
        /* XXX - this is gross but seems to work */
        to.innerHTML = from.innerHTML;
        from.innerHTML = "";
    }
};

Widget.SortableTable.prototype.sortOnColumn = function (idx) {
    if (! this._table ) {
        return;
    }

    if ( this._table.rows.length == 1 ) {
        return;
    }

    var cell_data = [];
    var rows = [];
    /* start at 1 to ignore the header row when sorting */
    for ( var i = 1; i < this._table.rows.length; i++ ) {
        var text = this._getAllText( this._table.rows[i].cells[idx] );
        var cell_info = { "primaryText": text, "rowNumber": i - 1 };
        if ( idx != this._secondarySortColumn ) {
            cell_info.secondaryText =
                this._getAllText( this._table.rows[i].cells[ this._secondarySortColumn ] );
        }

        cell_data.push(cell_info);
        rows.push( this._table.rows[i] );
    }

    var sort_info = this._sortFor( idx, cell_data[0].primaryText );
    if ( idx != this._secondarySortColumn ) {
        var sec_sort_info = this._sortFor( this._secondarySortColumn, cell_data[0].secondaryText );
        sort_info.secondaryFunc = sec_sort_info.func;
    }

    cell_data.sort( Widget.SortableTable._makeCellDataSorter
                        ( sort_info.func, sort_info.secondaryFunc ) );

    if ( sort_info.dir == "desc" ) {
        cell_data.reverse();
    }

    this._resortTable( cell_data, rows );

    this._updateCSSClasses( idx, sort_info.dir );

    this._lastSort = { "index": idx,
                       "dir":   sort_info.dir };
}

/* More or less copied from
 * http://www.kryogenix.org/code/browser/sorttable/sorttable.js
 */
Widget.SortableTable.prototype._getAllText = function (elt) {
    if ( typeof elt == "string") {
        return elt;
    }
    if ( typeof elt == "undefined") {
        return "";
    }

    var text = "";
	
    var children = elt.childNodes;
    for ( var i = 0; i < children.length; i++ ) {
        switch ( children[i].nodeType) {
        case 1: /* ELEMENT_NODE */
            text += this._getAllText( children[i] );
            break;
        case 3:	/* TEXT_NODE */
            text += children[i].nodeValue;
            break;
        }
    }

    return text;
};

Widget.SortableTable.prototype._sortFor = function (idx, content) {
    var func;
    var type; if ( this._col_specs[idx] && this._col_specs[idx].sort ) {
        if ( typeof this._col_specs[idx].sort == "function" ) {
            func = this._col_specs[idx].sort;
        }
        else {
            var sort_name = this._col_specs[idx].sort;
            type = sort_name;
            func = Widget.SortableTable._sortFunctionsByType[sort_name];
        }
    }

    if ( ! func ) {
        if ( content.match( /^\s*[\$\u20AC]\s*\d+(?:\.\d+)?\s*$/ ) ) {
            type = "currency";
            func = Widget.SortableTable._sortFunctionsByType.currency;
        }
        else if ( content.match( /^\s*\d+(?:\.\d+)?\s*$/ ) ) {
            type = "number";
            func = Widget.SortableTable._sortFunctionsByType.number;
        }
        else if ( content.match( /^\s*\d\d\d\d[^\d]+\d\d[^\d]+\d\d\s*$/ ) ) {
            type = "date";
            func = Widget.SortableTable._sortFunctionsByType.date;
        }
        else {
            type = "text";
            func = Widget.SortableTable._sortFunctionsByType.text;
        }
    }

    var dir;
    if ( this._col_specs[idx] && this._col_specs[idx].defaultDir ) {
        dir = this._col_specs[idx].defaultDir;
    }
    else if (type)  {
        dir = Widget.SortableTable._defaultDirByType[type];
    }
    else {
        dir = "asc";
    }

    if ( this._lastSort
         && this._lastSort.index == idx
         && this._lastSort.dir   == dir ) {
        dir = dir == "asc" ? "desc" : "asc";
    }

    return { "func": func,
             "dir":  dir };
};

Widget.SortableTable._sortCurrency = function (a, b) {
    var a_num = parseFloat( a.replace( /[^\d\.]/g, "" ) )
    var b_num = parseFloat( b.replace( /[^\d\.]/g, "" ) )

    return Widget.SortableTable._sortNumberOrNaN(a_num, b_num);
};

Widget.SortableTable._sortNumber = function (a, b) {
    var a_num = parseFloat(a);
    var b_num = parseFloat(b);

    return Widget.SortableTable._sortNumberOrNaN(a_num, b_num);
};

Widget.SortableTable._sortNumberOrNaN = function (a, b) {
    if ( isNaN(a) && isNaN(b) ) {
        return 0;
    }
    else if ( isNaN(a) ) {
        return -1;
    }
    else if ( isNaN(b) ) {
        return 1;
    }
    else if ( a < b ) {
        return -1;
    }
    else if ( a > b ) {
        return 1;
    }
    else {
        return 0;
    }
};

Widget.SortableTable._sortDate = function (a, b) {
    var a_match = a.match( /(\d\d\d\d)[^\d]+(\d\d)[^\d]+(\d\d)/ );
    var b_match = b.match( /(\d\d\d\d)[^\d]+(\d\d)[^\d]+(\d\d)/ );

    if ( ! a_match ) {
        a_match = [ "", -9999, 1, 1 ];
    }

    if ( ! b_match ) {
        b_match = [ "", -9999, 1, 1 ];
    }

    var a_date = new Date( a_match[1], a_match[2], a_match[3] );
    var b_date = new Date( b_match[1], b_match[2], b_match[3] );

    if ( a_date < b_date ) {
        return -1;
    }
    else if ( a_date > b_date ) {
        return 1;
    }
    else {
        return 0;
    }
};

Widget.SortableTable._sortText = function (a, b) {
    var a_text = a.toLowerCase();
    var b_text = b.toLowerCase();

    if ( a_text < b_text ) {
        return -1;
    }
    else if ( a_text > b_text ) {
        return 1;
    }
    else {
        return 0;
    }
};

Widget.SortableTable._sortFunctionsByType = {
    "currency": Widget.SortableTable._sortCurrency,
    "number":   Widget.SortableTable._sortNumber,
    "date":     Widget.SortableTable._sortDate,
    "text":     Widget.SortableTable._sortText
};

Widget.SortableTable._defaultDirByType = {
    "currency": "asc",
    "number":   "asc",
    "date":     "desc",
    "text":     "asc"
};

Widget.SortableTable._makeCellDataSorter = function ( real_func, secondary_func ) {
    return function(a, b) {
        var sort = real_func( a.primaryText, b.primaryText );
        if ( sort == 0 && secondary_func ) {
            return secondary_func( a.secondaryText, b.secondaryText );
        }
        return sort;
    };
};

Widget.SortableTable.prototype._resortTable = function (cell_data, rows) {
    for ( var i = 0; i < cell_data.length; i++ ) {
        var row = rows[ cell_data[i].rowNumber ];
        if ( i % 2 ) {
            this._removeCSSClass( row, "w-st-even-row" );
            this._addCSSClass( row, "w-st-odd-row" );
        }
        else {
            this._removeCSSClass( row, "w-st-odd-row" );
            this._addCSSClass( row, "w-st-even-row" );
        }

        if ( this._onSortRowCallback ) {
            this._onSortRowCallback( row, i + 1 );
        }

        this._table.tBodies[0].appendChild(row);
    }
};

Widget.SortableTable.prototype._setRowCSS = function () {
    for ( var i = 0; i < this._table.rows.length; i++ ) {
        if ( i % 2 ) {
            this._addCSSClass( this._table.rows[i], "w-st-even-row" );
            this._removeCSSClass( this._table.rows[i], "w-st-odd-row" );
        }
        else {
            this._addCSSClass( this._table.rows[i], "w-st-odd-row" );
            this._removeCSSClass( this._table.rows[i], "w-st-even-row" );
        }
    }
};

Widget.SortableTable.prototype._updateCSSClasses = function (idx, dir) {
    if ( ( ! this._lastSort )
         ||
         ( this._lastSort && this._lastSort.index != idx ) ) {

        for ( var i = 0; i < this._table.rows.length; i++ ) {
            this._addCSSClass( this._table.rows[i].cells[idx], "w-st-current-sorted-column" );
            if ( this._lastSort ) {
                old_idx = this._lastSort.index;
                this._removeCSSClass( this._table.rows[i].cells[old_idx], "w-st-current-sorted-column" );
            }
        }
    }

    if ( this._lastSort ) {
        var old_header_cell = this._table.rows[0].cells[ this._lastSort.index ];
        this._removeCSSClass(
            old_header_cell,
            this._lastSort.dir == "asc" ? "w-st-asc-column-header" : "w-st-desc-column-header" );
        this._addCSSClass( old_header_cell, "w-st-unsorted-column-header" );
    }

    var header_cell = this._table.rows[0].cells[idx];
    if ( this._lastSort && this._lastSort.index == idx ) {
        var old_dir = this._lastSort.dir;
        this._removeCSSClass( header_cell,
                              "w-st-" + old_dir + "-column-header" );
    }
    else {
        this._removeCSSClass( header_cell, "w-st-unsorted-column-header" );
    }
    this._addCSSClass( header_cell, "w-st-" + dir + "-column-header" );
};

Widget.SortableTable.prototype._addCSSClass = function (elt, add_class) {
    var class_regex = new RegExp(add_class);
    if ( ! elt.className.match(class_regex) ) {
        elt.className = elt.className + (elt.className.length ? " " : "" ) + add_class;
    }
};

Widget.SortableTable.prototype._removeCSSClass = function (elt, remove_class) {
    var class_regex = new RegExp( "\\s*" + remove_class );
    elt.className = elt.className.replace( class_regex, "" );
}


/*

*/
// BEGIN ../../../js-modules/Widget-Lightbox/lib/Widget/Lightbox.js
JSAN.use("DOM.Events");

if ( typeof Widget == "undefined" )
    Widget = {};

Widget.Lightbox = function(param) {
    this.win = window;
    this.doc = window.document;
    this.contentHTML = "";
    this.config = {
        clickBackgroundToHide: true
    };
    if ( param ) {
        if (param.divs ) {
            this.divs = {};
            for(var i in param.divs) {
                this.divs[i] = param.divs[i]
            }
            this.div = this.divs.wrapper;
            this.div.style.display="none";
        }
        if ( param.effects ) {
            this._effects = [];
            for (var i=0; i<param.effects.length; i++) {
                this._effects.push(param.effects[i]);
            }
        }
        if (param.wrapperClassName) {
            this.wrapperClassName = param.wrapperClassName;
        }
        else
            this.wrapperClassName = '';

        if (param.contentClassName) {
            this.contentClassName = param.contentClassName;
        }
        else
            this.contentClassName = '';
    }
    return this;
}

Widget.Lightbox.VERSION = '0.06';
Widget.Lightbox.EXPORT = [];
Widget.Lightbox.EXPORT_OK = [];
Widget.Lightbox.EXPORT_TAGS = {};

Widget.Lightbox.is_ie = function() {
    ua = navigator.userAgent.toLowerCase();
    is_ie = (
        ua.indexOf("msie") != -1 &&
        ua.indexOf("opera") == -1 &&
        ua.indexOf("webtv") == -1
    );
    return is_ie;
}();

Widget.Lightbox.show = function(param) {
    if ( typeof param == 'string' ) {
        var box = new Widget.Lightbox;
        box.content(param);
        box.show();
        return box;
    }
    else {
        var box = new Widget.Lightbox(param);
        box.show();
        return box;
    }
}

Widget.Lightbox.prototype.show = function(callback) {
    this.scrollable = "no";
    var div = this.create();
    if ( this.div.style.display== "none" )
        this.div.style.display="block";
    this.applyStyle();
    this.applyHandlers();
    this.applyEffects();

    if ( typeof callback == 'function') {
        callback(div);
    }
}

Widget.Lightbox.prototype.hide = function() {
    if (this.div.parentNode) {
        this.div.style.display="none";
        if (Widget.Lightbox.is_ie) {
            document.body.scroll = this.scrollable = "yes";
        }
    }
}

Widget.Lightbox.prototype.content = function(content) {
    if ( typeof content != 'undefined' ) {
        this._content = content;
    }
    return this._content;
}

Widget.Lightbox.prototype.create = function() {
    if (typeof this.div != 'undefined') {
        return this.div;
    }

    var wrapperDiv = this.doc.createElement("div");
    wrapperDiv.className = "jsan-widget-lightbox";

    var contentDiv = this.doc.createElement("div");

    if (this.contentClassName) {
        contentDiv.className = this.contentClassName;
    }
    else {
        contentDiv.className = "jsan-widget-lightbox-content";
    }

    if ( typeof this._content == 'object' ) {
        if ( this._content.nodeType && this._content.nodeType == 1 ) {
            contentDiv.appendChild( this._content );
        }
    }
    else {
        contentDiv.innerHTML = this._content;
    }

    var contentWrapperDiv = this.doc.createElement("div");
    if (this.wrapperClassName) {
        contentWrapperDiv.className = this.wrapperClassName;
    }
    else {
        contentWrapperDiv.className = "jsan-widget-lightbox-content-wrapper";
    }

    var bgDiv = this.doc.createElement("div");
    bgDiv.className = "jsan-widget-lightbox-background";

    contentWrapperDiv.appendChild(contentDiv);

    wrapperDiv.appendChild(bgDiv);
    wrapperDiv.appendChild(contentWrapperDiv);

    this.div = wrapperDiv;
    this.divs = {
        wrapper: wrapperDiv,
        background: bgDiv,
        content: contentDiv,
        contentWrapper: contentWrapperDiv
    };
    wrapperDiv.style.display = "none";
    this.doc.body.appendChild(this.div);
    return this.div;
}


Widget.Lightbox.prototype.applyStyle = function() {
    var divs = this.divs;
    with(divs.wrapper.style) {
        position= Widget.Lightbox.is_ie ? 'absolute': 'fixed';
        top=0;
        left=0;
        width='100%';
        height='100%';
        padding=0;
        margin=0;
    }
    with(divs.background.style) {
        position= Widget.Lightbox.is_ie ? 'absolute': 'fixed';
        background="#000";
        opacity="0.5";
        filter = "alpha(opacity=50)";
        top=0;
        left=0;
        width="100%";
        height="100%";
        zIndex=2000;
        padding=0;
        margin=0;
    }

    divs.contentWrapper.style.position = Widget.Lightbox.is_ie ? 'absolute': 'fixed';

    if (this.wrapperClassName) {
        divs.contentWrapper.className = this.wrapperClassName;
    }
    else {
        with(divs.contentWrapper.style) {
            zIndex=2001;
            padding=0;
            background='#fff';
            width='520px';
            margin='100px auto';
            border="1px outset #555";
        }
    }

    with(divs.content.style) {
        margin='5px';
    }

    var win_height = document.body.clientHeight;
    var win_width = document.body.clientWidth;
    var my_width = divs.content.offsetWidth;
    var my_left = (win_width - my_width) /2;
    my_left = (my_left < 0)? 0 : my_left + "px";
    divs.contentWrapper.style.left = my_left;

    if ( Widget.Lightbox.is_ie ) {
        document.body.scroll = this.scrollable;
        divs.background.style.height = win_height;
    }
}

Widget.Lightbox.prototype.applyHandlers = function(){
    if(!this.div)
        return;

    var self = this;

    if ( this.config.clickBackgroundToHide == true ) {
        DOM.Events.addListener(this.divs.background, "click", function () {
            self.hide();
        });
    }
    if (Widget.Lightbox.is_ie) {
        DOM.Events.addListener(window, "resize", function () {
            self.applyStyle();
        });
    }
}

Widget.Lightbox.prototype.effects = function() {
    if ( arguments.length > 0 ) {
        this._effects = [];
        for (var i=0; i<arguments.length; i++) {
            this._effects.push(arguments[i]);
        }
    }
    return this._effects;
}

Widget.Lightbox.prototype.applyEffects = function() {
    if (!this._effects)
        return;
    for (var i=0;i<this._effects.length;i++) {
        this.applyEffect(this._effects[i]);
    }
}

Widget.Lightbox.prototype.applyEffect = function(effect) {
    var func_name = "applyEffect" + effect;
    if ( typeof this[func_name] == 'function') {
        this[func_name]();
    }
}

// Require Effect.RoundedCorners
Widget.Lightbox.prototype.applyEffectRoundedCorners = function() {
    divs = this.divs
    if ( ! divs ) { return; }
    if ( typeof Effect.RoundedCorners == 'undefined' ) { return; }
    divs.contentWrapper.style.border="none";
    var bs = divs.contentWrapper.getElementsByTagName("b");
    for (var i = 0; i < bs.length; i++) {
        if(bs[i].className.match(/rounded-corners-/)) {
            return;
        }
    }
    for (var i=1; i< 5; i++) {
        Effect.RoundedCorners._Styles.push(
            [ ".rounded-corners-" + i,
              "opacity: 0.4",
              "filter: alpha(opacity=40)"
             ]
        );
    }

    Effect.RoundedCorners._addStyles();
    Effect.RoundedCorners._roundCorners(
        divs.contentWrapper,
        {   'top': true,
            'bottom':true,
            'color':'black'
            }
        );
}

// A Generator function for scriptaculous effects.
;(function () {
    var effects = ['Appear', 'Grow', 'BlindDown', 'Shake'];
    for (var i=0; i<effects.length; i++) {
        var name = "applyEffect" + effects[i];
        Widget.Lightbox.prototype[name] = function(effect) {
            return function() {
                if ( ! this.divs ) { return; }
                if ( typeof Effect[effect] == 'undefined' ) { return; }
                if (effect != 'Shake')
                    this.divs.contentWrapper.style.display="none";
                Effect[effect](this.divs.contentWrapper, { duration: 2.0 });
            }
        }(effects[i]);
    }
})();



/**

*/
// BEGIN ../../../js-modules/Widget-Lightbox/tests/lib/Effect/RoundedCorners.js
JSAN.use("DOM.Ready");

if ( typeof Effect == "undefined" ) Effect = {};

Effect.RoundedCorners = {};

Effect.RoundedCorners.VERSION = "0.12";

Effect.RoundedCorners.roundCorners = function (params) {
    if ( typeof params == "string" ) {
        params = { "elementId": params };
    }

    if ( ! params["elementId"] ) {
        throw new Error("Effect.RoundedCorners requires an elementId parameter");
    }

    Effect.RoundedCorners._addStyles();

    if ( ! params.hasOwnProperty("top") ) {
        params["top"] = true;
    }

    if ( ! params.hasOwnProperty("bottom") ) {
        params["bottom"] = true;
    }

    var callback = function () {
        var elt = document.getElementById( params.elementId );
        if ( ! elt ) { return }
        Effect.RoundedCorners._roundCorners( elt, params );
    };
    DOM.Ready.onDOMDone(callback);
}

Effect.RoundedCorners._roundCorners = function (elt, params) {
    var color = params["color"];
    if ( ! color ) {
        var current_elt = elt.parentNode;
        while ( current_elt && ( ! color || color == "transparent" ) ) {
            try {
                color = window.getComputedStyle( current_elt, null ).backgroundColor;
            }
            /* at least on Firefox calling getComputedStyle on the
             * root HTML node seems to produce an error */
            catch (e) {}
            current_elt = current_elt.parentNode;
        }

        if ( color == undefined || color == "transparent" ) {
            color = "white";
        }
    }

    if ( params["top"] ) {
        Effect.RoundedCorners._roundUpperCorners( elt, color );
    }

    if ( params["bottom"] ) {
        Effect.RoundedCorners._roundBottomCorners( elt, color );
    }

}

Effect.RoundedCorners._roundUpperCorners = function (elt, color) {
    var container =
       Effect.RoundedCorners._makeElements( color, [ "1", "2", "3", "4" ] );

    elt.insertBefore( container, elt.firstChild );
}

Effect.RoundedCorners._roundBottomCorners = function (elt, color) {
    var container =
       Effect.RoundedCorners._makeElements( color, [ "4", "3", "2", "1" ] );

    elt.appendChild(container);
}

var foo = 1;
Effect.RoundedCorners._makeElements = function (color, order) {
    var container = document.createElement("b");
    container.className = "rounded-corners-container";

    while ( order.length ) {
        var b_tag = document.createElement("b");
        b_tag.className = "rounded-corners-" + order.shift();
        b_tag.style.backgroundColor = "transparent";
        b_tag.style.borderColor = color;

        container.appendChild(b_tag);
    }

    return container;
}

Effect.RoundedCorners._Styles = [
    [ ".rounded-corners-container",
      "display: block",
      "background-color: transparent" ],

    [ ".rounded-corners-container *",
      "display: block",
      "height: 1px",
      "overflow: hidden",
      "font-size: 1px",
      "border-style: solid",
      "border-width: 0px 1px"
    ],

    [ ".rounded-corners-1",
      "border-left-width: 5px",
      "border-right-width: 5px"
    ],

    [ ".rounded-corners-2",
      "border-left-width: 3px",
      "border-right-width: 3px"
    ],

    [ ".rounded-corners-3",
      "border-left-width: 2px",
      "border-right-width: 2px"
    ],

    [ ".rounded-corners-4",
      "height: 2px"
    ]
];

Effect.RoundedCorners._StylesAdded = 0;
Effect.RoundedCorners._addStyles = function () {
    if (Effect.RoundedCorners._StylesAdded) {
        return;
    }

    var styles = Effect.RoundedCorners._Styles;
    var style_string = "";

    for ( var i = 0; i < styles.length; i++ ) {
        var style = styles[i];

        style_string =
            style_string
            + style.shift()
            + " {\n  "
            + style.join(";\n  ")
            + ";\n}\n\n";
    }

    var style_elt = document.createElement("style");
    style_elt.setAttribute("type", "text/css");

    if ( style_elt.styleSheet ) { /* IE */
        style_elt.styleSheet.cssText = style_string;
    }
    else { /* w3c */
        var style_text = document.createTextNode(style_string);
        style_elt.appendChild(style_text);
    }

    var head = document.getElementsByTagName("head")[0];
    head.appendChild(style_elt);
    
    Effect.RoundedCorners._StylesAdded = 1;
}

/*

*/
// BEGIN hacks.js

/* 
COPYRIGHT NOTICE:
    Copyright (c) 2004-2005 Socialtext Corporation 
    235 Churchill Ave 
    Palo Alto, CA 94301 U.S.A.
    All rights reserved.
*/

/*
 * A collection of external code overrides.
 * /

/* prototype does not deal with the broken handling of HTTP 204 done by
   IE 6.x. transport.status is seen as 1223 rather than 204 as expected.
 */

Ajax.Base.prototype.responseIsSuccess = function() {
    return this.transport.status == undefined
        || this.transport.status == 0
        || this.transport.status == 1223 /* we love you IE! */
        || (this.transport.status >= 200 && this.transport.status < 300);
}
// BEGIN md5.js
/**
*
*  MD5 (Message-Digest Algorithm)
*  http://www.webtoolkit.info/
*
**/

var MD5 = function (string) {

    function RotateLeft(lValue, iShiftBits) {
        return (lValue<<iShiftBits) | (lValue>>>(32-iShiftBits));
    }

    function AddUnsigned(lX,lY) {
        var lX4,lY4,lX8,lY8,lResult;
        lX8 = (lX & 0x80000000);
        lY8 = (lY & 0x80000000);
        lX4 = (lX & 0x40000000);
        lY4 = (lY & 0x40000000);
        lResult = (lX & 0x3FFFFFFF)+(lY & 0x3FFFFFFF);
        if (lX4 & lY4) {
            return (lResult ^ 0x80000000 ^ lX8 ^ lY8);
        }
        if (lX4 | lY4) {
            if (lResult & 0x40000000) {
                return (lResult ^ 0xC0000000 ^ lX8 ^ lY8);
            } else {
                return (lResult ^ 0x40000000 ^ lX8 ^ lY8);
            }
        } else {
            return (lResult ^ lX8 ^ lY8);
        }
    }

    function F(x,y,z) { return (x & y) | ((~x) & z); }
    function G(x,y,z) { return (x & z) | (y & (~z)); }
    function H(x,y,z) { return (x ^ y ^ z); }
    function I(x,y,z) { return (y ^ (x | (~z))); }

    function FF(a,b,c,d,x,s,ac) {
        a = AddUnsigned(a, AddUnsigned(AddUnsigned(F(b, c, d), x), ac));
        return AddUnsigned(RotateLeft(a, s), b);
    };

    function GG(a,b,c,d,x,s,ac) {
        a = AddUnsigned(a, AddUnsigned(AddUnsigned(G(b, c, d), x), ac));
        return AddUnsigned(RotateLeft(a, s), b);
    };

    function HH(a,b,c,d,x,s,ac) {
        a = AddUnsigned(a, AddUnsigned(AddUnsigned(H(b, c, d), x), ac));
        return AddUnsigned(RotateLeft(a, s), b);
    };

    function II(a,b,c,d,x,s,ac) {
        a = AddUnsigned(a, AddUnsigned(AddUnsigned(I(b, c, d), x), ac));
        return AddUnsigned(RotateLeft(a, s), b);
    };

    function ConvertToWordArray(string) {
        var lWordCount;
        var lMessageLength = string.length;
        var lNumberOfWords_temp1=lMessageLength + 8;
        var lNumberOfWords_temp2=(lNumberOfWords_temp1-(lNumberOfWords_temp1 % 64))/64;
        var lNumberOfWords = (lNumberOfWords_temp2+1)*16;
        var lWordArray=Array(lNumberOfWords-1);
        var lBytePosition = 0;
        var lByteCount = 0;
        while ( lByteCount < lMessageLength ) {
            lWordCount = (lByteCount-(lByteCount % 4))/4;
            lBytePosition = (lByteCount % 4)*8;
            lWordArray[lWordCount] = (lWordArray[lWordCount] | (string.charCodeAt(lByteCount)<<lBytePosition));
            lByteCount++;
        }
        lWordCount = (lByteCount-(lByteCount % 4))/4;
        lBytePosition = (lByteCount % 4)*8;
        lWordArray[lWordCount] = lWordArray[lWordCount] | (0x80<<lBytePosition);
        lWordArray[lNumberOfWords-2] = lMessageLength<<3;
        lWordArray[lNumberOfWords-1] = lMessageLength>>>29;
        return lWordArray;
    };

    function WordToHex(lValue) {
        var WordToHexValue="",WordToHexValue_temp="",lByte,lCount;
        for (lCount = 0;lCount<=3;lCount++) {
            lByte = (lValue>>>(lCount*8)) & 255;
            WordToHexValue_temp = "0" + lByte.toString(16);
            WordToHexValue = WordToHexValue + WordToHexValue_temp.substr(WordToHexValue_temp.length-2,2);
        }
        return WordToHexValue;
    };

    function Utf8Encode(string) {
        string = string.replace(/\r\n/g,"\n");
        var utftext = "";

        for (var n = 0; n < string.length; n++) {

            var c = string.charCodeAt(n);

            if (c < 128) {
                utftext += String.fromCharCode(c);
            }
            else if((c > 127) && (c < 2048)) {
                utftext += String.fromCharCode((c >> 6) | 192);
                utftext += String.fromCharCode((c & 63) | 128);
            }
            else {
                utftext += String.fromCharCode((c >> 12) | 224);
                utftext += String.fromCharCode(((c >> 6) & 63) | 128);
                utftext += String.fromCharCode((c & 63) | 128);
            }

        }

        return utftext;
    };

    var x=Array();
    var k,AA,BB,CC,DD,a,b,c,d;
    var S11=7, S12=12, S13=17, S14=22;
    var S21=5, S22=9 , S23=14, S24=20;
    var S31=4, S32=11, S33=16, S34=23;
    var S41=6, S42=10, S43=15, S44=21;

    string = Utf8Encode(string);

    x = ConvertToWordArray(string);

    a = 0x67452301; b = 0xEFCDAB89; c = 0x98BADCFE; d = 0x10325476;

    for (k=0;k<x.length;k+=16) {
        AA=a; BB=b; CC=c; DD=d;
        a=FF(a,b,c,d,x[k+0], S11,0xD76AA478);
        d=FF(d,a,b,c,x[k+1], S12,0xE8C7B756);
        c=FF(c,d,a,b,x[k+2], S13,0x242070DB);
        b=FF(b,c,d,a,x[k+3], S14,0xC1BDCEEE);
        a=FF(a,b,c,d,x[k+4], S11,0xF57C0FAF);
        d=FF(d,a,b,c,x[k+5], S12,0x4787C62A);
        c=FF(c,d,a,b,x[k+6], S13,0xA8304613);
        b=FF(b,c,d,a,x[k+7], S14,0xFD469501);
        a=FF(a,b,c,d,x[k+8], S11,0x698098D8);
        d=FF(d,a,b,c,x[k+9], S12,0x8B44F7AF);
        c=FF(c,d,a,b,x[k+10],S13,0xFFFF5BB1);
        b=FF(b,c,d,a,x[k+11],S14,0x895CD7BE);
        a=FF(a,b,c,d,x[k+12],S11,0x6B901122);
        d=FF(d,a,b,c,x[k+13],S12,0xFD987193);
        c=FF(c,d,a,b,x[k+14],S13,0xA679438E);
        b=FF(b,c,d,a,x[k+15],S14,0x49B40821);
        a=GG(a,b,c,d,x[k+1], S21,0xF61E2562);
        d=GG(d,a,b,c,x[k+6], S22,0xC040B340);
        c=GG(c,d,a,b,x[k+11],S23,0x265E5A51);
        b=GG(b,c,d,a,x[k+0], S24,0xE9B6C7AA);
        a=GG(a,b,c,d,x[k+5], S21,0xD62F105D);
        d=GG(d,a,b,c,x[k+10],S22,0x2441453);
        c=GG(c,d,a,b,x[k+15],S23,0xD8A1E681);
        b=GG(b,c,d,a,x[k+4], S24,0xE7D3FBC8);
        a=GG(a,b,c,d,x[k+9], S21,0x21E1CDE6);
        d=GG(d,a,b,c,x[k+14],S22,0xC33707D6);
        c=GG(c,d,a,b,x[k+3], S23,0xF4D50D87);
        b=GG(b,c,d,a,x[k+8], S24,0x455A14ED);
        a=GG(a,b,c,d,x[k+13],S21,0xA9E3E905);
        d=GG(d,a,b,c,x[k+2], S22,0xFCEFA3F8);
        c=GG(c,d,a,b,x[k+7], S23,0x676F02D9);
        b=GG(b,c,d,a,x[k+12],S24,0x8D2A4C8A);
        a=HH(a,b,c,d,x[k+5], S31,0xFFFA3942);
        d=HH(d,a,b,c,x[k+8], S32,0x8771F681);
        c=HH(c,d,a,b,x[k+11],S33,0x6D9D6122);
        b=HH(b,c,d,a,x[k+14],S34,0xFDE5380C);
        a=HH(a,b,c,d,x[k+1], S31,0xA4BEEA44);
        d=HH(d,a,b,c,x[k+4], S32,0x4BDECFA9);
        c=HH(c,d,a,b,x[k+7], S33,0xF6BB4B60);
        b=HH(b,c,d,a,x[k+10],S34,0xBEBFBC70);
        a=HH(a,b,c,d,x[k+13],S31,0x289B7EC6);
        d=HH(d,a,b,c,x[k+0], S32,0xEAA127FA);
        c=HH(c,d,a,b,x[k+3], S33,0xD4EF3085);
        b=HH(b,c,d,a,x[k+6], S34,0x4881D05);
        a=HH(a,b,c,d,x[k+9], S31,0xD9D4D039);
        d=HH(d,a,b,c,x[k+12],S32,0xE6DB99E5);
        c=HH(c,d,a,b,x[k+15],S33,0x1FA27CF8);
        b=HH(b,c,d,a,x[k+2], S34,0xC4AC5665);
        a=II(a,b,c,d,x[k+0], S41,0xF4292244);
        d=II(d,a,b,c,x[k+7], S42,0x432AFF97);
        c=II(c,d,a,b,x[k+14],S43,0xAB9423A7);
        b=II(b,c,d,a,x[k+5], S44,0xFC93A039);
        a=II(a,b,c,d,x[k+12],S41,0x655B59C3);
        d=II(d,a,b,c,x[k+3], S42,0x8F0CCC92);
        c=II(c,d,a,b,x[k+10],S43,0xFFEFF47D);
        b=II(b,c,d,a,x[k+1], S44,0x85845DD1);
        a=II(a,b,c,d,x[k+8], S41,0x6FA87E4F);
        d=II(d,a,b,c,x[k+15],S42,0xFE2CE6E0);
        c=II(c,d,a,b,x[k+6], S43,0xA3014314);
        b=II(b,c,d,a,x[k+13],S44,0x4E0811A1);
        a=II(a,b,c,d,x[k+4], S41,0xF7537E82);
        d=II(d,a,b,c,x[k+11],S42,0xBD3AF235);
        c=II(c,d,a,b,x[k+2], S43,0x2AD7D2BB);
        b=II(b,c,d,a,x[k+9], S44,0xEB86D391);
        a=AddUnsigned(a,AA);
        b=AddUnsigned(b,BB);
        c=AddUnsigned(c,CC);
        d=AddUnsigned(d,DD);
    }

    var temp = WordToHex(a)+WordToHex(b)+WordToHex(c)+WordToHex(d);

    return temp.toLowerCase();
}
// BEGIN Cookie.js
// Cookie handling functions

Cookie = {};

Cookie.get = function(name) {
    var cookieStart = document.cookie.indexOf(name + "=");
    if (cookieStart == -1) return null;
    var valueStart = document.cookie.indexOf('=', cookieStart) + 1;
    var valueEnd = document.cookie.indexOf(';', valueStart);
    if (valueEnd == -1) valueEnd = document.cookie.length;
    var val = document.cookie.substring(valueStart, valueEnd);
    return val == null
        ? null
        : unescape(document.cookie.substring(valueStart, valueEnd));
}

Cookie.set = function(name, val, expiration) {
    // Default to 25 year expiry if not specified by the caller.
    if (typeof(expiration) == 'undefined') {
        expiration = new Date(
            new Date().getTime() + 25 * 365 * 24 * 60 * 60 * 1000
        )
    }
    var str = name + '=' + escape(val) +
        '; expires=' + expiration.toGMTString();
    document.cookie = str;
}

Cookie['delete'] = function(name) {
    Cookie.set(name, '', new Date(new Date().getTime() - 1));
}

// BEGIN ArrayUtils.js
/*
  Extensions to the JavaScript Array object.
  Author: Sean M. Burke
  Codeblt'd from: http://interglacial.com/hoj/hoj.html

  map, grep, and foreach are added to the Array object

  Examples:

    Get a copy of words with every item uppercase:
        var loudwords = words.map( function(_){ return _.toUpperCase(); } );

    Find all the uppercased words in words:
        function isUpperCase (_) { return _ == _.toUpperCase(); }
        var already_loud = words.grep( isUpperCase);

    Change words in-place:
        words.foreach( function(item, arr, i){arr[i] = item.toUpperCase();} );
*/

Array.prototype.map = function(f) {
    if(!f.apply) {
        var propname = f;
        f = function(_) {
            return _[propname]
        }
    }

    var out = [];
    for(var i = 0; i < this.length; i++) {
        out.push( f( this[i], this, i) );
    }

    return out;
};

Array.prototype.mapc = function(f) {
    if (!f.apply) {
        var propname = f;
        f = function(_) {
            return _[propname]
        }
    }

    var out = [];
    var gotten;
    for (var i = 0; i < this.length; i++) {
        gotten = f( this[i], this, i);
        if ( gotten != undefined )
            out = out.concat( gotten );
    }
    return out;
};


Array.prototype.grep = function(f) {
    if (!f.apply) {
        var propname = f;
        f = function(_) {
            return _[propname]
        }
    }
    var out = [];
    for(var i = 0; i < this.length; i++) {
        if ( f( this[i], this, i) )
            out.push(this[i]);
    }
    return out;
};

Array.prototype.foreach = function(f) {
    if(!f.apply) {
        var propname = f;
        f = function(_,x,i) { x[i] = _[propname] }
    }

    for(var i = 0; i < this.length; i++) {
        f( this[i], this, i );
    }

    return;
};

Array.prototype.deleteElement = function(toDelete) {
    var i;
    for (i=0; i < this.length; i++)
        if (this[i] == toDelete) {
            this.splice(i,1);
            return;
        }
}

Array.prototype.deleteElementIgnoreCase = function(toDelete) {
    var i;
    var lcToDelete = toDelete.toLowerCase();
    for (i=0; i < this.length; i++)
        if (this[i].toLowerCase() == lcToDelete) {
            this.splice(i,1);
            return;
        }
}// BEGIN stlibrary.js
// namespace placeholder
if (typeof ST == 'undefined') {
    ST = {};
}

ST.isRelative = function(node) {
    return node.style.position == 'relative' || node.style.position == 'absolute' || node.style.position == 'fixed';
}

ST.getRadioValue = function(name) {
    var nodes = document.getElementsByName(name);
    for (var i=0; i < nodes.length; i++)
        if (nodes[i].checked)
            return nodes[i].value;
    return '';
}

ST.setRadioValue = function(name, value) {
    var nodes = document.getElementsByName(name);
    for (var i=0; i < nodes.length; i++) {
        if (nodes[i].value == value) {
            nodes[i].checked = true;
            return;
        }
    }
}

// Function from Javascript: The Definitive Guide
ST.getDocumentX = function(e, is_relative) {
    var x = 0;
    while (e) {
        x+= e.offsetLeft;
        e = e.offsetParent;
        if (e && is_relative && ST.isRelative(e))
            e = null;
    }
    return x;
}

ST.getDocumentY = function(e, is_relative) {
    var y = 0;
    while (e) {
        y += e.offsetTop;
        e = e.offsetParent;
        if (e && is_relative && ST.isRelative(e))
            e = null;
    }
    return y;
}

/**
 * A function used to extend one class with another
 *
 * @author Kevin Lindsey
 * @version 1.0
 *
 * copyright 2006, Kevin Lindsey
 *
 *
 * @param {Object} subClass
 * 		The inheriting class, or subclass
 * @param {Object} baseClass
 * 		The class from which to inherit
 */
ST.extend = function(subClass, baseClass) {
   function inheritance() {}
   inheritance.prototype = baseClass.prototype;

   subClass.prototype = new inheritance();
   subClass.prototype.constructor = subClass;
   subClass.baseConstructor = baseClass;
   subClass.superClass = baseClass.prototype;
}


// Pop up a new HTML window
function query_popup(url, width, height, left, top) {
    if (!width) width = 400;
    if (!height) height = 275;
    if (!left) left = 400-width/2;
    if (!top) top = 280-height/2;
    window.open(url, '_blank', 'toolbar=no, location=no, directories=no, status=no, menubar=no, titlebar=no, scrollbars=yes, resizable=yes, width=' + width + ', height=' + height + ', left=' + left + ', top=' + top);
}

function help_popup(url, width, height, left, top) {
    if (!width) width = 520;
    if (!height) height = 300;
    if (!left) left = 400-width/2;
    if (!top) top = 280-height/2;
    window.open(url, '_blank', 'toolbar=no, location=no, directories=no, status=no, menubar=no, titlebar=no, scrollbars=yes, resizable=yes, width=' + width + ', height=' + height + ', left=' + left + ', top=' + top);
}

function trim(value) {
    var ltrim = /\s*((\s*\S+)*)/;
    var rtrim = /((\s*\S+)*)\s*/;
    return value.replace(rtrim, "$1").replace(ltrim, "$1");
};

function is_reserved_pagename(pagename) {
    if (pagename && pagename.length > 0) {
        var name = trim(pagename.toLowerCase());
        return name == 'untitled page';
    }
    else {
        return false;
    }
}

function confirm_delete(pageid) {
    if (confirm('Are you sure you want to delete this page?')) {
        location = 'index.cgi?action=delete_page;page_name=' + pageid;
    }
}
// BEGIN Jemplate.js
/*------------------------------------------------------------------------------
Jemplate - Template Toolkit for JavaScript

DESCRIPTION - This module provides the runtime JavaScript support for
compiled Jemplate templates.

AUTHOR - Ingy döt Net <ingy@cpan.org>

Copyright 2006 Ingy döt Net. All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
------------------------------------------------------------------------------*/

//------------------------------------------------------------------------------
// Main Jemplate class
//------------------------------------------------------------------------------

if (typeof Jemplate == 'undefined') {
    Jemplate = function() {
        this.init.apply(this, arguments);
    };
}

if (! Jemplate.templateMap)
    Jemplate.templateMap = {};

Jemplate.process = function() {
    var jemplate = new Jemplate();
    return jemplate.process.apply(jemplate, arguments);
}

proto = Jemplate.prototype;

proto.init = function(config) {
    this.config = config ||
    {
        AUTO_RESET: true,
        BLOCKS: {},
        CONTEXT: null,
        DEBUG_UNDEF: false,
        DEFAULT: null,
        ERROR: null,
        EVAL_JAVASCRIPT: false,
        FILTERS: {},
        INCLUDE_PATH: [''],
        INTERPOLATE: false,
        OUTPUT: null,
        PLUGINS: {},
        POST_PROCESS: [],
        PRE_PROCESS: [],
        PROCESS: null,
        RECURSION: false,
        STASH: null,
        TOLERANT: null,
        VARIABLES: {},
        WRAPPER: []
    };
}

proto.process = function(template, data, output) {
    var context = this.config.CONTEXT || new Jemplate.Context();
    context.config = this.config;

    context.stash = this.config.STASH || new Jemplate.Stash();
    context.stash.__config__ = this.config;

    context.__filter__ = new Jemplate.Filter();
    context.__filter__.config = this.config;

    var result;

    var proc = function(input) {
        try {
            result = context.process(template, input);
        }
        catch(e) {
            if (! String(e).match(/Jemplate\.STOP\n/))
                throw(e);
            result = e.toString().replace(/Jemplate\.STOP\n/, '');
        }

        if (typeof output == 'undefined')
            return result;
        if (typeof output == 'function') {
            output(result);
            return;
        }
        if (typeof(output) == 'string' || output instanceof String) {
            if (output.match(/^#[\w\-]+$/)) {
                var id = output.replace(/^#/, '');
                var element = document.getElementById(id);
                if (typeof element == 'undefined')
                    throw('No element found with id="' + id + '"');
                element.innerHTML = result;
                return;
            }
        }
        else {
            output.innerHTML = result;
            return;
        }

        throw("Invalid arguments in call to Jemplate.process");

        return 1;
    }

    if (typeof data == 'function')
        data = data();
    else if (typeof data == 'string') {
        Ajax.get(data, function(r) { proc(JSON.parse(r)) });
        return;
    }

    return proc(data);
}

//------------------------------------------------------------------------------
// Jemplate.Context class
//------------------------------------------------------------------------------
if (typeof Jemplate.Context == 'undefined')
    Jemplate.Context = function() {};

proto = Jemplate.Context.prototype;

proto.include = function(template, args) {
    return this.process(template, args, true);
}

proto.process = function(template, args, localise) {
    if (localise)
        this.stash.clone(args);
    else
        this.stash.update(args);
    var func = Jemplate.templateMap[template];
    if (typeof func == 'undefined')
        throw('No Jemplate template named "' + template + '" available');
    var output = func(this);
    if (localise)
        this.stash.declone();
    return output;
}

proto.set_error = function(error, output) {
    this._error = [error, output];
    return error;
}

proto.filter = function(text, name, args) {
    if (name == 'null')
        name = "null_filter";
    if (typeof this.__filter__.filters[name] == "function")
        return this.__filter__.filters[name](text, args, this);
    else
        throw "Unknown filter name ':" + name + "'";
}

//------------------------------------------------------------------------------
// Jemplate.Filter class
//------------------------------------------------------------------------------
if (typeof Jemplate.Filter == 'undefined') {
    Jemplate.Filter = function() { };
}

proto = Jemplate.Filter.prototype;

proto.filters = {};

proto.filters.null_filter = function(text) {
    return '';
}

proto.filters.upper = function(text) {
    return text.toUpperCase();
}

proto.filters.lower = function(text) {
    return text.toLowerCase();
}

proto.filters.ucfirst = function(text) {
    var first = text.charAt(0);
    var rest = text.substr(1);
    return first.toUpperCase() + rest;
}

proto.filters.lcfirst = function(text) {
    var first = text.charAt(0);
    var rest = text.substr(1);
    return first.toLowerCase() + rest;
}

proto.filters.trim = function(text) {
    return text.replace( /^\s+/g, "" ).replace( /\s+$/g, "" );
}

proto.filters.collapse = function(text) {
    return text.replace( /^\s+/g, "" ).replace( /\s+$/g, "" ).replace(/\s+/, " ");
}

proto.filters.html = function(text) {
    text = text.replace(/&/g, '&amp;');
    text = text.replace(/</g, '&lt;');
    text = text.replace(/>/g, '&gt;');
    text = text.replace(/"/g, '&quot;'); // " end quote for emacs
    return text;
}

proto.filters.html_para = function(text) {
    var lines = text.split(/(?:\r?\n){2,}/);
    return "<p>\n" + lines.join("\n</p>\n\n<p>\n") + "</p>\n";
}

proto.filters.html_break = function(text) {
    return text.replace(/(\r?\n){2,}/g, "$1<br />$1<br />$1");
}

proto.filters.html_line_break = function(text) {
    return text.replace(/(\r?\n)/g, "$1<br />$1");
}

proto.filters.uri = function(text) {
    return encodeURI(text);
}

proto.filters.indent = function(text, args) {
    var pad = args[0];
    if (! text) return;
    if (typeof pad == 'undefined')
        pad = 4;

    var finalpad = '';
    if (typeof pad == 'number' || String(pad).match(/^\d$/)) {
        for (var i = 0; i < pad; i++) {
            finalpad += ' ';
        }
    } else {
        finalpad = pad;
    }
    var output = text.replace(/^/gm, finalpad);
    return output;
}

proto.filters.truncate = function(text, args) {
    var len = args[0];
    if (! text) return;
    if (! len)
        len = 32;
    // This should probably be <=, but TT just uses <
    if (text.length < len)
        return text;
    var newlen = len - 3;
    return text.substr(0,newlen) + '...';
}

proto.filters.repeat = function(text, iter) {
    if (! text) return;
    if (! iter || iter == 0)
        iter = 1;
    if (iter == 1) return text

    var output = text;
    for (var i = 1; i < iter; i++) {
        output += text;
    }
    return output;
}

proto.filters.replace = function(text, args) {
    if (! text) return;
    var re_search = args[0];
    var text_replace = args[1];
    if (! re_search)
        re_search = '';
    if (! text_replace)
        text_replace = '';
    var re = new RegExp(re_search, 'g');
    return text.replace(re, text_replace);
}

//------------------------------------------------------------------------------
// Jemplate.Stash class
//------------------------------------------------------------------------------
if (typeof Jemplate.Stash == 'undefined') {
    Jemplate.Stash = function() {
        this.data = {};
    };
}

proto = Jemplate.Stash.prototype;

proto.clone = function(args) {
    var data = this.data;
    this.data = {};
    this.update(data);
    this.update(args);
    this.data._PARENT = data;
}

proto.declone = function(args) {
    this.data = this.data._PARENT || this.data;
}

proto.update = function(args) {
    if (typeof args == 'undefined') return;
    for (var key in args) {
        var value = args[key];
        this.set(key, value);
    }
}

proto.get = function(key) {
    var root = this.data;
    if (key instanceof Array) {
        for (var i = 0; i < key.length; i += 2) {
            var args = key.slice(i, i+2);
            args.unshift(root);
            value = this._dotop.apply(this, args);
            if (typeof value == 'undefined')
                break;
            root = value;
        }
    }
    else {
        value = this._dotop(root, key);
    }

    if (typeof value == 'undefined') {
        if (this.__config__.DEBUG_UNDEF)
            throw("undefined value found while using DEGUG_UNDEF");
        value = '';
    }

    return value;
}

proto.set = function(key, value, set_default) {
    if (key instanceof Array) {
        var data = this.get(key[0]) || {};
        key = key[2];
    }
    else {
        data = this.data;
    }
    if (! (set_default && (typeof data[key] != 'undefined')))
        data[key] = value;
}

proto._dotop = function(root, item, args) {
    if (typeof item == 'undefined' ||
        typeof item == 'string' && item.match(/^[\._]/)) {
        return undefined;
    }

    if ((! args) &&
        (typeof root == 'object') &&
        (!(root instanceof Array) || (typeof item == 'number')) &&
        (typeof root[item] != 'undefined')) {
        var value = root[item];
        if (typeof value == 'function')
            value = value();
        return value;
    }

    if (typeof root == 'string' && this.string_functions[item])
        return this.string_functions[item](root, args);
    if (root instanceof Array && this.list_functions[item])
        return this.list_functions[item](root, args);
    if (typeof root == 'object' && this.hash_functions[item])
        return this.hash_functions[item](root, args);
    if (typeof root[item] == 'function')
        return root[item].apply(root, args);

    return undefined;
}

proto.string_functions = {};

// chunk(size)     negative size chunks from end
proto.string_functions.chunk = function(string, args) {
    var size = args[0];
    var list = new Array();
    if (! size)
        size = 1;
    if (size < 0) {
        size = 0 - size;
        for (i = string.length - size; i >= 0; i = i - size)
            list.unshift(string.substr(i, size));
        if (string.length % size)
            list.unshift(string.substr(0, string.length % size));
    }
    else
        for (i = 0; i < string.length; i = i + size)
            list.push(string.substr(i, size));
    return list;
}

// defined         is value defined?
proto.string_functions.defined = function(string) {
    return 1;
}

// hash            treat as single-element hash with key value
proto.string_functions.hash = function(string) {
    return { 'value': string };
}

// length          length of string representation
proto.string_functions.length = function(string) {
    return string.length;
}

// list            treat as single-item list
proto.string_functions.list = function(string) {
    return [ string ];
}

// match(re)       get list of matches
proto.string_functions.match = function(string, args) {
    var regexp = new RegExp(args[0], 'gm');
    var list = string.match(regexp);
    return list;
}

// repeat(n)       repeated n times
proto.string_functions.repeat = function(string, args) {
    var n = args[0] || 1;
    var output = '';
    for (var i = 0; i < n; i++) {
        output += string;
    }
    return output;
}

// replace(re, sub)    replace instances of re with sub
proto.string_functions.replace = function(string, args) {
    var regexp = new RegExp(args[0], 'gm');
    var sub = args[1];
    if (! sub)
        sub  = '';
    var output = string.replace(regexp, sub);
    return output;
}

// search(re)      true if value matches re
proto.string_functions.search = function(string, args) {
    var regexp = new RegExp(args[0]);
    return (string.search(regexp) >= 0) ? 1 : 0;
}

// size            returns 1, as if a single-item list
proto.string_functions.size = function(string) {
    return 1;
}

// split(re)       split string on re
proto.string_functions.split = function(string, args) {
    var regexp = new RegExp(args[0]);
    var list = string.split(regexp);
    return list;
}



proto.list_functions = {};

proto.list_functions.join = function(list, args) {
    return list.join(args[0]);
};

proto.list_functions.sort = function(list,key) {
    if( typeof(key) != 'undefined' && key != "" ) {
        // we probably have a list of hashes
        // and need to sort based on hash key
        return list.sort(
            function(a,b) {
                if( a[key] == b[key] ) {
                    return 0;
                }
                else if( a[key] > b[key] ) {
                    return 1;
                }
                else {
                    return -1;
                }
            }
        );
    }
    return list.sort();
}

proto.list_functions.nsort = function(list) {
    return list.sort(function(a, b) { return (a-b) });
}

proto.list_functions.grep = function(list, args) {
    var regexp = new RegExp(args[0]);
    var result = [];
    for (var i = 0; i < list.length; i++) {
        if (list[i].match(regexp))
            result.push(list[i]);
    }
    return result;
}

proto.list_functions.unique = function(list) {
    var result = [];
    var seen = {};
    for (var i = 0; i < list.length; i++) {
        var elem = list[i];
        if (! seen[elem])
            result.push(elem);
        seen[elem] = true;
    }
    return result;
}

proto.list_functions.reverse = function(list) {
    var result = [];
    for (var i = list.length - 1; i >= 0; i--) {
        result.push(list[i]);
    }
    return result;
}

proto.list_functions.merge = function(list, args) {
    var result = [];
    var push_all = function(elem) {
        if (elem instanceof Array) {
            for (var j = 0; j < elem.length; j++) {
                result.push(elem[j]);
            }
        }
        else {
            result.push(elem);
        }
    }
    push_all(list);
    for (var i = 0; i < args.length; i++) {
        push_all(args[i]);
    }
    return result;
}

proto.list_functions.slice = function(list, args) {
    return list.slice(args[0], args[1]);
}

proto.list_functions.splice = function(list, args) {
    if (args.length == 1)
        return list.splice(args[0]);
    if (args.length == 2)
        return list.splice(args[0], args[1]);
    if (args.length == 3)
        return list.splice(args[0], args[1], args[2]);
}

proto.list_functions.push = function(list, args) {
    list.push(args[0]);
    return list;
}

proto.list_functions.pop = function(list) {
    return list.pop();
}

proto.list_functions.unshift = function(list, args) {
    list.unshift(args[0]);
    return list;
}

proto.list_functions.shift = function(list) {
    return list.shift();
}

proto.list_functions.first = function(list) {
    return list[0];
}

proto.list_functions.size = function(list) {
    return list.length;
}

proto.list_functions.max = function(list) {
    return list.length - 1;
}

proto.list_functions.last = function(list) {
    return list.slice(-1);
}

proto.hash_functions = {};


// each            list of alternating keys/values
proto.hash_functions.each = function(hash) {
    var list = new Array();
    for ( var key in hash )
        list.push(key, hash[key]);
    return list;
}

// exists(key)     does key exist?
proto.hash_functions.exists = function(hash, args) {
    return ( typeof( hash[args[0]] ) == "undefined" ) ? 0 : 1;
}

// FIXME proto.hash_functions.import blows everything up
//
// import(hash2)   import contents of hash2
// import          import into current namespace hash
//proto.hash_functions.import = function(hash, args) {
//    var hash2 = args[0];
//    for ( var key in hash2 )
//        hash[key] = hash2[key];
//    return '';
//}

// keys            list of keys
proto.hash_functions.keys = function(hash) {
    var list = new Array();
    for ( var key in hash )
        list.push(key);
    return list;
}

// list            returns alternating key, value
proto.hash_functions.list = function(hash, args) {
    var what = '';
    if ( args )
        var what = args[0];

    var list = new Array();
    if (what == 'keys')
        for ( var key in hash )
            list.push(key);
    else if (what == 'values')
        for ( var key in hash )
            list.push(hash[key]);
    else if (what == 'each')
        for ( var key in hash )
            list.push(key, hash[key]);
    else
        for ( var key in hash )
            list.push({ 'key': key, 'value': hash[key] });

    return list;
}

// nsort           keys sorted numerically
proto.hash_functions.nsort = function(hash) {
    var list = new Array();
    for (var key in hash)
        list.push(key);
    return list.sort(function(a, b) { return (a-b) });
}

// size            number of pairs
proto.hash_functions.size = function(hash) {
    var size = 0;
    for (var key in hash)
        size++;
    return size;
}


// sort            keys sorted alphabetically
proto.hash_functions.sort = function(hash) {
    var list = new Array();
    for (var key in hash)
        list.push(key);
    return list.sort();
}

// values          list of values
proto.hash_functions.values = function(hash) {
    var list = new Array();
    for ( var key in hash )
        list.push(hash[key]);
    return list;
}



//------------------------------------------------------------------------------
// Jemplate.Iterator class
//------------------------------------------------------------------------------
if (typeof Jemplate.Iterator == 'undefined') {
    Jemplate.Iterator = function(object) {
        if( object instanceof Array ) {
            this.object = object;
            this.size = object.length;
            this.max  = this.size -1;
        }
        else if ( object instanceof Object ) {
            this.object = object;
            var object_keys = new Array;
            for( var key in object ) {
                object_keys[object_keys.length] = key;
            }
            this.object_keys = object_keys.sort();
            this.size = object_keys.length;
            this.max  = this.size -1;
        }
    }
}

proto = Jemplate.Iterator.prototype;

proto.get_first = function() {
    this.index = 0;
    this.first = 1;
    this.last  = 0;
    this.count = 1;
    return this.get_next(1);
}

proto.get_next = function(should_init) {
    var object = this.object;
    var index;
    if( typeof(should_init) != 'undefined' && should_init ) {
        index = this.index;
    } else {
        index = ++this.index;
        this.first = 0;
        this.count = this.index + 1;
        if( this.index == this.size -1 ) {
            this.last = 1;
        }
    }
    if (typeof object == 'undefined')
        throw('No object to iterate');
    if( this.object_keys ) {
        if (index < this.object_keys.length) {
            this.prev = index > 0 ? this.object_keys[index - 1] : "";
            this.next = index < this.max ? this.object_keys[index + 1] : "";
            return [this.object_keys[index], false];
        }
    } else {
        if (index < object.length) {
            this.prev = index > 0 ? object[index - 1] : "";
            this.next = index < this.max ? object[index +1] : "";
            return [object[index], false];
        }
    }
    return [null, true];
}

//------------------------------------------------------------------------------
// Debugging Support
//------------------------------------------------------------------------------

function XXX(msg) {
    if (! confirm(msg))
        throw("terminated...");
    return msg;
}

function JJJ(obj) {
    return XXX(JSON.stringify(obj));
}

//------------------------------------------------------------------------------
// Ajax support
//------------------------------------------------------------------------------
if (! this.Ajax) Ajax = {};

Ajax.get = function(url, callback) {
    var req = new XMLHttpRequest();
    req.open('GET', url, Boolean(callback));
    return Ajax._send(req, null, callback);
}

Ajax.post = function(url, data, callback) {
    var req = new XMLHttpRequest();
    req.open('POST', url, Boolean(callback));
    req.setRequestHeader(
        'Content-Type',
        'application/x-www-form-urlencoded'
    );
    return Ajax._send(req, data, callback);
}

Ajax._send = function(req, data, callback) {
    if (callback) {
        req.onreadystatechange = function() {
            if (req.readyState == 4) {
                if(req.status == 200)
                    callback(req.responseText);
            }
        };
    }
    req.send(data);
    if (!callback) {
        if (req.status != 200)
            throw('Request for "' + url +
                  '" failed with status: ' + req.status);
        return req.responseText;
    }
}

//------------------------------------------------------------------------------
// Cross-Browser XMLHttpRequest v1.1
//------------------------------------------------------------------------------
/*
Emulate Gecko 'XMLHttpRequest()' functionality in IE and Opera. Opera requires
the Sun Java Runtime Environment <http://www.java.com/>.

by Andrew Gregory
http://www.scss.com.au/family/andrew/webdesign/xmlhttprequest/

This work is licensed under the Creative Commons Attribution License. To view a
copy of this license, visit http://creativecommons.org/licenses/by/1.0/ or send
a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305,
USA.
*/

// IE support
if (window.ActiveXObject && !window.XMLHttpRequest) {
  window.XMLHttpRequest = function() {
    return new ActiveXObject((navigator.userAgent.toLowerCase().indexOf('msie 5') != -1) ? 'Microsoft.XMLHTTP' : 'Msxml2.XMLHTTP');
  };
}

// Opera support
if (window.opera && !window.XMLHttpRequest) {
  window.XMLHttpRequest = function() {
    this.readyState = 0; // 0=uninitialized,1=loading,2=loaded,3=interactive,4=complete
    this.status = 0; // HTTP status codes
    this.statusText = '';
    this._headers = [];
    this._aborted = false;
    this._async = true;
    this.abort = function() {
      this._aborted = true;
    };
    this.getAllResponseHeaders = function() {
      return this.getAllResponseHeader('*');
    };
    this.getAllResponseHeader = function(header) {
      var ret = '';
      for (var i = 0; i < this._headers.length; i++) {
        if (header == '*' || this._headers[i].h == header) {
          ret += this._headers[i].h + ': ' + this._headers[i].v + '\n';
        }
      }
      return ret;
    };
    this.setRequestHeader = function(header, value) {
      this._headers[this._headers.length] = {h:header, v:value};
    };
    this.open = function(method, url, async, user, password) {
      this.method = method;
      this.url = url;
      this._async = true;
      this._aborted = false;
      if (arguments.length >= 3) {
        this._async = async;
      }
      if (arguments.length > 3) {
        // user/password support requires a custom Authenticator class
        opera.postError('XMLHttpRequest.open() - user/password not supported');
      }
      this._headers = [];
      this.readyState = 1;
      if (this.onreadystatechange) {
        this.onreadystatechange();
      }
    };
    this.send = function(data) {
      if (!navigator.javaEnabled()) {
        alert("XMLHttpRequest.send() - Java must be installed and enabled.");
        return;
      }
      if (this._async) {
        setTimeout(this._sendasync, 0, this, data);
        // this is not really asynchronous and won't execute until the current
        // execution context ends
      } else {
        this._sendsync(data);
      }
    }
    this._sendasync = function(req, data) {
      if (!req._aborted) {
        req._sendsync(data);
      }
    };
    this._sendsync = function(data) {
      this.readyState = 2;
      if (this.onreadystatechange) {
        this.onreadystatechange();
      }
      // open connection
      var url = new java.net.URL(new java.net.URL(window.location.href), this.url);
      var conn = url.openConnection();
      for (var i = 0; i < this._headers.length; i++) {
        conn.setRequestProperty(this._headers[i].h, this._headers[i].v);
      }
      this._headers = [];
      if (this.method == 'POST') {
        // POST data
        conn.setDoOutput(true);
        var wr = new java.io.OutputStreamWriter(conn.getOutputStream());
        wr.write(data);
        wr.flush();
        wr.close();
      }
      // read response headers
      // NOTE: the getHeaderField() methods always return nulls for me :(
      var gotContentEncoding = false;
      var gotContentLength = false;
      var gotContentType = false;
      var gotDate = false;
      var gotExpiration = false;
      var gotLastModified = false;
      for (var i = 0; ; i++) {
        var hdrName = conn.getHeaderFieldKey(i);
        var hdrValue = conn.getHeaderField(i);
        if (hdrName == null && hdrValue == null) {
          break;
        }
        if (hdrName != null) {
          this._headers[this._headers.length] = {h:hdrName, v:hdrValue};
          switch (hdrName.toLowerCase()) {
            case 'content-encoding': gotContentEncoding = true; break;
            case 'content-length'  : gotContentLength   = true; break;
            case 'content-type'    : gotContentType     = true; break;
            case 'date'            : gotDate            = true; break;
            case 'expires'         : gotExpiration      = true; break;
            case 'last-modified'   : gotLastModified    = true; break;
          }
        }
      }
      // try to fill in any missing header information
      var val;
      val = conn.getContentEncoding();
      if (val != null && !gotContentEncoding) this._headers[this._headers.length] = {h:'Content-encoding', v:val};
      val = conn.getContentLength();
      if (val != -1 && !gotContentLength) this._headers[this._headers.length] = {h:'Content-length', v:val};
      val = conn.getContentType();
      if (val != null && !gotContentType) this._headers[this._headers.length] = {h:'Content-type', v:val};
      val = conn.getDate();
      if (val != 0 && !gotDate) this._headers[this._headers.length] = {h:'Date', v:(new Date(val)).toUTCString()};
      val = conn.getExpiration();
      if (val != 0 && !gotExpiration) this._headers[this._headers.length] = {h:'Expires', v:(new Date(val)).toUTCString()};
      val = conn.getLastModified();
      if (val != 0 && !gotLastModified) this._headers[this._headers.length] = {h:'Last-modified', v:(new Date(val)).toUTCString()};
      // read response data
      var reqdata = '';
      var stream = conn.getInputStream();
      if (stream) {
        var reader = new java.io.BufferedReader(new java.io.InputStreamReader(stream));
        var line;
        while ((line = reader.readLine()) != null) {
          if (this.readyState == 2) {
            this.readyState = 3;
            if (this.onreadystatechange) {
              this.onreadystatechange();
            }
          }
          reqdata += line + '\n';
        }
        reader.close();
        this.status = 200;
        this.statusText = 'OK';
        this.responseText = reqdata;
        this.readyState = 4;
        if (this.onreadystatechange) {
          this.onreadystatechange();
        }
        if (this.onload) {
          this.onload();
        }
      } else {
        // error
        this.status = 404;
        this.statusText = 'Not Found';
        this.responseText = '';
        this.readyState = 4;
        if (this.onreadystatechange) {
          this.onreadystatechange();
        }
        if (this.onerror) {
          this.onerror();
        }
      }
    };
  };
}
// ActiveXObject emulation
if (!window.ActiveXObject && window.XMLHttpRequest) {
  window.ActiveXObject = function(type) {
    switch (type.toLowerCase()) {
      case 'microsoft.xmlhttp':
      case 'msxml2.xmlhttp':
        return new XMLHttpRequest();
    }
    return null;
  };
}


//------------------------------------------------------------------------------
// JSON Support
//------------------------------------------------------------------------------

/*
Copyright (c) 2005 JSON.org
*/
var JSON = function () {
    var m = {
            '\b': '\\b',
            '\t': '\\t',
            '\n': '\\n',
            '\f': '\\f',
            '\r': '\\r',
            '"' : '\\"',
            '\\': '\\\\'
        },
        s = {
            'boolean': function (x) {
                return String(x);
            },
            number: function (x) {
                return isFinite(x) ? String(x) : 'null';
            },
            string: function (x) {
                if (/["\\\x00-\x1f]/.test(x)) {
                    x = x.replace(/([\x00-\x1f\\"])/g, function(a, b) {
                        var c = m[b];
                        if (c) {
                            return c;
                        }
                        c = b.charCodeAt();
                        return '\\u00' +
                            Math.floor(c / 16).toString(16) +
                            (c % 16).toString(16);
                    });
                }
                return '"' + x + '"';
            },
            object: function (x) {
                if (x) {
                    var a = [], b, f, i, l, v;
                    if (x instanceof Array) {
                        a[0] = '[';
                        l = x.length;
                        for (i = 0; i < l; i += 1) {
                            v = x[i];
                            f = s[typeof v];
                            if (f) {
                                v = f(v);
                                if (typeof v == 'string') {
                                    if (b) {
                                        a[a.length] = ',';
                                    }
                                    a[a.length] = v;
                                    b = true;
                                }
                            }
                        }
                        a[a.length] = ']';
                    } else if (x instanceof Object) {
                        a[0] = '{';
                        for (i in x) {
                            v = x[i];
                            f = s[typeof v];
                            if (f) {
                                v = f(v);
                                if (typeof v == 'string') {
                                    if (b) {
                                        a[a.length] = ',';
                                    }
                                    a.push(s.string(i), ':', v);
                                    b = true;
                                }
                            }
                        }
                        a[a.length] = '}';
                    } else {
                        return;
                    }
                    return a.join('');
                }
                return 'null';
            }
        };
    return {
        copyright: '(c)2005 JSON.org',
        license: 'http://www.crockford.com/JSON/license.html',
        stringify: function (v) {
            var f = s[typeof v];
            if (f) {
                v = f(v);
                if (typeof v == 'string') {
                    return v;
                }
            }
            return null;
        },
        parse: function (text) {
            try {
                return !(/[^,:{}\[\]0-9.\-+Eaeflnr-u \n\r\t]/.test(
                        text.replace(/"(\\.|[^"\\])*"/g, ''))) &&
                    eval('(' + text + ')');
            } catch (e) {
                return false;
            }
        }
    };
}();
// BEGIN JSON.js
//------------------------------------------------------------------------------
// JSON Support
//------------------------------------------------------------------------------

/*
Copyright (c) 2005 JSON.org
*/
var JSON = function () {
    var m = {
            '\b': '\\b',
            '\t': '\\t',
            '\n': '\\n',
            '\f': '\\f',
            '\r': '\\r',
            '"' : '\\"',
            '\\': '\\\\'
        },
        s = {
            'boolean': function (x) {
                return String(x);
            },
            number: function (x) {
                return isFinite(x) ? String(x) : 'null';
            },
            string: function (x) {
                if (/["\\\x00-\x1f]/.test(x)) {
                    x = x.replace(/([\x00-\x1f\\"])/g, function(a, b) {
                        var c = m[b];
                        if (c) {
                            return c;
                        }
                        c = b.charCodeAt();
                        return '\\u00' +
                            Math.floor(c / 16).toString(16) +
                            (c % 16).toString(16);
                    });
                }
                return '"' + x + '"';
            },
            object: function (x) {
                if (x) {
                    var a = [], b, f, i, l, v;
                    if (x instanceof Array) {
                        a[0] = '[';
                        l = x.length;
                        for (i = 0; i < l; i += 1) {
                            v = x[i];
                            f = s[typeof v];
                            if (f) {
                                v = f(v);
                                if (typeof v == 'string') {
                                    if (b) {
                                        a[a.length] = ',';
                                    }
                                    a[a.length] = v;
                                    b = true;
                                }
                            }
                        }
                        a[a.length] = ']';
                    } else if (x instanceof Object) {
                        a[0] = '{';
                        for (i in x) {
                            v = x[i];
                            f = s[typeof v];
                            if (f) {
                                v = f(v);
                                if (typeof v == 'string') {
                                    if (b) {
                                        a[a.length] = ',';
                                    }
                                    a.push(s.string(i), ':', v);
                                    b = true;
                                }
                            }
                        }
                        a[a.length] = '}';
                    } else {
                        return;
                    }
                    return a.join('');
                }
                return 'null';
            }
        };
    return {
        copyright: '(c)2005 JSON.org',
        license: 'http://www.crockford.com/JSON/license.html',
        stringify: function (v) {
            var f = s[typeof v];
            if (f) {
                v = f(v);
                if (typeof v == 'string') {
                    return v;
                }
            }
            return null;
        },
        parse: function (text) {
            try {
                if (text.length > 5 * 1024) {
                    return eval('(' + text + ')');
                }
                return !(/[^,:{}\[\]0-9.\-+Eaeflnr-u \n\r\t]/.test(
                        text.replace(/"(\\.|[^"\\])*"/g, ''))) &&
                    eval('(' + text + ')');
            } catch (e) {
                return false;
            }
        }
    };
}();
// BEGIN Wikiwyg/Jemplate.js
/*
   This JavaScript code was generated by Jemplate, the JavaScript
   Template Toolkit. Any changes made to this file will be lost the next
   time the templates are compiled.

   Copyright 2006 - Ingy döt Net - All rights reserved.
*/

if (typeof(Jemplate) == 'undefined')
    throw('Jemplate.js must be loaded before any Jemplate template files');

Jemplate.templateMap['save-cancel.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<div class="st-widget-buttons">\n    <span class="st-widget-savebutton"><input type="submit" value="Save" /></span>\n    <span class="st-widget-cancelbutton"><input type="reset" value="Cancel" /></span>\n</div>\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_aim_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">AIM Link</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Display a link to an AIM screen name. The icon will show whether the person is online. Clicking the link will start an IM conversation with the person if your IM client is properly configured. Use this form to edit the properties of the link.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">AIM screen name:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-aim_id" name="aim_id" value="';
//line 10 "widget_aim_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('aim_id');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="aim_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">There are no optional properties for an AIM link.</p>\n<table class="st-widgets-moreoptionstable">\n\n\n\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="aim_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 34 "widget_aim_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_asap_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">Convoq Link</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Display a link to a Convoq name. Clicking the link will start a Convoq call with the person if your Convoq client is properly configured. Use this form to edit the properties of the Convoq link.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Convoq name:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-asap_id" name="asap_id" value="';
//line 10 "widget_asap_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('asap_id');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="asap_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">There are no optional properties for a Convoq Link.</p>\n<table class="st-widgets-moreoptionstable">\n\n\n\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="asap_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 34 "widget_asap_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_asis_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">Unformatted</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Include unformatted text in the page. This text will not be treated as wiki text. Use this form to edit the text.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Unformatted content:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-asis_content" name="asis_content" value="';
//line 10 "widget_asis_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('asis_content');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="asis_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">There are no optional properties for unformatted text.</p>\n<table class="st-widgets-moreoptionstable">\n\n\n\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="asis_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 34 "widget_asis_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_date_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">Date in Local Time</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Display the given date and time in the individually-set time zone for each reader. Use this form to edit the date and time to be displayed</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">YYYY-MM-DD&nbsp;HH:MM:SS:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-date_string" name="date_string" value="';
//line 10 "widget_date_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('date_string');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="date_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">There are no optional properties for a date display.</p>\n<table class="st-widgets-moreoptionstable">\n\n\n\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="date_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 34 "widget_date_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_fetchatom_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">Inline Atom</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Display the content of an Atom feed. Use this form to edit the properties of the inline Atom feed.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Atom feed URL:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-atom_url" name="atom_url" value="';
//line 10 "widget_fetchatom_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('atom_url');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="fetchatom_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">There are no optional properties for an Atom feed.</p>\n<table class="st-widgets-moreoptionstable">\n\n\n\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="fetchatom_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 34 "widget_fetchatom_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_fetchrss_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">Inline RSS</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Display the content of an RSS feed. Use this form to edit the properties of the inline RSS feed.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">RSS feed URL:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-rss_url" name="rss_url" value="';
//line 10 "widget_fetchrss_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('rss_url');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="fetchrss_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">There are no optional properties for an RSS feed.</p>\n<table class="st-widgets-moreoptionstable">\n\n\n\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="fetchrss_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 34 "widget_fetchrss_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_file_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">Attachment Link</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Display a link to a file attached to a page. Use this form to edit the properities of the link.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Attachment filename:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-file_name" name="file_name" value="';
//line 10 "widget_file_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('file_name');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="file_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">Optional properties include specifying a different page for the attachment, and link text.</p>\n<table class="st-widgets-moreoptionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Page in:</td>\n  <td class="st-widget-dialog-editfield">\n    <p class="st-widget-dialog-defaultradio"><input type="radio" name="st-widget-workspace_id-rb" value="current" checked>the current\nworkspace\n<i>&nbsp;&nbsp;or</i></p>\n<p class="st-widget-dialog-choiceradio">\n  <input type="radio" name="st-widget-workspace_id-rb" value="other">the\n  workspace named&nbsp;\n<input size="25" type="text" id="st-widget-workspace_id" name="workspace_id" value="';
//line 32 "widget_file_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('workspace_id');

    return context.filter(output, 'html', []);
})();

output += '"/>\n</p>\n</td>\n</tr>\n<tr>\n  <td class="st-widget-dialog-editlabel">File attached to:</td>\n  <td class="st-widget-dialog-editfield">\n    <p class="st-widget-dialog-defaultradio"><input type="radio" name="st-widget-page_title-rb" value="current" checked>the current\npage\n<i>&nbsp;&nbsp;or</i></p>\n<p class="st-widget-dialog-choiceradio">\n  <input type="radio" name="st-widget-page_title-rb" value="other">the\n  page titled&nbsp;\n<input size="25" type="text" id="st-widget-page_title" name="page_title" value="';
//line 45 "widget_file_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('page_title');

    return context.filter(output, 'html', []);
})();

output += '"/>\n</p>\n</td>\n</tr>\n<tr>\n  <td class="st-widget-dialog-editlabel">Link text:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-label" name="label" value="';
//line 52 "widget_file_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('label');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n\n\n\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="file_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 66 "widget_file_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_googlesoap_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">Google Search</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Display the results from a Google search. Use this form to edit the properties for the search.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Search for:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-search_term" name="search_term" value="';
//line 10 "widget_googlesoap_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('search_term');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="googlesoap_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">There are no optional properties for an Google search.</p>\n<table class="st-widgets-moreoptionstable">\n\n\n\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="googlesoap_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 34 "widget_googlesoap_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_image_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">Attached Image</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Display an image on this page. The image must be already uploaded as an attachment to this page or another page. Use this form to edit the properties of the displayed image.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Attachment filename:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-image_name" name="image_name" value="';
//line 10 "widget_image_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('image_name');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="image_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">Optional properties include the title of another page to which the image is attached, and link text. If link text is specified then a link to the image is displayed instead of the image.</p>\n<table class="st-widgets-moreoptionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Page in:</td>\n  <td class="st-widget-dialog-editfield">\n    <p class="st-widget-dialog-defaultradio"><input type="radio" name="st-widget-workspace_id-rb" value="current" checked>the current\nworkspace\n<i>&nbsp;&nbsp;or</i></p>\n<p class="st-widget-dialog-choiceradio">\n  <input type="radio" name="st-widget-workspace_id-rb" value="other">the\n  workspace named&nbsp;\n<input size="25" type="text" id="st-widget-workspace_id" name="workspace_id" value="';
//line 32 "widget_image_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('workspace_id');

    return context.filter(output, 'html', []);
})();

output += '"/>\n</p>\n</td>\n</tr>\n<tr>\n  <td class="st-widget-dialog-editlabel">Attached to:</td>\n  <td class="st-widget-dialog-editfield">\n    <p class="st-widget-dialog-defaultradio"><input type="radio" name="st-widget-page_title-rb" value="current" checked>the current\npage\n<i>&nbsp;&nbsp;or</i></p>\n<p class="st-widget-dialog-choiceradio">\n  <input type="radio" name="st-widget-page_title-rb" value="other">the\n  page titled&nbsp;\n<input size="25" type="text" id="st-widget-page_title" name="page_title" value="';
//line 45 "widget_image_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('page_title');

    return context.filter(output, 'html', []);
})();

output += '"/>\n</p>\n</td>\n</tr>\n<tr>\n  <td class="st-widget-dialog-editlabel">Link text:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-label" name="label" value="';
//line 52 "widget_image_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('label');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n\n\n\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="image_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 66 "widget_image_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_include_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">Page Include</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Display the contents of another page within the current page. Use this form to edit the properties for the page include.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Other page in:</td>\n  <td class="st-widget-dialog-editfield">\n    <p class="st-widget-dialog-defaultradio"><input type="radio" name="st-widget-workspace_id-rb" value="current" checked>the current\nworkspace\n<i>&nbsp;&nbsp;or</i></p>\n<p class="st-widget-dialog-choiceradio">\n  <input type="radio" name="st-widget-workspace_id-rb" value="other">the\n  workspace named&nbsp;\n<input size="25" type="text" id="st-widget-workspace_id" name="workspace_id" value="';
//line 16 "widget_include_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('workspace_id');

    return context.filter(output, 'html', []);
})();

output += '"/>\n</p>\n</td>\n</tr>\n<tr>\n  <td class="st-widget-dialog-editlabel">Page title:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-page_title" name="page_title" value="';
//line 23 "widget_include_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('page_title');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="include_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">There are no optional properties for page include.</p>\n<table class="st-widgets-moreoptionstable">\n\n\n\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="include_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 47 "widget_include_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_link1_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">Inter-workspace link</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Use this form to edit the properties of the link.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Other workspace:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-workspace_id" name="workspace_id" value="';
//line 10 "widget_link1_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('workspace_id');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n<tr>\n  <td class="st-widget-dialog-editlabel">Page title:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-page_title" name="page_title" value="';
//line 16 "widget_link1_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('page_title');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="link1_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">Optional properties include the text to display for the link, and a target section within the linked page.</p>\n<table class="st-widgets-moreoptionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Link text:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-label" name="label" value="';
//line 32 "widget_link1_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('label');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n<tr>\n  <td class="st-widget-dialog-editlabel">Section name:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-section_name" name="section_name" value="';
//line 38 "widget_link1_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('section_name');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n\n\n\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="link1_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 52 "widget_link1_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_link2_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">Link to a Section</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Use this form to edit the properties of the link to a page section.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Section name:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-section_name" name="section_name" value="';
//line 10 "widget_link2_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('section_name');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="link2_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">Optional properties include the text to display for the link, and the title of a different page.</p>\n<table class="st-widgets-moreoptionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Link text:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-label" name="label" value="';
//line 26 "widget_link2_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('label');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n<tr>\n  <td class="st-widget-dialog-editlabel">Workspace:</td>\n  <td class="st-widget-dialog-editfield">\n    <p class="st-widget-dialog-defaultradio"><input type="radio" name="st-widget-workspace_id-rb" value="current" checked>the current\nworkspace\n<i>&nbsp;&nbsp;or</i></p>\n<p class="st-widget-dialog-choiceradio">\n  <input type="radio" name="st-widget-workspace_id-rb" value="other">the\n  workspace named&nbsp;\n<input size="25" type="text" id="st-widget-workspace_id" name="workspace_id" value="';
//line 38 "widget_link2_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('workspace_id');

    return context.filter(output, 'html', []);
})();

output += '"/>\n</p>\n</td>\n</tr>\n<tr>\n  <td class="st-widget-dialog-editlabel">Page title:</td>\n  <td class="st-widget-dialog-editfield">\n    <p class="st-widget-dialog-defaultradio"><input type="radio" name="st-widget-page_title-rb" value="current" checked>the current\npage\n<i>&nbsp;&nbsp;or</i></p>\n<p class="st-widget-dialog-choiceradio">\n  <input type="radio" name="st-widget-page_title-rb" value="other">the\n  page titled&nbsp;\n<input size="25" type="text" id="st-widget-page_title" name="page_title" value="';
//line 51 "widget_link2_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('page_title');

    return context.filter(output, 'html', []);
})();

output += '"/>\n</p>\n</td>\n</tr>\n\n\n\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="link2_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 66 "widget_link2_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_new_form_page_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">New Form Page</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Select a form and generates a new form page.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Form name:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-form_name" name="form_name" value="';
//line 10 "widget_new_form_page_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('form_name');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n<tr>\n  <td class="st-widget-dialog-editlabel">Link text:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-form_text" name="form_text" value="';
//line 16 "widget_new_form_page_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('form_text');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="new_form_page_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">There are no optional properties for a new form page.</p>\n<table class="st-widgets-moreoptionstable">\n\n\n\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="new_form_page_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 40 "widget_new_form_page_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_recent_changes_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">What\'s New</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Display a list of pages recently changed in a workspace. By default only the page titles are displayed. Use this form to edit the list properties.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Workspace:</td>\n  <td class="st-widget-dialog-editfield">\n    <p class="st-widget-dialog-defaultradio"><input type="radio" name="st-widget-workspace_id-rb" value="current" checked>the current\nworkspace\n<i>&nbsp;&nbsp;or</i></p>\n<p class="st-widget-dialog-choiceradio">\n  <input type="radio" name="st-widget-workspace_id-rb" value="other">the\n  workspace named&nbsp;\n<input size="25" type="text" id="st-widget-workspace_id" name="workspace_id" value="';
//line 16 "widget_recent_changes_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('workspace_id');

    return context.filter(output, 'html', []);
})();

output += '"/>\n</p>\n</td>\n</tr>\n</table>\n</div>\n<div id="recent_changes_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">Optionally, specify that the page contents should be displayed.</p>\n<table class="st-widgets-moreoptionstable">\n\n\n\n\n<tr>\n<td class="st-widget-dialog-editlabel">\nFull results:\n</td>\n<td class="st-widget-dialog-editfield">\n<input type="checkbox" name="full"';
//line 39 "widget_recent_changes_edit.html"
if (stash.get('full')) {
output += ' checked="checked"';
}

output += ' />\n</td>\n</tr>\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="recent_changes_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 50 "widget_recent_changes_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_search_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">Search Results</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Display the search results for the given phrase within a workspace. Use this form to edit the properties for the search.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Search term:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-search_term" name="search_term" value="';
//line 10 "widget_search_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('search_term');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="search_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">Optional properties include the name of the workspace to search, whether to search in the page title, text or tags, and whether to display full results or just page titles.</p>\n<table class="st-widgets-moreoptionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">In:</td>\n  <td class="st-widget-dialog-editfield">\n    <p class="st-widget-dialog-defaultradio"><input type="radio" name="st-widget-workspace_id-rb" value="current" checked>the current\nworkspace\n<i>&nbsp;&nbsp;or</i></p>\n<p class="st-widget-dialog-choiceradio">\n  <input type="radio" name="st-widget-workspace_id-rb" value="other">the\n  workspace named&nbsp;\n<input size="25" type="text" id="st-widget-workspace_id" name="workspace_id" value="';
//line 32 "widget_search_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('workspace_id');

    return context.filter(output, 'html', []);
})();

output += '"/>\n</p>\n</td>\n</tr>\n\n\n<tr>\n<td class="st-widget-dialog-editlabel">\nSearch type:\n</td>\n<td class="st-widget-dialog-editfield">\n<input type="radio" name="search_type" value="text"\n';
//line 44 "widget_search_edit.html"
if (stash.get('search_type') == 'text' || stash.get('search_type') == '') {
output += 'checked="checked"';
}

output += '\n/> Text\n<input type="radio" name="search_type" value="category"\n';
//line 47 "widget_search_edit.html"
if (stash.get('search_type') == 'category') {
output += 'checked="checked"';
}

output += '\n/> Tag\n<input type="radio" name="search_type" value="title"\n';
//line 50 "widget_search_edit.html"
if (stash.get('search_type') == 'title') {
output += 'checked="checked"';
}

output += '\n/> Title\n</td>\n</tr>\n\n\n\n<tr>\n<td class="st-widget-dialog-editlabel">\nFull results:\n</td>\n<td class="st-widget-dialog-editfield">\n<input type="checkbox" name="full"';
//line 62 "widget_search_edit.html"
if (stash.get('full')) {
output += ' checked="checked"';
}

output += ' />\n</td>\n</tr>\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="search_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 73 "widget_search_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_section_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">Section Marker</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Add a section marker at the current cursor location. You can link to a section marker using a "Section Link". Use this form to edit the properties for the section marker.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Section name:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-section_name" name="section_name" value="';
//line 10 "widget_section_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('section_name');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="section_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">There are no optional properties for a section marker.</p>\n<table class="st-widgets-moreoptionstable">\n\n\n\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="section_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 34 "widget_section_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_skype_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">Skype Link</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Display a link to a Skype name. Clicking the link will start a Skype call with the person if your Skype client is properly configured. Use this form to edit the properties of the link.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Skype name:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-skype_id" name="skype_id" value="';
//line 10 "widget_skype_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('skype_id');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="skype_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">There are no optional properties for a Skype link.</p>\n<table class="st-widgets-moreoptionstable">\n\n\n\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="skype_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 34 "widget_skype_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_tag_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">Tag Link</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Display a link to a list of pages with a specific tag. Use this form to edit the properties of the link.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Tag name:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-tag_name" name="tag_name" value="';
//line 10 "widget_tag_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('tag_name');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="tag_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">Optional properties include link text, and the name of a different workspace for the tags.</p>\n<table class="st-widgets-moreoptionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Link text:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-label" name="label" value="';
//line 26 "widget_tag_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('label');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n<tr>\n  <td class="st-widget-dialog-editlabel">Search:</td>\n  <td class="st-widget-dialog-editfield">\n    <p class="st-widget-dialog-defaultradio"><input type="radio" name="st-widget-workspace_id-rb" value="current" checked>the current\nworkspace\n<i>&nbsp;&nbsp;or</i></p>\n<p class="st-widget-dialog-choiceradio">\n  <input type="radio" name="st-widget-workspace_id-rb" value="other">the\n  workspace named&nbsp;\n<input size="25" type="text" id="st-widget-workspace_id" name="workspace_id" value="';
//line 38 "widget_tag_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('workspace_id');

    return context.filter(output, 'html', []);
})();

output += '"/>\n</p>\n</td>\n</tr>\n\n\n\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="tag_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 53 "widget_tag_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_tag_list_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">Tag List</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Display a list of the most recently changed pages in a workspace that have a specific tag. By default only the page title is displayed. Use this form to edit the list properties.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Tag name:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-tag_name" name="tag_name" value="';
//line 10 "widget_tag_list_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('tag_name');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="tag_list_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">Optional properties include specifying which workspace to use and whether to display page titles or whole pages.</p>\n<table class="st-widgets-moreoptionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Pages in:</td>\n  <td class="st-widget-dialog-editfield">\n    <p class="st-widget-dialog-defaultradio"><input type="radio" name="st-widget-workspace_id-rb" value="current" checked>the current\nworkspace\n<i>&nbsp;&nbsp;or</i></p>\n<p class="st-widget-dialog-choiceradio">\n  <input type="radio" name="st-widget-workspace_id-rb" value="other">the\n  workspace named&nbsp;\n<input size="25" type="text" id="st-widget-workspace_id" name="workspace_id" value="';
//line 32 "widget_tag_list_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('workspace_id');

    return context.filter(output, 'html', []);
})();

output += '"/>\n</p>\n</td>\n</tr>\n\n\n\n\n<tr>\n<td class="st-widget-dialog-editlabel">\nFull results:\n</td>\n<td class="st-widget-dialog-editfield">\n<input type="checkbox" name="full"';
//line 45 "widget_tag_list_edit.html"
if (stash.get('full')) {
output += ' checked="checked"';
}

output += ' />\n</td>\n</tr>\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="tag_list_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 56 "widget_tag_list_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_technorati_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">Technorati Search</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Display the results for a Technorati search. Use this form to edit the properties for the search.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Search for:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-search_term" name="search_term" value="';
//line 10 "widget_technorati_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('search_term');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="technorati_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">There are no optional properties for a Technorati search.</p>\n<table class="st-widgets-moreoptionstable">\n\n\n\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="technorati_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 34 "widget_technorati_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_toc_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">Table of Contents</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Display a table of contents for a page. Each header or section on the page is listed as a link in the table of contents. Click "Save" now, or click "More options" to edit the properties for the table of contents.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n</table>\n</div>\n<div id="toc_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">Optionally, specify which page\'s headers and sections to use for the table of contents.</p>\n<table class="st-widgets-moreoptionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Page in:</td>\n  <td class="st-widget-dialog-editfield">\n    <p class="st-widget-dialog-defaultradio"><input type="radio" name="st-widget-workspace_id-rb" value="current" checked>the current\nworkspace\n<i>&nbsp;&nbsp;or</i></p>\n<p class="st-widget-dialog-choiceradio">\n  <input type="radio" name="st-widget-workspace_id-rb" value="other">the\n  workspace named&nbsp;\n<input size="25" type="text" id="st-widget-workspace_id" name="workspace_id" value="';
//line 26 "widget_toc_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('workspace_id');

    return context.filter(output, 'html', []);
})();

output += '"/>\n</p>\n</td>\n</tr>\n<tr>\n  <td class="st-widget-dialog-editlabel">Headers and<br/>sections in:</td>\n  <td class="st-widget-dialog-editfield">\n    <p class="st-widget-dialog-defaultradio"><input type="radio" name="st-widget-page_title-rb" value="current" checked>the current\npage\n<i>&nbsp;&nbsp;or</i></p>\n<p class="st-widget-dialog-choiceradio">\n  <input type="radio" name="st-widget-page_title-rb" value="other">the\n  page titled&nbsp;\n<input size="25" type="text" id="st-widget-page_title" name="page_title" value="';
//line 39 "widget_toc_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('page_title');

    return context.filter(output, 'html', []);
})();

output += '"/>\n</p>\n</td>\n</tr>\n\n\n\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="toc_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 54 "widget_toc_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_user_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">User Name</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Display the full name for the given email address or user name. Use this form to edit the properties of the user name.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">User\'s email:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-user_email" name="user_email" value="';
//line 10 "widget_user_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('user_email');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="user_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">There are no optional properties for a user name.</p>\n<table class="st-widgets-moreoptionstable">\n\n\n\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="user_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 34 "widget_user_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_weblog_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">Weblog Link</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Display a link to a weblog. Use this form to edit the properties of the link.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Weblog name:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-weblog_name" name="weblog_name" value="';
//line 10 "widget_weblog_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('weblog_name');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="weblog_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">Optional properties include link text, and the name of a different workspace for the weblog.</p>\n<table class="st-widgets-moreoptionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Link text:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-label" name="label" value="';
//line 26 "widget_weblog_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('label');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n<tr>\n  <td class="st-widget-dialog-editlabel">Weblog on:</td>\n  <td class="st-widget-dialog-editfield">\n    <p class="st-widget-dialog-defaultradio"><input type="radio" name="st-widget-workspace_id-rb" value="current" checked>the current\nworkspace\n<i>&nbsp;&nbsp;or</i></p>\n<p class="st-widget-dialog-choiceradio">\n  <input type="radio" name="st-widget-workspace_id-rb" value="other">the\n  workspace named&nbsp;\n<input size="25" type="text" id="st-widget-workspace_id" name="workspace_id" value="';
//line 38 "widget_weblog_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('workspace_id');

    return context.filter(output, 'html', []);
})();

output += '"/>\n</p>\n</td>\n</tr>\n\n\n\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="weblog_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 53 "widget_weblog_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_weblog_list_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">Weblog List</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Display a list of the most recent entries from a weblog in a workspace. By default only the weblog entry names are displayed. Use this form to edit the list properties.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Weblog name:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-weblog_name" name="weblog_name" value="';
//line 10 "widget_weblog_list_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('weblog_name');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="weblog_list_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">Optional parameters include specifying which workspace to use and whether to display page titles or whole pages.</p>\n<table class="st-widgets-moreoptionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">in:</td>\n  <td class="st-widget-dialog-editfield">\n    <p class="st-widget-dialog-defaultradio"><input type="radio" name="st-widget-workspace_id-rb" value="current" checked>the current\nworkspace\n<i>&nbsp;&nbsp;or</i></p>\n<p class="st-widget-dialog-choiceradio">\n  <input type="radio" name="st-widget-workspace_id-rb" value="other">the\n  workspace named&nbsp;\n<input size="25" type="text" id="st-widget-workspace_id" name="workspace_id" value="';
//line 32 "widget_weblog_list_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('workspace_id');

    return context.filter(output, 'html', []);
})();

output += '"/>\n</p>\n</td>\n</tr>\n\n\n\n\n<tr>\n<td class="st-widget-dialog-editlabel">\nFull results:\n</td>\n<td class="st-widget-dialog-editfield">\n<input type="checkbox" name="full"';
//line 45 "widget_weblog_list_edit.html"
if (stash.get('full')) {
output += ' checked="checked"';
}

output += ' />\n</td>\n</tr>\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="weblog_list_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 56 "widget_weblog_list_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

Jemplate.templateMap['widget_yahoo_edit.html'] = function(context) {
    if (! context) throw('Jemplate function called without context\n');
    var stash = context.stash;
    var output = '';

    try {
output += '<span class="st-widget-dialog-title">Yahoo! IM Link</span>\n<form>\n<div class="st-widget-dialog">\n<p class="st-widget-description">Display a link to a Yahoo! instant message ID. The icon will show whether the person is online. Clicking the link will start an IM conversation with the person if your IM client is properly configured. Use this form to edit the properties of the link.</p>\n<div id="st-widgets-standardoptionspanel">\n<table class="st-widgets-optionstable">\n<tr>\n  <td class="st-widget-dialog-editlabel">Yahoo! ID:</td>\n  <td class="st-widget-dialog-editfield">\n    <input size="40" type="text" id="st-widget-yahoo_id" name="yahoo_id" value="';
//line 10 "widget_yahoo_edit.html"

// FILTER
output += (function() {
    var output = '';

output += stash.get('yahoo_id');

    return context.filter(output, 'html', []);
})();

output += '"/>\n  </td>\n</tr>\n</table>\n</div>\n<div id="yahoo_widget_edit_error_msg" class="widget_edit_error_msg"></div>\n<div class="st-widgets-options">\n    <img id="st-widgets-optionsicon" src="/static/2.9.3.0/images/st/show_more.gif">\n    <a id="st-widgets-moreoptions" href="#">More options</a>\n</div>\n<div id="st-widgets-moreoptionspanel">\n<p class="st-widget-description">There are no optional properties for a Yahoo! link.</p>\n<table class="st-widgets-moreoptionstable">\n\n\n\n\n</table>\n<div class="st-widgetdialog-wikitext">\n    <span class="label">wiki text: </span>\n    <span class="wikitext" id="yahoo_wafl_text">&nbsp;</span>\n</div>\n</div>\n</div>\n';
//line 34 "widget_yahoo_edit.html"
output += context.process('save-cancel.html');
output += '\n</form>\n\n\n';
    }
    catch(e) {
        var error = context.set_error(e, output);
        throw(error);
    }

    return output;
}

// BEGIN pagetags.js
if (typeof ST == 'undefined') {
    ST = {};
}

// St.Tags Class

ST.Tags = function (args) {
    $H(args).each(this._applyArgument.bind(this));

    Event.observe(window, 'load', this._loadInterface.bind(this));
};


ST.Tags.prototype = {
    showTagField: false,
    workspaceTags: {},
    initialTags: {},
    suggestionRE: '',
    _deleted_tags: [],
    socialtextModifiers: {
        uri_escape: function (str) {
            return encodeURIComponent(str);
        },
        escapespecial : function(str) {
            var escapes = [
                { regex: /'/g, sub: "\\'" },
                { regex: /\n/g, sub: "\\n" },
                { regex: /\r/g, sub: "\\r" },
                { regex: /\t/g, sub: "\\t" }
            ];
            for (var i=0; i < escapes.length; i++)
                str = str.replace(escapes[i].regex, escapes[i].sub);
            return str;
        },
        quoter: function (str) {
            return str.replace(/"/g, '&quot;');
        },
        tagescapespecial : function(t) {
            var escapes = [
                { regex: /'/g, sub: "\\'" },
                { regex: /\n/g, sub: "\\n" },
                { regex: /\r/g, sub: "\\r" },
                { regex: /\t/g, sub: "\\t" }
            ];
            s = t.name;
            for (var i=0; i < escapes.length; i++)
                s = s.replace(escapes[i].regex, escapes[i].sub);
            return s;
        }
    },

    element: {
        workspaceTags: 'st-tags-workspace',
        tagName: 'st-tags-tagtemplate',
        tagSuggestion: 'st-tags-suggestiontemplate',
        addButton: 'st-tags-addbutton',
        displayAdd: 'st-tags-addlink',
        initialTags: 'st-tags-initial',
        tagField: 'st-tags-field',
        addInput: 'st-tags-addinput',
        addBlock: 'st-tags-addblock',
        message: 'st-tags-message',
        tagSuggestionList: 'st-tags-suggestionlist',
        suggestions: 'st-tags-suggestion',
        deleteTagsMessage: 'st-tags-deletemessage',
        noTagsPlaceholder: 'st-no-tags-placeholder'
    },

    jst: {
        name: '', // WAS TaglineTemplate
        suggestion: '' // WAS SuggestionFormat
    },

    displayListOfTags: function (tagfield_should_focus) {
        this.tagCollection.maxCount = this.workspaceTags.maxCount;
        var tagList = this.tagCollection;
        if (tagList.tags && tagList.tags.length > 0) {
            tagList._MODIFIERS = this.socialtextModifiers;
            this.tagCollection = tagList;

            // Tags might have raw html.
            for (var ii = 0; ii < tagList.tags.length ; ii++)
               tagList.tags[ii].name = html_escape( tagList.tags[ii].name );

            this.computeTagLevels();
            this.jst.name.update(tagList);
        } else {
            this.jst.name.clear();
        }
        if (this.showTagField) {
            Element.setStyle('st-tags-addinput', {display: 'block'});
            if (tagfield_should_focus) {
                tagField = $(this.element.tagField).focus();
            }
        }
        if ($('st-tags-message')) {
            Element.hide('st-tags-message');
        }
    },

    _copy_page_tags_to_master_list: function () {
        for (var i=0; i < this.tagCollection.tags.length; i++) {
            found = false;
            var tag = this.tagCollection.tags[i];
            var lctag = tag.name.toLowerCase();
            for (var j=0; j < this.workspaceTags.tags.length; j++) {
                if (this.workspaceTags.tags[j].name.toLowerCase() == lctag) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                this.workspaceTags.tags.push(tag);
            }
        }
    },

    decodeTagNames: function () {
        var tagList = this.tagCollection;
        for (i=0; i < tagList.tags.length; i++)
            tagList.tags[i].name = decodeURIComponent(tagList.tags[i].name);
    },

    computeTagLevels: function () {
        var tagList = this.tagCollection;
        var i=0;
        var maxWeight = tagList.maxCount;

        if (maxWeight < 10) {
            for (i=0; i < tagList.tags.length; i++)
                tagList.tags[i].level = 'st-tags-level2';
        }
        else {
            for (i=0; i < tagList.tags.length; i++) {
                var tagWeight = tagList.tags[i].page_count / maxWeight;
                if (tagWeight > 0.8)
                    tagList.tags[i].level = 'st-tags-level5';
                else if (tagWeight > 0.6)
                    tagList.tags[i].level = 'st-tags-level4';
                else if (tagWeight > 0.4)
                    tagList.tags[i].level = 'st-tags-level3';
                else if (tagWeight > 0.2)
                    tagList.tags[i].level = 'st-tags-level2';
                else
                    tagList.tags[i].level = 'st-tags-level1';
            }
        }
        this.tagCollection = tagList;
    },

    addTag: function (tagToAdd) {
        Element.hide(this.element.suggestions);
        tagToAdd = this._trim(tagToAdd);
        var tagField = $(this.element.tagField);
        if (tagToAdd.length == 0) {
            return;
        }
        this.showTagMessage('Adding tag ' + html_escape(tagToAdd));
        var uri = Page.APIUriPageTag(tagToAdd);
        new Ajax.Request (
            uri,
            {
                method: 'post',
                requestHeaders: ['X-Http-Method','PUT'],
                onComplete: (function (req) {
                    this._remove_from_deleted_list(tagToAdd);
                    this.fetchTags();
                    Page.refresh_page_content();
                }).bind(this),
                onFailure: (function(req, jsonHeader) {
                    this.resetDisplayOnError();
                }).bind(this)
            }
        );
        tagField.value = '';
    },

    addTagFromField: function () {
        this.addTag($(this.element.tagField).value);
    },

    displayAddTag: function () {
        this.showTagField = true;
        Element.setStyle(this.element.addInput, {display: 'block'});
        $(this.element.tagField).focus();
        Element.hide(this.element.addBlock);
    },

    _remove_from_deleted_list: function (tagToRemove) {
        this._deleted_tags.deleteElementIgnoreCase(tagToRemove);
        this._update_delete_list();
    },

    showTagMessage: function (msg) {
        Element.hide(this.element.addInput);
        Element.setStyle(this.element.message, {display: 'block'});
        Element.update(this.element.message, msg);
    },

    resetDisplayOnError: function() {
        if (this.showTagField) {
            Element.setStyle(this.element.addInput, {display: 'block'});
        }
        Element.hide(this.element.message);
        Element.update(this.element.message, '');
    },

    findSuggestions: function () {
        var field = $(this.element.tagField);

        if (field.value.length == 0) {
            Element.hide(this.element.suggestions);
        } else {
            if (this.workspaceTags.tags) {
                var expression = field.value;
                if (field.value.search(/ /) == -1) {
                    expression = '\\b'+expression;
                }
                this.suggestionRE = new RegExp(expression,'i');
                var suggestions = {
                    matches : this.workspaceTags.tags.grep(this.matchTag.bind(this))
                };
                Element.setStyle(this.element.suggestions, {display: 'block'});
                if (suggestions.matches.length > 0) {
                    suggestions._MODIFIERS = this.socialtextModifiers;
                    this.jst.suggestion.update(suggestions);
                } else {
                    var help = '<span class="st-tags-nomatch">No matches</span>';
                    this.jst.suggestion.set_text(help);
                }
            }
        }
    },

    matchTag: function (tag) {
        if (typeof tag.name == 'number') {
            var s = tag.name.toString();
            return s.search(this.suggestionRE) != -1;
        } else {
            return tag.name.search(this.suggestionRE) != -1;
        }
    },

    tagFieldKeyHandler: function (event) {
        var key;
        if (window.event) {
            key = event.keyCode;
        } else if (event.which) {
            key = event.which;
        }

        if (key == Event.KEY_RETURN) {
            this.addTagFromField();
            return false;
        } else if (key == Event.KEY_TAB) {
            return this.setFirstMatchingSuggestion();
        }
    },

    setFirstMatchingSuggestion: function () {
        var field = $(this.element.tagField);

        if (field.value.length > 0) {
            var suggestions = this.workspaceTags.tags.grep(this.matchTag.bind(this));
            if ((suggestions.length >= 1) && (field.value != suggestions[0].tag)) {
                field.value = suggestions[0].tag;
                return false;
            }
        }
        return true;
    },

    fetchTags: function () {
        var uri = Page.APIUriPageTags();
        var date = new Date();
        uri += ';iecacheworkaround=' + date.toLocaleTimeString();
        var ar = new Ajax.Request (
            uri,
            {
                method: 'get',
                requestHeaders: ['Accept','application/json'],
                onComplete: (function (req) {
                    this.tagCollection.tags = JSON.parse(req.responseText);
                    if (this.tagCollection.tags.length == 0) {
                        Element.show(this.element.noTagsPlaceholder);
                    } else {
                        Element.hide(this.element.noTagsPlaceholder);
                    }
                    this.decodeTagNames(); /* Thanks, IE */
                    this.displayListOfTags(false);
                    $(this.element.tagField).focus();
                }).bind(this),
                onFailure: (function(req, jsonHeader) {
                    this._deleted_tags.pop();
                    alert('Could not remove tag');
                    this.resetDisplayOnError();
                }).bind(this)
            }
        );
    },

    deleteTag: function (tagToDelete) {
        this.showTagMessage('Removing tag ' + tagToDelete);
        this._deleted_tags.push(tagToDelete);

        var uri = Page.UriPageTagDelete(tagToDelete);
        var ar = new Ajax.Request (
            uri,
            {
                method: 'post',
                requestHeaders: ['X-Http-Method','DELETE'],
                onComplete: (function (req) {
                    this._update_delete_list();
                    this.fetchTags();
                }).bind(this),
                onFailure: (function(req, jsonHeader) {
                    this._deleted_tags.pop();
                    alert('Could not remove tag');
                    this.resetDisplayOnError();
                }).bind(this)
            }
        );
    },

    _update_delete_list: function () {
        if (this._deleted_tags.length > 0) {
            Element.update(this.element.deleteTagsMessage, 'These tags have been removed: ' + this._deleted_tags.join(', '));
            $(this.element.deleteTagsMessage).style.display = 'block';
        }
        else {
            Element.update(this.element.deleteTagsMessage, '');
            $(this.element.deleteTagsMessage).style.display = 'none';
        }
    },

    _applyArgument: function (arg) {
        if (typeof this[arg.key] != 'undefined') {
            this[arg.key] = arg.value;
        }
    },

    _trim: function (value) {
        // XXX Belongs in Scalar Utils?
        var ltrim = /\s*((\s*\S+)*)/;
        var rtrim = /((\s*\S+)*)\s*/;
        return value.replace(rtrim, "$1").replace(ltrim, "$1");
    },

    _loadInterface: function () {
        this.jst.name = new ST.TemplateField(this.element.tagName, 'st-tags-listing');
        this.jst.suggestion = new ST.TemplateField(this.element.tagSuggestion, this.element.tagSuggestionList);

        this.workspaceTags  = JSON.parse($(this.element.workspaceTags).value);
        this.tagCollection = JSON.parse($(this.element.initialTags).value);

        if ($(this.element.addButton)) {
            Event.observe(this.element.addButton,  'click', this.addTagFromField.bind(this));
        }
        if ($(this.element.displayAdd)) {
            Event.observe(this.element.displayAdd, 'click', this.displayAddTag.bind(this));
        }
        if ($(this.element.tagField)) {
            Event.observe(this.element.tagField, 'keyup', this.findSuggestions.bind(this));
            Event.observe(this.element.tagField, 'keydown', this.tagFieldKeyHandler.bind(this));
        }

        this.displayListOfTags(false);
    }

};
// BEGIN pageattachments.js
if (typeof ST == 'undefined') {
    ST = {};
}

// ST.Attachments class
ST.Attachments = function (args) {
    this._uploaded_list = [];
    $H(args).each(this._applyArgument.bind(this));

    Event.observe(window, 'load', this._loadInterface.bind(this));
};

function sort_filesize(a,b) {
    var aunit = a.charAt(a.length-1);
    var bunit = b.charAt(b.length-1);
    if (aunit != bunit) {
        if (aunit < bunit) {
            return -1;
        } else if ( aunit > bunit ) {
            return 1;
        } else {
            return 0;
        }
    } else {
        var asize = parseFloat(a.slice(0,-1));
        var bsize = parseFloat(b.slice(0,-1));
        if (asize < bsize) {
            return -1;
        } else if ( asize > bsize ) {
            return 1;
        } else {
            return 0;
        }
    }
};

ST.Attachments.prototype = {
    attachments: null,
    _uploaded_list: [],
    _attachWaiter: '',
    _table_sorter: null,

    element: {
        attachmentInterface:   'st-attachments-attachinterface',
        manageInterface:       'st-attachments-manageinterface',

        listTemplate:          'st-attachments-listtemplate',
        manageTableTemplate:   'st-attachments-managetable',

        uploadButton:          'st-attachments-uploadbutton',
        manageButton:          'st-attachments-managebutton',

        attachForm:            'st-attachments-attach-form',
        attachSubmit:          'st-attachments-attach-submit',
        attachUnpackCheckbox:  'st-attachments-attach-unpackcheckbox',
        attachEmbedCheckbox:   'st-attachments-attach-embedcheckbox',
        attachUnpack:          'st-attachments-attach-unpackfield',
        attachEmbed:           'st-attachments-attach-embedfield',
        attachUnpackLabel:     'st-attachments-attach-unpacklabel',
        attachCloseButton:     'st-attachments-attach-closebutton',
        attachFilename:        'st-attachments-attach-filename',
        attachFileError:       'st-attachments-attach-error',
        attachFileList:        'st-attachments-attach-list',
        attachMessage:         'st-attachments-attach-message',
        attachUploadMessage:   'st-attachments-attach-uploadmessage',

        manageTableRows:       'st-attachments-manage-body',
        manageCloseButton:     'st-attachments-manage-closebutton',
        manageDeleteButton:    'st-attachments-manage-deletebutton',
        manageDeleteMessage:   'st-attachments-manage-deletemessage',
        manageSelectAll:       'st-attachments-manage-selectall',
        manageTable:           'st-attachments-manage-filelisting'
    },

    jst: {
        list: '',
        manageTable: ''
    },

    _applyArgument: function (arg) {
        if (typeof this[arg.key] != 'undefined') {
            this[arg.key] = arg.value;
        }
    },

    _attach_status_check: function () {
        var text = null;
        Try.these(
            function () { text = $('st-attachments-attach-formtarget').contentWindow.document.body.innerHTML; },
            function () { text = $('st-attachments-attach-formtarget').contentDocument.body.innerHTML; }
        );
        if (text == null)
            return;
        clearInterval(this._attach_waiter);
        $(this.element.attachUploadMessage).style.display = 'none';
        Element.update(this.element.attachUploadMessage, '');
        $(this.element.attachSubmit).disabled = false;
        $(this.element.attachUnpackCheckbox).disabled = false;
        $(this.element.attachEmbedCheckbox).disabled = false;
        $(this.element.attachCloseButton).style.display = 'block';

        Element.update(this.element.attachMessage, 'Click "Browse" to find the file you want to upload. When you click "Upload another file" your file will be uploaded and added to the list of attachments for this page.');
        $(this.element.attachSubmit).value = 'Upload another file';
        if (text.match(/Request Entity Too Large/)) {
            text = 'File size exceeds maximum limit. File was not uploaded.';
        }
        else {
            this._pullAttachmentList();
            Page.refresh_page_content();
        }

        Try.these(
            (function() {
                $(this.element.attachFilename).value = '';
                if ($(this.element.attachFilename).value) {
                    throw new Error ("Failed to clear value");
                }
            }).bind(this),
            (function() {
                var input = document.createElement('input');
                var old   = $(this.element.attachFilename);
                input.type = old.type;
                input.name = old.name;
                input.size = old.size;
                old.parentNode.replaceChild(input, old);
                input.id = this.element.attachFilename;
                this._hook_filename_field();
            }).bind(this)
        );
        $(this.element.attachFilename).focus();
        setTimeout(this._hide_attach_error.bind(this), 5 * 1000);
    },

    _attach_file_form_submit: function () {
        var filenameField = $(this.element.attachFilename);
        if (! filenameField.value) {
            this._show_attach_error("Please click browse and select a file to upload.");
            return false;
        }

        this._update_ui_for_upload(filenameField.value);
        $(this.element.attachCloseButton).style.display = 'none';

        this._attach_waiter = setInterval(this._attach_status_check.bind(this), 3 * 1000);
        return true;
    },

    _update_ui_for_upload: function (filename) {
        Element.update(this.element.attachUploadMessage, 'Uploading ' + filename + '...');
        $(this.element.attachSubmit).disabled = true;

        var cb = $(this.element.attachUnpackCheckbox);
        $(this.element.attachUnpack).value = (cb.checked) ? '1' : '0';
        cb.disabled = true;

        var cb = $(this.element.attachEmbedCheckbox);
        $(this.element.attachEmbed).value = (cb.checked) ? '1' : '0';
        cb.disabled = true;

        $(this.element.attachUploadMessage).style.display = 'block';

//        this._update_uploaded_list(filename);
        this._hide_attach_error();
    },

    _check_for_zip_file: function () {
        var filename = $(this.element.attachFilename).value;

        if (filename.match(/\.zip$/, 'i')) {
            this._enable_unpack();
        } else {
            this._disable_unpack();
        }
    },

    _clear_uploaded_list: function () {
        this._uploaded_list = [];
        this._refresh_uploaded_list();
    },

    _delete_selected_attachments: function () {
        var to_delete = [];
        $A($(this.element.manageTableRows).getElementsByTagName('tr')).each(function (node) {
            if (node.getElementsByTagName('input')[0].checked) {
                Element.hide(node);
                to_delete.push(node.getElementsByTagName('input')[0].value);
            }
        });
        if (to_delete.length == 0)
            return false;

        var j = 0;
        var i = 0;
        for (i = 0; i < to_delete.length; i++) {
//            var attachmentId = to_delete[i].match(/\,(.+)\,/)[1];
//            var uri = Wikiwyg.is_safari
//                ? Page.UriPageAttachmentDelete(attachmentId)
//                : Page.APIUriAttachmentDelete(attachmentId);

            var ar = new Ajax.Request (
                to_delete[i],
                {
                    method: 'post',
                    requestHeaders: ['X-Http-Method','DELETE'],
                    onComplete: function(xhr) {
                        if( Wikiwyg.is_safari) {
                            j++;
                            return;
                        }
                    }.bind(this)
                }
            );
        }

        //if ( Wikiwyg.is_safari ) {
        //    var intervalID = window.setInterval(
        //        function() {
        //            if ( j < to_delete.length ) {
        //                return;
        //            }
        //            var ar = new Ajax.Request(
        //                Page.APIUriPageAttachment(),
        //                {
        //                    method: 'get',
        //                    asynchronous: false,
        //                    requestHeaders: ['Accept', 'text/javascript']
        //                }
        //            );
        //            this.attachments = JSON.parse(ar.transport.responseText);
        //            this._refresh_attachment_list();
        //            clearInterval( intervalID );
        //        }.bind(this)
        //        , 5
        //    );
        //}

// TODO - Update message setTimeout(function () {Element.update(this.element.manageDeleteMessage, '')}, 2000);
//        this._pullAttachmentList();
//        Page.refresh_page_content();
        return false;
    },

    _disable_unpack: function () {
        var unpackCheckbox = $(this.element.attachUnpackCheckbox);
        unpackCheckbox.disabled = true;
        unpackCheckbox.checked = false;
        unpackCheckbox.style.display = 'none';

        var label = $(this.element.attachUnpackLabel);
        label.style.color = '#aaa';
        label.style.display = 'none';
    },

    _display_attach_interface: function () {
        field = $(this.element.attachFilename);
        Try.these(function () {
            field.value = '';
        });

        $(this.element.attachmentInterface).style.display = 'block';
        this._disable_scrollbar();

        $(this.element.attachSubmit).value = 'Upload file';
        Element.update(this.element.attachMessage, 'Click "Browse" to find the file you want to upload. When you click "Upload file" your file will be uploaded and added to the list of attachments for this page.');

        var overlayElement = $('st-attachments-attach-attachinterface-overlay');
        var element = $('st-attachments-attach-interface');
        this._center_lightbox(overlayElement, element, this.element.attachmentInterface);
        this._disable_unpack();
        this._check_for_zip_file();
        field.focus();
        return false;
    },

    _center_lightbox: function (overlayElement, element, parentElement) {
        var divs = {
            wrapper: $(parentElement),
            background: overlayElement,
            content: element,
            contentWrapper: element.parentNode
        };
        Widget.Lightbox.show({'divs':divs});

    },

    _display_manage_interface: function () {
        $(this.element.manageSelectAll).checked = false;
        this._refresh_manage_table();
        $(this.element.manageInterface).style.display = 'block';
        this._disable_scrollbar();
        var overlayElement = $('st-attachments-manage-manageinterface-overlay');
        var element = $('st-attachments-manage-interface');
        this._center_lightbox(overlayElement, element, this.element.manageInterface);

        this._table_sorter = new Widget.SortableTable( {
            "tableId": this.element.manageTable,
            "initialSortColumn": 1,
            "columnSpecs": [
              { skip: true },
              { sort: "text" },
              { sort: "text" },
              { sort: "date" },
              { sort: sort_filesize}
            ]
          } );
        return false;
    },

    _enable_scrollbar: function(){
        this._disable_scrollbar('auto','auto');
    },

    // This method has parameters because it could
    // be used to both enable and disable scrollbar. Caller
    // shouldn't give any arguments when calling it.
    _disable_scrollbar: function(height, overflow){
        if ( !height ) height = '100%';
        if ( !overflow ) overflow = 'hidden';

        var bod = document.getElementsByTagName('body')[0];
        bod.style.height = height;
        bod.style.overflow = overflow;

        var htm = document.getElementsByTagName('html')[0];
        htm.style.height = height;
        htm.style.overflow = overflow;
    },

    _enable_unpack: function () {
        var unpackCheckbox = $(this.element.attachUnpackCheckbox);
        unpackCheckbox.disabled = false;
        unpackCheckbox.checked = false;
        unpackCheckbox.style.display = '';

        var label = $(this.element.attachUnpackLabel);
        label.style.color = 'black';
        label.style.display = '';
    },

    _hide_attach_error: function () {
        $(this.element.attachFileError).style.display = 'none';
    },

    _hide_attach_file_interface: function () {
        if (!this._is_uploading_file()) {
            $(this.element.attachmentInterface).style.display = 'none';
            $(this.element.attachSubmit).value = 'Upload file';
            this._enable_scrollbar();
            this._clear_uploaded_list();
        }
        return false;
    },

    _hide_manage_file_interface: function () {
        this._pullAttachmentList();
        Page.refresh_page_content(true);

        $(this.element.manageInterface).style.display = 'none';
        this._enable_scrollbar();
        return false;
    },

    _hook_filename_field: function() {
        if (! $(this.element.attachFilename)) return;
        Event.observe(this.element.attachFilename,     'blur',   this._check_for_zip_file.bind(this));
        Event.observe(this.element.attachFilename,     'keyup',  this._check_for_zip_file.bind(this));
        Event.observe(this.element.attachFilename,     'change', this._check_for_zip_file.bind(this));
    },

    _is_uploading_file: function() {
        return $(this.element.attachSubmit).disabled;
    },

    _pullAttachmentList: function () {
        var ar = new Ajax.Request(
            Page.AttachmentListUri(),
            {
                method: 'get',
                requestHeaders: ['Accept', 'application/json'],
                onComplete: (function (req) {
                    this.attachments = JSON.parse(req.responseText);
                    this._refresh_attachment_list();
                }).bind(this)
            }
        );
    },

    _refresh_attachment_list: function () {
        if (this.attachments && this.attachments.length > 0) {
            var data = {};
            data.attachments = this.attachments;
            this.jst.list.update(data);
        } else {
            this.jst.list.clear();
        }
        return false;
    },

    _refresh_manage_table: function () {
        if (this.attachments && this.attachments.length > 0) {
            var data = {};
            data.attachments = this.attachments;
            var i;
            for (i=0; i< data.attachments.length; i++) {
                var filesize = data.attachments[i]['content-length'];
                var n = 0;
                var unit = '';
                if (filesize < 1024) {
                    unit = 'B';
                    n = filesize;
                } else if (filesize < 1024*1024) {
                    unit = 'K';
                    n = filesize/1024;
                    if (n < 10)
                        n = n.toPrecision(2);
                    else
                        n = n.toPrecision(3);
                } else {
                    unit = 'M';
                    n = filesize/(1024*1024);
                    if (n < 10) {
                        n = n.toPrecision(2);
                    } else if ( n < 1000) {
                        n = n.toPrecision(3);
                    } else {
                        n = n.toFixed(0);
                    }
                }
                data.attachments[i].displaylength = n + unit;
            }
            data.page_name = Page.page_id;
            data.workspace = Page.wiki_id;
            Try.these(
                (function () {
                    this.jst.manageTable.update(data);
                }).bind(this),
                (function () { /* http://www.ericvasilik.com/2006/07/code-karma.html */
                    var temp = document.createElement('div');
                    temp.innerHTML = '<table><tbody id="' + this.element.manageTableRows + '-temp">' +
                                     this.jst.manageTable.html(data) + '</tbody></table>';
                    $(this.element.manageTableRows).parentNode.replaceChild(
                        temp.childNodes[0].childNodes[0],
                        $(this.element.manageTableRows)
                    );
                    $(this.element.manageTableRows + '-temp').id = this.element.manageTableRows;
                }).bind(this)
            );
        } else {
            Try.these(
                (function () {
                    this.jst.manageTable.clear();
                }).bind(this),
                (function () { /* http://www.ericvasilik.com/2006/07/code-karma.html */
                    var temp = document.createElement('div');
                    temp.innerHTML = '<table><tbody id="' + this.element.manageTableRows + '-temp"></tbody></table>';
                    $(this.element.manageTableRows).parentNode.replaceChild(
                        temp.childNodes[0].childNodes[0],
                        $(this.element.manageTableRows)
                    );
                    $(this.element.manageTableRows + '-temp').id = this.element.manageTableRows;
                }).bind(this)
            );
        }
        return false;
    },

    _refresh_uploaded_list: function () {
        if (this._uploaded_list.length > 0) {
            Element.update(this.element.attachFileList, '<span class="st-attachments-attach-listlabel">Uploaded files: </span>' + this._uploaded_list.join(', '));
            $(this.element.attachFileList).style.display = 'block';
        }
        else {
            $(this.element.attachFileList).style.display = 'none';
            Element.update(this.element.attachFileList, '');
        }
    },

    _show_attach_error: function (msg) {
        if (!msg)
            msg = '&nbsp;';
        Element.update(this.element.attachFileError, msg);
        $(this.element.attachFileError).style.display = 'block';
    },

    _toggle_all_attachments: function () {
        var checkbox = $(this.element.manageSelectAll);

        $A($(this.element.manageTableRows).getElementsByTagName('tr')).each(
            function (node) {
                node.getElementsByTagName('input')[0].checked = checkbox.checked;
            }
        );
    },

    _update_uploaded_list: function (filename) {
        filename = filename.match(/^.+[\\\/]([^\\\/]+)$/)[1];
        this._uploaded_list.push(filename);
    },

    _loadInterface: function () {
        this.jst.list = new ST.TemplateField(this.element.listTemplate, 'st-attachments-listing');
        this.jst.manageTable = new ST.TemplateField(this.element.manageTableTemplate, this.element.manageTableRows);

       this._disable_unpack();

        if ($(this.element.uploadButton)) {
            Event.observe(this.element.uploadButton,       'click',  this._display_attach_interface.bind(this));
        }
        if ($(this.element.manageButton)) {
            Event.observe(this.element.manageButton,       'click',  this._display_manage_interface.bind(this));
        }
        if ($(this.element.manageCloseButton)) {
            Event.observe(this.element.manageCloseButton,  'click',  this._hide_manage_file_interface.bind(this));
        }
        if ($(this.element.manageDeleteButton)) {
            Event.observe(this.element.manageDeleteButton, 'click',  this._delete_selected_attachments.bind(this));
        }
        if ($(this.element.manageSelectAll)) {
            Event.observe(this.element.manageSelectAll,    'click',  this._toggle_all_attachments.bind(this));
        }
        if ($(this.element.attachCloseButton)) {
            Event.observe(this.element.attachCloseButton,  'click',  this._hide_attach_file_interface.bind(this));
        }
        if ($(this.element.attachForm)) {
            Event.observe(this.element.attachForm,         'submit', this._attach_file_form_submit.bind(this));
        }

        this._hook_filename_field();

        this._pullAttachmentList();
    }
};
// BEGIN pageview.js
if (typeof ST == 'undefined') {
    ST = {};
}

// ST.Page calls
ST.Page = function (args) {
    $H(args).each(this._applyArgument.bind(this));
    Event.observe(window, 'load', this._loadInterface.bind(this));
};

ST.Page.prototype = {
    page_id: null,
    wiki_id: null,
    wiki_title: null,
    page_title: null,
    revision_id: null,
    comment_form_window_height: null,
    element: {
        toggleLink: 'st-page-boxes-toggle-link',
        accessories: 'st-page-boxes',
        underlay: 'st-page-boxes-underlay',
        pageEditing: 'st-page-editing',
        content: 'st-content-page-display'
    },
    hideAttributes: {
        onclick: 'showAccessories',
        text: '&gt;'
    },
    showAttributes: {
        onclick: 'hideAccessories',
        text: 'V'
    },

    restApiUri: function () {
        return '/data/workspaces/' + this.wiki_id + '/pages/' + this.page_id;
    },

    APIUri: function () {
        return '/page/' + this.wiki_id + '/' + this.page_id;
    },

    APIUriPageTag: function (tag) {
        return this.restApiUri() + '/tags/' + encodeURIComponent(tag);
    },

    APIUriPageTags: function () {
        return this.restApiUri() + '/tags';
    },

    UriPageTagDelete: function (id) {
        return this.APIUriPageTag(id);
    },

    UriPageAttachmentDelete: function (id) {
        return this. APIUriPageAttachment(id);
    },

    APIUriPageAttachment: function (id) {
        return this.AttachmentListUri + '/' + id;
    },

    AttachmentListUri: function () {
        return this.restApiUri() + '/attachments' + '?' + this.ieCacheFix();
    },

    ieCacheFix: function () {
        var date = new Date();
        return 'iecacheworkaround=' + date.toLocaleTimeString();
    },

    ContentUri: function () {
        return '/' + this.wiki_id + '/index.cgi';
    },

    active_page_exists: function (page_name) {
        page_name = trim(page_name);
        var uri = this.ContentUri();
        uri = uri + '?action=page_info;page_name=' + encodeURIComponent(page_name);
        var ar = new Ajax.Request (
            uri,
            {
                method: 'get',
                asynchronous: false,
                requestHeaders: ['Accept','text/javascript'],
                onFailure: (function(req, jsonHeader) {
                    alert('Could not retrieve the latest revision of the page');
                }).bind(this)
            }
        );
        var page_info = JSON.parse(ar.transport.responseText);
        return page_info.is_active;
    },

    refresh_page_content: function (force_update) {
        var uri = Page.restApiUri();
        uri = uri + '?verbose=1;link_dictionary=s2';
        uri = uri + '' + this.ieCacheFix()
        var request = new Ajax.Request (
            uri,
            {
                method: 'get',
                asynchronous: false,
                requestHeaders: ['Accept','application/json'],
                onFailure: (function(req, jsonHeader) {
                    alert('Could not retrieve the latest revision of the page');
                }).bind(this)
            }
        );

        if (request.transport.status == 403) {
            window.location = "/challenge";
            return;
        }

        if (request.transport.status == 200) {
            var page_info = JSON.parse(request.transport.responseText);
            if (page_info) {
                if ((Page.revision_id < page_info.revision_id) || force_update) {
                    $('st-page-content').innerHTML = page_info.html;
                    $('st-page-editing-revisionid').value = page_info.revision_id;
                    Page.revision_id = page_info.revision_id;
                    if ($('st-raw-wikitext-textarea')) {
                        $('st-raw-wikitext-textarea').value = Wikiwyg.is_safari
                            ? Wikiwyg.htmlUnescape(page_info.wikitext)
                            : page_info.wikitext;
                    }
                    var revisionNode = $('st-rewind-revision-count');
                    if (revisionNode) {
                        Element.update('st-rewind-revision-count', '&nbsp;&nbsp;' + page_info.revision_count);
                        Element.update('st-page-stats-revisions', page_info.revision_count + ' revisions');
                    }
                }
            }
        }
    },

    hideAccessories: function () {
        Cookie.set('st-page-accessories', 'hide');
        Element.hide(this.element.accessories);
        Element.update(this.element.toggleLink, this.hideAttributes.text);
        $(this.element.toggleLink).onclick = this[this.hideAttributes.onclick].bind(this);
        Element.setStyle('st-page-maincontent', {marginRight: '0px'});
    },

    showAccessories: function (leaveMarginAlone) {
        Cookie.set('st-page-accessories', 'show');
        Element.show(this.element.accessories);
        Element.update(this.element.toggleLink, this.showAttributes.text);
        $(this.element.toggleLink).onclick = this[this.showAttributes.onclick].bind(this);
        if (! Element.visible('st-pagetools')) {
            Element.setStyle('st-page-maincontent', {marginRight: '240px'});
        }
    },

    orientAccessories: function () {
        var s_height = $(this.element.accessories).offsetHeight;
        var s_width = $(this.element.accessories).offsetWidth;
        Element.setStyle(this.element.underlay, {height: s_height + 'px'});
        Element.setStyle(this.element.underlay, {width: s_width + 'px'});

        if (document.all) {
            var c_height = (
                 $(this.element.accessories).offsetHeight + (
                       $(this.element.accessories).offsetTop
                     - $(this.element.content).offsetTop
                 )
            );
            if ($(this.element.content).offsetHeight < c_height) {
                if (c_height > 0) {
                    $(this.element.content).style.height = c_height + 'px';
                }
            }
        }
    },

    installUnderlayOrienter: function () {
        /* We want to call it for the first time ASAP since it may
         * change the existing page layout */
        this.orientAccessories();
        setInterval(this.orientAccessories.bind(this), 1000);
    },

    _applyArgument: function (arg) {
        if (typeof this[arg.key] != 'undefined') {
            this[arg.key] = arg.value;
        }
    },

    _loadInterface: function () {
        var m = Cookie.get('st-page-accessories');
        if (m == null || m == 'show') {
            this.showAccessories();
        } else {
            this.hideAccessories();
        }
        this.installUnderlayOrienter();
    }
};

// ST.Page calls
ST.NavBar = function (args) {
    $H(args).each(this._applyArgument.bind(this));
    Event.observe(window, 'load', this._loadInterface.bind(this));
};

ST.NavBar.prototype = {
    element: {
        searchForm: 'st-search-form',
        searchButton: 'st-search-submit',
        searchField: 'st-search-term'
    },

    submit_search: function (arg) {
        $(this.element.searchForm).submit();
    },

    clear_search: function(arg) {
        if( $(this.element.searchField).value.match(/New\s*search/i) ) {
            $(this.element.searchField).value = "";
        }
    },

    _applyArgument: function (arg) {
        if (typeof this[arg.key] != 'undefined') {
            this[arg.key] = arg.value;
        }
    },

    _loadInterface: function () {
        var element = $(this.element.searchButton);
        if (! element) return;
        Event.observe(element, 'click', this.submit_search.bind(this));
        if (! $(this.element.searchField) ) return;
        Event.observe(this.element.searchField, 'click', this.clear_search.bind(this));
        Event.observe(this.element.searchField, 'focus', this.clear_search.bind(this));
    }
};
// BEGIN attachqueue.js
if (typeof ST == 'undefined') {
    ST = {};
}

// ST.Attachments class
ST.AttachmentQueue = function (args) {
    $H(args).each(this._applyArgument.bind(this));

    Event.observe(window, 'load', this._loadInterface.bind(this));
};


ST.AttachmentQueue.prototype = {
    _queued_files: [],
    _sequence: 0,

    element: {
        queueInterface:   'st-attachmentsqueue-interface',

        listTemplate:     'st-attachmentsqueue-listtemplate',
        editUploadButton: 'st-edit-mode-uploadbutton',

        inputContainer:   'st-attachmentsqueue-fileprompt',
        holder:           'st-attachmentsqueue-holder',

        submitButton:     'st-attachmentsqueue-submitbutton',
        unpackCheckbox:   'st-attachmentsqueue-unpackcheckbox',
        unpackMessage:    'st-attachmentsqueue-unpackmessage',
        embedCheckbox:    'st-attachmentsqueue-embedcheckbox',
        embedMessage:     'st-attachmentsqueue-embedmessage',
        unpack:           'st-attachmentsqueue-unpackfield',
        embed:            'st-attachmentsqueue-embedfield',
        unpackLabel:      'st-attachmentsqueue-unpacklabel',
        closeButton:      'st-attachmentsqueue-closebutton',
        filename:         'st-attachmentsqueue-filename',
        fileError:        'st-attachmentsqueue-error',
        fileList:         'st-attachmentsqueue-list',
        message:          'st-attachmentsqueue-message',
        uploadMessage:    'st-attachmentsqueue-uploadmessage'
    },

    jst: {
        list: ''
    },

    _add_new_input: function () {
        var new_input = document.createElement( 'input' );
        new_input.type = 'file';
        new_input.name = 'file';
        new_input.id = 'st-attachmentsqueue-filename';
        new_input.size = 60;
        var container = $(this.element.inputContainer);
        container.appendChild(new_input);
        this._set_handlers_for_input();
    },

    _applyArgument: function (arg) {
        if (typeof this[arg.key] != 'undefined') {
            this[arg.key] = arg.value;
        }
    },

    _check_for_zip_file: function () {
        var filename = $(this.element.filename).value;

        var has_zip = false;
        if (filename.match(/\.zip$/, 'i')) {
            has_zip = true;
        } else {
            has_zip = this._has_zip_file();
        }

        if (has_zip) {
            this._enable_unpack();
        }
        else {
            this._disable_unpack();
        }
    },

    clear_list: function () {
        this._queued_files = [];
        this._refresh_queue_list();
    },

    _disable_unpack: function () {
        var unpackCheckbox = $(this.element.unpackCheckbox);
//        unpackCheckbox.checked = false;
        unpackCheckbox.disabled = true;
        unpackCheckbox.style.display = 'none';

        var label = $(this.element.unpackLabel);
        label.style.color = '#aaa';
        label.style.display = 'none';
    },

    _display_interface: function () {
        field = $(this.element.filename);
        Try.these(function () {
            field.value = '';
        });

        $(this.element.queueInterface).style.display = 'block';
        this._center_lightbox(this.element.queueInterface);
        this._refresh_queue_list();
        field.focus();
        return false;
    },

    _center_lightbox: function (parentElement) {
        var overlayElement = $('st-attachmentsqueue-overlay');
        var element = $('st-attachmentsqueue-dialog');
        parentElement = $(parentElement);
        var divs = {
            wrapper: parentElement,
            background: overlayElement,
            content: element,
            contentWrapper: element.parentNode
        }
        Widget.Lightbox.show({'divs':divs, 'effects':['RoundedCorners']});
    },

    count: function () {
        return this._queued_files.length;
    },

    _enable_unpack: function () {
        var unpackCheckbox = $(this.element.unpackCheckbox);
        unpackCheckbox.disabled = false;
        unpackCheckbox.style.display = '';

        var label = $(this.element.unpackLabel);
        label.style.color = 'black';
        label.style.display = '';
    },

    file: function (index) {
        return this._queued_files[index];
    },

    _has_zip_file: function() {
        for (var i=0; i < this._queued_files.length; i++)
            if (this._queued_files[i].filename.match(/\.zip$/,'i'))
                return true;

        return false;
    },

    _hide_error: function () {
        $(this.element.fileError).style.display = 'none';
    },

    _hide_interface: function () {
        $(this.element.queueInterface).style.display = 'none';
        return false;
    },

    is_embed_checked: function() {
        return $(this.element.embedCheckbox).checked;
    },

    is_unpack_checked: function() {
        if (this._has_zip_file()) {
            return $(this.element.unpackCheckbox).checked;
        }
        else {
            return false;
        }
    },

    _queue_file: function () {
        var filenameField = $(this.element.filename);
        if (! filenameField.value) {
            this._show_error('Plese click "Browse" and select a file to upload.');
            return false;
        }

        var unpackCheckbox = $(this.element.unpackCheckbox);
        var embedCheckbox = $(this.element.embedCheckbox);
        var entry = {
            filename: filenameField.value,
            embed: embedCheckbox.checked,
            unpack: unpackCheckbox.checked,
            field: filenameField
        };

        this._queued_files.push(entry);
        filenameField.id = filenameField.id + '-' + this._sequence;
        this._sequence = this._sequence + 1;

        this._add_new_input();

        var holder = $(this.element.holder);
        holder.appendChild(filenameField);
        this._refresh_queue_list();
        return false;
    },

    _refresh_queue_list: function () {
        if (this._queued_files.length > 0) {
            var data = { queue: [] };
            for (var i=0; i < this._queued_files.length; i++)
                data.queue.push(this._queued_files[i].filename);
            this.jst.list.update(data);
            this.jst.list.show();
            Element.update(this.element.submitButton, 'Add another file');
            Element.update(this.element.embedMessage, 'Add links to these attachments at the top of the page? Images will appear in the page.');
            Element.update(this.element.unpackMessage, 'Expand zip archives and attach individual files to the page?');
            Element.update(this.element.message, 'Click "Browse" to find the file you want to upload. When you click "Add another file," these files will be added to the list of attachments for this page, and uploaded when you save the page.');
        }
        else {
            this.jst.list.clear();
            this.jst.list.hide();
            Element.update(this.element.submitButton, 'Add file');
            Element.update(this.element.embedMessage, 'Add a link to this attachment at the top of the page? Images will appear in the page.');
            Element.update(this.element.unpackMessage, 'Expand zip archive and attach individual files to the page?');
            Element.update(this.element.message, 'Click "Browse" to find the file you want to upload. When you click "Add file," this file will be added to the list of attachments for this page, and uploaded when you save the page.');
        }
        this._check_for_zip_file();
        return false;
    },

    remove_index: function (index) {
        this._queued_files.splice(index,1);
        this._refresh_queue_list();
    },

    reset_dialog: function () {
        this.clear_list();
        var embedCheckbox = $(this.element.embedCheckbox);
        embedCheckbox.checked = true;

    },

    _set_handlers_for_input: function () {
        if (! $(this.element.filename)) return;
        Event.observe(this.element.filename, 'blur',   this._check_for_zip_file.bind(this));
        Event.observe(this.element.filename, 'keyup',  this._check_for_zip_file.bind(this));
        Event.observe(this.element.filename, 'change', this._check_for_zip_file.bind(this));
    },

    _show_error: function (msg) {
        if (!msg)
            msg = '&nbsp;';
        Element.update(this.element.fileError, msg);
        $(this.element.fileError).style.display = 'block';
    },

    _update_uploaded_list: function (filename) {
        filename = filename.match(/^.+[\\\/]([^\\\/]+)$/)[1];
        this._uploaded_list.push(filename);
    },

    _loadInterface: function () {
        this.jst.list = new ST.TemplateField(this.element.listTemplate, this.element.fileList);

        if ($(this.element.editUploadButton)) {
            Event.observe(this.element.editUploadButton, 'click',  this._display_interface.bind(this));
        }
        if ($(this.element.closeButton)) {
            Event.observe(this.element.closeButton,      'click',  this._hide_interface.bind(this));
        }
        if ($(this.element.submitButton)) {
            Event.observe(this.element.submitButton,     'click',  this._queue_file.bind(this));
        }

        this._set_handlers_for_input();

        this._refresh_queue_list();
    }
};

// main
if (Socialtext.box_javascript) {
    window.EditQueue = new ST.AttachmentQueue ();
}
// BEGIN StTemplateField.js
/*
 * ST.TemplateField class
 *
 * This class wraps two DOM nodes. One node is a display node -- its content
 * is updated by the class. The other node contains the template (Trimpath)
 * used to generate the content for the display node.
 */
ST.TemplateField = function (template, target) {
    this._template_tag = template;
    this._update_tag = target;
    this._template_jst = this._JST(template);
};


ST.TemplateField.prototype = {
    _template_tag: '',
    _update_tag: '',
    _template_jst: '',

    clear: function () {
        Element.update(this._update_tag, '');
    },

    hide: function () {
        $(this._update_tag).style.display = 'none';
    },

    html: function (data) {
        return this._template_jst.process(data);
    },

    set_text: function (html) {
        Element.update(this._update_tag, html);
    },

    show: function () {
        $(this._update_tag).style.display = 'block';
    },

    update: function (data) {
        Element.update(this._update_tag, this.html(data));
    },

    _JST: function (elem) {
        return TrimPath.parseDOMTemplate(elem);
    }
};
// BEGIN tagqueue.js
if (typeof ST == 'undefined') {
    ST = {};
}

// ST.Attachments class
ST.TagQueue = function (args) {
    $H(args).each(this._applyArgument.bind(this));

    Event.observe(window, 'load', this._loadInterface.bind(this));
};


ST.TagQueue.prototype = {
    _queued_tags: [],
    suggestionRE: '',
    workspaceTags: [],

    element: {
        workspaceTags:      'st-tags-workspace',
        queueInterface:     'st-tagqueue-interface',

        editTagButton:      'st-edit-mode-tagbutton',
        submitButton:       'st-tagqueue-submitbutton',
        closeButton:        'st-tagqueue-closebutton',

        tagList:            'st-tagqueue-list',
        listTemplate:       'st-tagqueue-listtemplate',

        suggestions:        'st-tagqueue-suggestion',
        suggestionList:     'st-tagqueue-suggestionlist',
        suggestionTemplate: 'st-tagqueue-suggestiontemplate',

        holder:             'st-tagqueue-holder',

        tagField:           'st-tagqueue-field',
        message:            'st-tagqueue-message',
        error:              'st-tagqueue-error'
    },

    socialtextModifiers: {
        escapespecial : function(str) {
            var escapes = [
                { regex: /'/g, sub: "\\'" },
                { regex: /\n/g, sub: "\\n" },
                { regex: /\r/g, sub: "\\r" },
                { regex: /\t/g, sub: "\\t" }
            ];
            for (var i=0; i < escapes.length; i++)
                str = str.replace(escapes[i].regex, escapes[i].sub);
            return str;
        },
        quoter: function (str) {
            return str.replace(/"/g, '&quot;');
        },
        tagescapespecial : function(t) {
            var escapes = [
                { regex: /'/g, sub: "\\'" },
                { regex: /\n/g, sub: "\\n" },
                { regex: /\r/g, sub: "\\r" },
                { regex: /\t/g, sub: "\\t" }
            ];
            s = t.name;
            for (var i=0; i < escapes.length; i++)
                s = s.replace(escapes[i].regex, escapes[i].sub);
            return s;
        }
    },

    jst: {
        list: '',
        suggestion: ''
    },

    _applyArgument: function (arg) {
        if (typeof this[arg.key] != 'undefined') {
            this[arg.key] = arg.value;
        }
    },

    _hide_error: function () {
        Element.update(this.element.error, '&nbsp;');
        Element.hide(this.element.error);
    },

    clear_list: function () {
        this._queued_tags = [];
        this._refresh_queue_list();
    },

    _display_interface: function () {
        field = $(this.element.tagField);
        Try.these(function () {
            field.value = '';
        });

        this.workspaceTags  = JSON.parse($(this.element.workspaceTags).value);

        $(this.element.queueInterface).style.display = 'block';
        this._center_lightbox(this.element.queueInterface);
        this._refresh_queue_list();
        field.focus();
        return false;
    },

    _center_lightbox: function (parentElement) {
        var overlayElement = $('st-tagqueue-overlay');
        var element = $('st-tagqueue-dialog');
        Widget.Lightbox.show({
            divs: {
                wrapper: $(parentElement),
                background: overlayElement,
                contentWrapper: element.parentNode,
                content: element
            },
            effects: ['RoundedCorners']
        });
    },

    count: function () {
        return this._queued_tags.length;
    },

    tag: function (index) {
        return this._queued_tags[index];
    },

    _find_suggestions: function () {
        var field = $(this.element.tagField);

        if (field.value.length == 0) {
            Element.hide(this.element.suggestions);
        } else {
            if (this.workspaceTags.tags) {
                var expression = field.value;
                if (field.value.search(/ /) == -1) {
                    expression = '\\b'+expression;
                }
                this.suggestionRE = new RegExp(expression,'i');
                var suggestions = {
                    matches : this.workspaceTags.tags.grep(this.matchTag.bind(this))
                };
                Element.setStyle(this.element.suggestions, {display: 'block'});
                if (suggestions.matches.length > 0) {
                    suggestions._MODIFIERS = this.socialtextModifiers;
                    this.jst.suggestion.update(suggestions);
                } else {
                    var help = '<span class="st-tagqueue-nomatch">No matches</span>';
                    this.jst.suggestion.set_text(help);
                }
            }
        }
    },

    _hide_interface: function () {
        $(this.element.queueInterface).style.display = 'none';
        return false;
    },

    _clear_field: function () {
        var tag_field = $(this.element.tagField);
        tag_field.value = '';
        this._refresh_queue_list();
        Element.hide(this.element.suggestions);
        tag_field.focus();
        return false;
    },

    queue_tag: function (tag) {
        if (! tag) {
            this._show_error('No tag entered');
            return false;
        }
        this._queued_tags.push(tag);

        return this._clear_field();
    },

    _queue_tag: function () {
        var tag_field = $(this.element.tagField);
        return this.queue_tag(tag_field.value);
    },

    _refresh_queue_list: function () {
        if (this._queued_tags.length > 0) {
            var data = { queue: [] };
            for (var i=0; i < this._queued_tags.length; i++)
                data.queue.push(this._queued_tags[i]);
            this.jst.list.update(data);
            this.jst.list.show();
            Element.update(this.element.submitButton, 'Add another tag');
            Element.update(this.element.message, 'Enter a tag and click "Add another tag". The tag will be saved when you save the page.');
        }
        else {
            this.jst.list.clear();
            this.jst.list.hide();
            Element.update(this.element.submitButton, 'Add tag');
            Element.update(this.element.message, 'Enter a tag and click "Add tag". The tag will be saved when you save the page.');
        }
        this._hide_error();
        return false;
    },

    remove_index: function (index) {
        this._queued_tags.splice(index,1);
        this._refresh_queue_list();
    },

    reset_dialog: function () {
        this.clear_list();
    },

    matchTag: function (tag) {
        if (typeof tag.name == 'number') {
            var s = tag.name.toString();
            return s.search(this.suggestionRE) != -1;
        } else {
            return tag.name.search(this.suggestionRE) != -1;
        }
    },

    _set_first_matching_suggestion: function () {
        var field = $(this.element.tagField);

        if (field.value.length > 0) {
            var suggestions = this.workspaceTags.tags.grep(this.matchTag.bind(this));
            if ((suggestions.length >= 1) && (field.value != suggestions[0].name)) {
                field.value = suggestions[0].name;
                return false;
            }
        }
        return true;
    },

    tagFieldKeyHandler: function (event) {
        var e = event || window.event;
        var key = e.charCode || e.keyCode;

        if (key == Event.KEY_RETURN) {
            this._queue_tag();
            return false;
        }
        else if (key == Event.KEY_TAB) {
            var ret = this._set_first_matching_suggestion();
            try {
                event.preventDefault();
            }
            catch(e) {
            }
            try {
                event.stopPropagation();
            }
            catch(e) {
            }
            return ret;
        }
    },

    _show_error: function (msg) {
        if (!msg)
            msg = '&nbsp;';
        Element.update(this.element.error, msg);
        $(this.element.error).style.display = 'block';
    },

    _loadInterface: function () {
        this.jst.list = new ST.TemplateField(this.element.listTemplate, this.element.tagList);
        this.jst.suggestion = new ST.TemplateField(this.element.suggestionTemplate, this.element.suggestionList);

        if ($(this.element.editTagButton)) {
            Event.observe(this.element.editTagButton, 'click', this._display_interface.bind(this));
        }
        if ($(this.element.closeButton)) {
            Event.observe(this.element.closeButton, 'click', this._hide_interface.bind(this));
        }
        if ($(this.element.submitButton)) {
            Event.observe(this.element.submitButton, 'click', this._queue_tag.bind(this));
        }

        if ($(this.element.tagField)) {
            Event.observe(this.element.tagField, 'keyup', this._find_suggestions.bind(this));
            Event.observe(this.element.tagField, 'keydown', this.tagFieldKeyHandler.bind(this));
        }

        this._refresh_queue_list();
   }

};
// BEGIN Watchlist.js
// Watchlist
if (typeof ST == 'undefined') {
    ST = {};
}

ST.Watchlist = function() {};

ST.Watchlist.prototype = {
    isBeingWatched: false,
    image: null,

    button_activate: function () {
        if (!this.isBeingWatched) {
            this.image.src = this._image_src('hover');
        }
        return false;
    },

    button_default: function () {
        if (this.isBeingWatched) {
            this.image.src = this._image_src('on');
        }
        else {
            this.image.src = this._image_src('off');
        }
        return false;
    },

    _image_src: function(type) {
        return nlw_make_static_path(
            '/images/st/pagetools/watch-' + type + '.gif'
        );
    },

    _toggle_watch_state: function () {
        var wiki_id = Socialtext.wiki_id || Page.wiki_id;
        var action = (this.isBeingWatched) ? 'remove_from' : 'add_to';
        var page_id = this.page_id || Page.page_id;
        var uri = '/' + wiki_id + '/index.cgi' +
                  '?action=' + action + '_watchlist;page=' + page_id;

        var ar = new Ajax.Request (
            uri,
            {
                method: 'get',
                onComplete: (function (req) {
                    if (req.responseText == '1' || req.responseText == '0') {
                        this.isBeingWatched = ! this.isBeingWatched;
                        this.button_default();
                    } else {
                        this._display_toggle_error();
                    }
                }).bind(this),
                onFailure: (function(req, jsonHeader) {
                    this._display_toggle_error();
                }).bind(this)
            }
        );
    },

    _display_toggle_error: function () {
        if (this.isBeingWatched) {
            alert('Could not remove page from watchlist');
        }
        else {
            alert('Could not add page to watchlist');
        }
    },

    _applyArgument: function (arg) {
        if (typeof this[arg.key] != 'undefined') {
            this[arg.key] = arg.value;
        }
    },

    _loadInterface: function (indicator) {
        this.image = $(indicator);
        if (this.image) {
            if (this.image.src.match(/watch-on/)) {
                this.isBeingWatched = true;
            }
            else {
                this.isBeingWatched = false;
            }

            Event.observe(indicator,  'click', this._toggle_watch_state.bind(this));
            Event.observe(indicator,  'mouseover', this.button_activate.bind(this));
            Event.observe(indicator,  'mouseout', this.button_default.bind(this));
        }
    }
};
// BEGIN comment.js
if (typeof ST == 'undefined') {
    ST = {};
}

ST.Comment = function () {
    Event.observe(window, 'load', function () {
        var comment_button = $('st-comment-button-link');
        if (comment_button) {
            if (! comment_button.href.match(/#$/)) {
                return;
            }

            Event.observe('st-comment-button-link', 'click', function () {
                ST.Comment.launchCommentInterface({
                    page_name: Page.page_id,
                    action: 'display',
                    height: Page.comment_form_window_height
                });
                return false;
            });
            var below_fold_comment_link = $('st-edit-actions-below-fold-comment');
            if (below_fold_comment_link) {
                if (! below_fold_comment_link.href.match(/#$/)) {
                    return;
                }

                Event.observe('st-edit-actions-below-fold-comment', 'click', function () {
                    ST.Comment.launchCommentInterface({
                        page_name: Page.page_id,
                        action: 'display',
                        height: Page.comment_form_window_height
                    });
                    return false;
                });
            }
        }
    });
};

ST.Comment.launchCommentInterface = function (args) {
    var display_width = (window.offsetWidth || document.body.clientWidth || 600);
    var page_name     = args.page_name;
    var action        = args.action;
    var height        = args.height;
    var comment_window = window.open(
        'index.cgi?action=enter_comment;page_name=' + page_name + ';caller_action=' + action,
        '_blank',
        'toolbar=no, location=no, directories=no, status=no, menubar=no, titlebar=no, scrollbars=yes, resizable=yes, width=' + display_width + ', height=' + height + ', left=' + 50 + ', top=' + 200
    );

    if ( navigator.userAgent.toLowerCase().indexOf("safari") != -1 ) {
        window.location.reload();
    }

    return false;
};

Comment = new ST.Comment ();
// BEGIN revisions.js
function check_revisions(form) {
    var r1;
    var r2;

    var old_id = form.old_revision_id;
    if (old_id) {
        for (var i = 0; i < old_id.length; i++) {
            if (old_id[i].checked) {
               r1 = old_id[i].value;
            }
        }
    } else {
        r1 = -1;
    }

    var new_id = form.new_revision_id;
    if (new_id) {
        for (var i = 0; i < new_id.length; i++) {
            if (new_id[i].checked) {
               r2 = new_id[i].value;
            }
        }
    } else {
        r2 = -1;
    }

    if ((! r1) || (! r2)) {
        alert(loc('You must select two revisions to compare.'));
        return false;
    }

    if (r1 == r2) {
        alert(loc('You cannot compare a revision to itself.'));
        return false;
    }

    return true;
}
// BEGIN listview.js
/**
 * This class handles the JS needs for the page list view
 */

if (typeof ST == 'undefined') {
    ST = {};
}

ST.ListView = function (args) {
    $H(args).each(this._applyArgument.bind(this));

    Event.observe(window, 'load', this._loadInterface.bind(this));
};


ST.ListView.prototype = {
    unselectMessage : 'Unselect all pages',
    selectMessage : 'Select all pages',
    checkboxes : null,
    element: {
        selectToggle:   'st-listview-allpagescb',
        pdfExport:      'st-listview-submit-pdfexport',
        rtfExport:      'st-listview-submit-rtfexport',
        submitAction:   'st-listview-action',
        submitFilename: 'st-listview-filename',
        form:           'st-listview-form'
    },

    _stateOfAllPagesIs: function (STATE) {
        for (var i=0; i < this.checkboxes.length; i++)
            if (this.checkboxes[i].checked != STATE)
                return false;
        return true;
    },
    
    _atLeastOnePageSelected: function () {
        for (var i=0; i < this.checkboxes.length; i++)
            if (this.checkboxes[i].checked)
                return true;
        return false;
    },
    
    _getPdf: function () {
        if (!this._atLeastOnePageSelected()) {
            alert("You must check at least one page in order to create a PDF.");
        }
        else {
            $(this.element.submitAction).value = 'pdf_export';
            $(this.element.submitFilename).value = Socialtext.wiki_id + ".pdf";
            $(this.element.form).submit();
        }
    },

    _getRtf: function () {
        if (!this._atLeastOnePageSelected()) {
            alert("You must check at least one page in order to create a Word document.");
        }
        else {
            $(this.element.submitAction).value = 'rtf_export';
            $(this.element.submitFilename).value = Socialtext.wiki_id + ".rtf";
            $(this.element.form).submit();
        }
    },

    _toggleSelect: function () {
        var allToggle = $(this.element.selectToggle);

        this.checkboxes.each(
            function (checkbox) {
                checkbox.checked = allToggle.checked;
            }
        );
        allToggle.title = (allToggle.checked) ? this.unselectMessage : this.selectMessage;
    },

    _applyArgument: function (arg) {
        if (typeof this[arg.key] != 'undefined') {
            this[arg.key] = arg.value;
        }
    },

    _syncCheckAllCb: function() {
        var allToggle = $(this.element.selectToggle);

        var allSelected = this._stateOfAllPagesIs(true);

        allToggle.checked = allSelected;
        allToggle.title = allToggle.checked ? this.unselectMessage : this.selectMessage;
    },

    _loadInterface: function () {
        if ($(this.element.selectToggle)) {
            Event.observe(this.element.selectToggle, 'click', this._toggleSelect.bind(this));
        }
        if ($(this.element.pdfExport)) {
            Event.observe(this.element.pdfExport, 'click', this._getPdf.bind(this));
        }
        if ($(this.element.rtfExport)) {
            Event.observe(this.element.rtfExport, 'click', this._getRtf.bind(this));
        }

        this.checkboxes = document.getElementsByClassName('st-listview-selectpage-checkbox');
        for (var i=0; i < this.checkboxes.length; i++)
            Event.observe(this.checkboxes[i], 'click', this._syncCheckAllCb.bind(this));
   }
};

window.ListView = new ST.ListView ();
// BEGIN LookaheadWidget.js
/*
 * Abstract class for a lookahead widget. A lookahead widget watches an &lt;input&gt; field
 * and presents the user with a list of suggested possible matches. Suggestion list is retrieved
 * using AJAX and the REST API.
 *
 * AJAX calls are asyncronous so as to not lock the browser and prevent the user from typing.
 * I could not determine a way to cancel an existing AJAX call so the class tracks which
 * AJAX call is the <i>active</i>. The class makes sure the suggestion list only contains
 * suggestions from the active AJAX call.
 */


/**
 * Constructor
 *
 * @param dialog_window lightbox dialog window
 * @param api API call to populate lookup window
 * @param edit_field_id CSS id for the workspace edit field
 * @param window_class CSS class for the drop down windod which contains the
 * suggestion list
 * @param suggestion_block_class CSS class for the suggestion block
 * @param suggestion_class CSS class for each suggestion
 * @param variable_name JS variable associated with the object
 */
LookaheadWidget = function(dialog_window, api, edit_field_id, window_class, suggestion_block_class, suggestion_class, variable_name) {
    this.apiCall = api;
    this.editFieldId = edit_field_id;
    this.editField = $(edit_field_id);

    this.variableName = variable_name;
    this.activeTransport = null;
    this.suggestions = [];
    this.hasFocus = false;
    this.mouseInSuggestion = false;
    this.suggestionYOffset = 2;

    this.suggestionWindowClass = window_class;
    this.suggestionClass = suggestion_class;
    this.suggestionBlockClass = suggestion_block_class;

    this.suggestionWindow = null;
    this.suggestionBlock = null;
    this.dialogWindow = dialog_window;
    this.previousText = '';

    // We have our own auto-complete, disable the browser's version
    this.editField.setAttribute('autocomplete', 'off');

    this._hookInterface();
}

/**
 * Update the edit field with the suggestion selected by the user
 */
LookaheadWidget.prototype.acceptSuggestion = function(suggestion) {
    this.activeTransport = null;
    this._hideSuggestionBlock();
    this.editField.value = suggestion;
    this.previousText = suggestion;
    return false;
}

/**
 * Build the URI for the API call to retrieve the suggestion list
 * @return URI string
 */
LookaheadWidget.prototype._apiURI = function () {
    var uri = this.apiCall;
    var connector = '?';
    var parameters = [this._getOrder(), this._getFilter()];
    for (i=0; i < parameters.length; i++) {
        if (parameters[i] != '') {
            uri += connector + parameters[i];
            connector = ';';
        }
    }

    return uri;
}

/**
 * Create the suggestion window and populate it with the suggestions from the API call
 */
LookaheadWidget.prototype._createSuggestionBlock = function () {
    if (this.suggestionWindow)
        return;

    this.suggestionWindow = document.createElement('div');
    this.suggestionWindow.id = 'st-widget-lookahead-window';

    this.suggestionWindow.className = this.suggestionWindowClass;
    this.suggestionWindow.style.height = "0px";
    this.suggestionWindow.style.overflow = "hidden";
    this.suggestionWindow.style.display = 'none';

    this.suggestionBlock = document.createElement('div');
    this.suggestionBlock.id = 'st-widget-lookahead-suggestionblock';
    this.suggestionBlock.className = this.suggestionBlockClass;
    this.suggestionWindow.appendChild(this.suggestionBlock);

    this.dialogWindow.appendChild(this.suggestionWindow);

    Event.observe(this.suggestionWindow, 'mouseover', this._mouseInSuggestion.bind(this), false);
    Event.observe(this.suggestionWindow, 'mouseout', this._mouseLeavingSuggestion.bind(this), false);
}

/**
 * Delete the suggestion window
 */
LookaheadWidget.prototype._deleteSuggestionWindow = function () {
    if (!this.suggestionWindow)
        return;

    this.suggestionWindow.removeChild(this.suggestionBlock);
    this.suggestionWindow.parentNode.removeChild(this.suggestionWindow);
    this.suggestionBlock = null;
    this.suggestionWindow = null;
}

/**
 * Escape the suggestion text so it works with HTML
 * @return Escaped suggestion text
 */
LookaheadWidget.prototype._escapedSuggestion = function (suggestion) {
    var escapes = [
        { regex: /'/g, sub: "\\'" },
        { regex: /\n/g, sub: "\\n" },
        { regex: /\r/g, sub: "\\r" },
        { regex: /\t/g, sub: "\\t" }
    ];
    for (var i=0; i < escapes.length; i++)
        suggestion = suggestion.replace(escapes[i].regex, escapes[i].sub);
    return suggestion.replace(/"/g, '&quot;');
}

LookaheadWidget.prototype._editIsEmpty = function () {
    this.activeTransport = null;
    this.suggestions = [];
    this._hideSuggestionBlock();
}

/**
 * Call the API and fetch the suggestion list
 */
LookaheadWidget.prototype._findSuggestions = function () {
    if (this.editField.value.length == 0) {
        this._editIsEmpty();
    }
    else {
        if (this.previousText != this.editField.value) {
            this.previousText = this.editField.value;
            try {
                var uri = this._apiURI();
                var id = this.activeId;
                var aj = new Ajax.Request();
                var request = new Ajax.Request (
                    uri,
                    {
                        method: 'get',
                        requestHeaders: ['Accept','text/plain'],
                        onComplete: (function (req) {
                            this.populateSuggestion(req);
                        }).bind(this),
                        onFailure: (function(req, jsonHeader) {
                        }).bind(this)
                    }
                );
                this.activeTransport = request.transport;
            }
            catch(e) {
                // XXX Ignore any error?
            }
        }
    }
}

/**
 * Called when the edit control gains focus.
 */
LookaheadWidget.prototype._gainFocus = function () {
    if (!this.hasFocus) {
        this.hasFocus = true;
        this.activeTransport = null;
        this._createSuggestionBlock();
        this._findSuggestions();
    }
},

/**
 * Build the filter criteria for the API call
 * @return Filter criteria string for the API URI
 */
LookaheadWidget.prototype._getFilter = function () {
    var filter = this.editField.value;
    filter = filter.replace(/^\s+/,'');
    filter = filter.replace(/ /g, '.*');
    return 'filter=\\b'+this.editField.value;
}

/**
 * Get the order clause for the API call. Default order is alpha
 * @return Order criteria string for the API URI
 */
LookaheadWidget.prototype._getOrder = function () {
    return 'order=alpha';
}

/**
 * Hide the suggestion window
 */
LookaheadWidget.prototype._hideSuggestionBlock = function () {
    this.suggestionBlock.innerHTML = '';
    this.suggestionWindow.style.overflow = 'hidden';
    this.suggestionWindow.style.display = 'none';
    this.editField.focus();
}

/**
 * Add the JS event observers for the &lt;input&gt; field
 */
LookaheadWidget.prototype._hookInterface = function () {
    if ($(this.editFieldId)) {
        Event.observe(this.editFieldId, 'keyup', this._findSuggestions.bind(this));
        Event.observe(this.editFieldId, 'keydown', this._keyHandler.bind(this));
        Event.observe(this.editFieldId, 'blur', this._loseFocus.bind(this));
        Event.observe(this.editFieldId, 'focus', this._gainFocus.bind(this));
    }
}

/**
 * Called when a key is pressed when the edit field has the focus
 * @param event JS event object
 */
LookaheadWidget.prototype._keyHandler = function (event) {
    var e = event || window.event;
    var key = e.charCode || e.keyCode;

    if (key == Event.KEY_TAB && this._suggestionsDisplayed()) {
        this._hideSuggestionBlock();
        var ret = this._setFirstMatchingSuggestion();
    }
}

/**
 * Called when the input field loses focus. Default action is to hide the suggestion window
 */
LookaheadWidget.prototype._loseFocus = function() {
    if (this.hasFocus && !this.mouseInSuggestion) {
        this.hasFocus = false;
        this._deleteSuggestionWindow();
        this.activeTransport = null;
    }
}

/**
 * Called when the mouse enters the suggestion window.
 *
 * We need to track if the mouse is in the suggestion window to handle focus change. If
 * the mouse is in the suggestion window we don't want to hide the window from the user.
 */
LookaheadWidget.prototype._mouseInSuggestion = function() {
    this.mouseInSuggestion = true;
}

/**
 * Called when the mouse leaves the suggestion window.
 *
 * We need to track if the mouse is in the suggestion window to handle focus change. If
 * the mouse is in the suggestion window we don't want to hide the window from the user.
 */
LookaheadWidget.prototype._mouseLeavingSuggestion = function() {
    this.mouseInSuggestion = false;
}

/**
 * Parse the API return and build the suggestion list
 *
 * The suggestion list is cleared if it only contains one suggestion which matches
 * the contents of the edit field. No use showing the user what they have already typed.
 */
LookaheadWidget.prototype._parseSuggestionList = function(suggestions_text) {
    var text = trim(suggestions_text);
    if (text.length == 0)
        this.suggestions = [];
    else {
        this.suggestions = text.split("\n");
        while (this.suggestions[this.suggestions.length -1] == '')
            this.suggestions.pop();
    }
    if (this.suggestions.length == 1 && this.suggestions[0] == this.editField.value)
        this.suggestions.pop();
}

LookaheadWidget.prototype.isValidTransport = function(request) {
    if ((this.activeTransport != null && request != this.activeTransport) || !this.hasFocus)
        return false;
    else
        return true;
}

/**
 * Build the suggestion window and populate it with the suggestions from the API call
 */
LookaheadWidget.prototype.populateSuggestion = function(request) {

    if (!this.isValidTransport(request))
        return;

    if (request.status != 200) {
        if (request.status == 404) {
            this.suggestionBlock.innerHTML = this._error404Message();
        }
        else {
            this.suggestionBlock.innerHTML = this._apiErrorMessage();
        }
        this._showSuggestionBlock();
        return;
    }

    this._parseSuggestionList(request.responseText);

    if (this.suggestions.length == 0) {
        this.suggestionBlock.innerHTML = '';
        this._hideSuggestionBlock();
        return;
    }

    var suggestions_text = '';
    for (var i=0; i < this.suggestions.length; i++) {
        suggestions_text +=
            '<span class="' +
            this.suggestionClass +
            '"><a href="#" onclick="return ' + this.variableName + '.acceptSuggestion(\'' +
            this._escapedSuggestion(this.suggestions[i]) +
            '\')">' +
            this.suggestions[i] +
            '</a>';
        if (i != this.suggestions.length - 1)
            suggestions_text += ',';
        suggestions_text += '</span> ';
    }
    this.suggestionBlock.innerHTML = suggestions_text;
    this._showSuggestionBlock();
}

/**
 * Select the first suggestion and update the edit field. This method is called if the user
 * presses tab while the suggestion window is displayed
 */
LookaheadWidget.prototype._setFirstMatchingSuggestion = function () {
    if (this.editField.value.length > 0 && this.suggestions.length > 0) {
        this.editField.value = this.suggestions[0];
        this._hideSuggestionBlock();
    }
    return true;
}

/**
 * Size, position, and display the suggestion window
 */
LookaheadWidget.prototype._showSuggestionBlock = function () {
    this.suggestionWindow.style.display = 'block';
    this.suggestionWindow.height = '1px';
    this.suggestionWindow.style.overflow = 'hidden';
    this.suggestionWindow.style.position = 'absolute';

    this.suggestionWindow.style.left = ST.getDocumentX(this.editField,true) + "px";
    this.suggestionWindow.style.top =
        ST.getDocumentY(this.editField,true) +
        this.editField.offsetHeight +
        this.suggestionYOffset + "px";
    this.suggestionWindow.style.width = this.editField.offsetWidth + "px";
    if (this.suggestionBlock.offsetHeight > 200) {
        this.suggestionWindow.style.height = "200px";
    }
    else {
        this.suggestionWindow.style.height = this.suggestionBlock.offsetHeight + 2 + "px";
    }
    this.suggestionWindow.style.overflow = "auto";
}

/**
 * Determine if the suggestion window is being displayed
 *
 * @return bool
 */
LookaheadWidget.prototype._suggestionsDisplayed = function (message) {
    return this.suggestionWindow.offsetHeight != 0;
}

/**
 * Replace tokens in the API URI with the appropriate values
 *
 * @return modified API URI
 */
LookaheadWidget.prototype._tokenReplace = function(command, token, value) {
    if (!this.workspace)
        throw URIError('No workspace to query');

    var re = new RegExp(token);
    if (command.match(re))
        command = command.replace(re, value);

    return command;
}
// BEGIN WorkspaceSupportLookahead.js
/**
 * Abstract class for lookahead widgets whose suggestions are workspace specific (such as page name).
 *
 * @see LookaheadWidget
 * @see ST.extend
 */


/**
 * Constructor
 *
 * @param dialog_window lightbox dialog window
 * @param api API call to retrieve suggestion list
 * @param edit_field_id CSS id for the workspace edit field
 * @param window_class CSS class for the drop down windod which contains the suggestion list
 * @param suggestion_block_class CSS class for the suggestion block
 * @param suggestion_class CSS class for each suggestion
 * @param variable_name JS variable associated with the object
 * @param widget Wikiwyg widget
 */
WorkspaceSupportLookahead = function(dialog_window, api, edit_field_id, window_class, suggestion_block_class, suggestion_class, variable_name, widget) {
	WorkspaceSupportLookahead.baseConstructor.call(
        this,
        dialog_window,
        api,
        edit_field_id,
		window_class,
		suggestion_block_class,
		suggestion_class,
        variable_name
    );
    this.workspace = '';
    this.workspaceWidget = widget;
    this.defaultWorkspace = '';
};

ST.extend(WorkspaceSupportLookahead, LookaheadWidget);

WorkspaceSupportLookahead.prototype.currentWorkspaceSelected = function () {
    var nodes = document.getElementsByName('st-rb-workspace_id');
    for (var i = 0; i < nodes.length; i++)
        if (nodes[i].checked)
            return nodes[i].value == 'current';
    return false;
}

/**
 * Get latest workspace data when control gains focus
 */
WorkspaceSupportLookahead.prototype._gainFocus = function() {
    this.workspace = this.defaultWorkspace;
    if (!this.currentWorkspaceSelected())
        if (this.workspaceWidget && this.workspaceWidget.title_and_id.workspace_id.id)
            this.workspace = this.workspaceWidget.title_and_id.workspace_id.id;

    WorkspaceSupportLookahead.superClass._gainFocus.call(this)
},

/**
 * Message to return when a 404 status code is returned by the API
 * @return Error message in HTML format
 */
WorkspaceSupportLookahead.prototype._error404Message = function() {
    return '<span class="st-suggestion-warning">Workspace "' + this.workspace + '" does not exist on wiki</span>';
}

/**
 * Build the URI for the API call
 * @return URI for API call
 */
WorkspaceSupportLookahead.prototype._apiURI = function() {
    var uri = WorkspaceSupportLookahead.superClass._apiURI.call(this)
    return this._tokenReplace(uri, ':ws', this.workspace);
}
// BEGIN WorkspaceLookahead.js
/**
 * This class implements a workspace lookahead widget.
 *
 * @see LookaheadWidget
 * @see ST.Extend
 */

/**
 * Constructor
 *
 * @param dialog_window lightbox dialog window
 * @param edit_field_id CSS id for the workspace edit field
 * @param window_class CSS class for the drop down windod which contains the
 * suggestion list
 * @param suggestion_block_class CSS class for the suggestion block
 * @param suggestion_class CSS class for each suggestion
 * @param variable_name JS variable associated with the object
 * @param widget Wikiwyg widget
 */
WorkspaceLookahead = function(dialog_window, edit_field_id, window_class, suggestion_block_class, suggestion_class, variable_name, widget) {
    WorkspaceLookahead.baseConstructor.call(
        this,
        dialog_window,
        '/data/workspaces',
        edit_field_id,
        window_class,
        suggestion_block_class,
        suggestion_class,
        variable_name
    );
    this.widget = widget;
    this.setTitleFromId();
    this.perfectMatch = false;
};

ST.extend(WorkspaceLookahead, LookaheadWidget);

/**
 * Update the wikiwyg widget and the workspace edit field with the user selection
 */
WorkspaceLookahead.prototype.acceptSuggestion = function(suggestion) {
    this.activeTransport = null;
    this._hideSuggestionBlock();
    this.widget.title_and_id.workspace_id.id = suggestion;
    this.widget.title_and_id.workspace_id.title = this.getTitleFromName(suggestion);
    this.editField.value = this.widget.title_and_id.workspace_id.title;
    this.previousText = this.widget.title_and_id.workspace_id.title;
    return false;
}

/**
 * Retrieves the title for a workspace name from the suggestion list returned
 * by the API.
 *
 * @param name workspace name
 * @return workspace title
 */
WorkspaceLookahead.prototype.getTitleFromName = function(name) {
    var title = '';
    for (var i=0; i < this.suggestions.length; i++) {
        if (this.suggestions[i].name == name) {
            title = this.suggestions[i].title;
            break;
        }
    }

    return title;
}

/**
 * Message to display when an API error occurs
 * @return Error message in HTML format
 */
WorkspaceLookahead.prototype._apiErrorMessage = function() {
    return '<span class="st-suggestion-warning">Could not retrieve workspace list from wiki</span>';
}

/**
 * Message to return when a 404 status code is returned by the API
 * @return Error message in HTML format
 */
WorkspaceLookahead.prototype._error404Message = function() {
    return this._apiErrorMessage();
}

/**
 * If the user cleared the workspace edit field reset the value to default
 * @return Nothing
 */
WorkspaceLookahead.prototype._editIsEmpty = function () {
    this.widget.title_and_id.workspace_id.id = '';
    this.widget.title_and_id.workspace_id.title = '';
    WorkspaceLookahead.superClass._editIsEmpty.call(this);
}

/**
 * Fetch the list of workspaces that match the user's string
 */
WorkspaceLookahead.prototype._findSuggestions = function () {
    if (this.editField.value.length == 0) {
        this._editIsEmpty();
    }
    else {
        if (this.previousText != this.editField.value) {
            this.previousText = this.editField.value;
            var uri = this._apiURI();
            var id = this.activeId;
            var aj = new Ajax.Request();
            var request = new Ajax.Request (
                uri,
                {
                    method: 'get',
                    requestHeaders: ['Accept','application/json'],
                    onComplete: (function (req) {
                        this.populateSuggestion(req);
                    }).bind(this),
                    onFailure: (function(req, jsonHeader) {
                        // XXX Need an error messaage
                    }).bind(this)
                }
            );
            this.activeTransport = request.transport;
        }
    }
}

/**
 * Since only the id for the workspace is saved with the widget
 * we need to pull the name of the workspace to display to the
 * end user
 * @return Nothing
 */
WorkspaceLookahead.prototype.setTitleFromId = function () {
    var radioName = this.editFieldId + '-rb';
    if (!this.widget.title_and_id.workspace_id.id) {
        ST.setRadioValue(radioName, 'current');
    }
    else {
        ST.setRadioValue(radioName, 'other');
        this.editField.value = this.widget.title_and_id.workspace_id.title;
    }
}

/**
 * Build the title filter for the workspace API call
 * @return Filter clause of the API call
 */
WorkspaceLookahead.prototype._getFilter = function () {
    var filter = this.editField.value;
    filter = filter.replace(/^\s+/,'');
    filter = filter.replace(/ /g, '.*');
    return 'title_filter=\\b'+this.editField.value;
}

/**
 * Parse the API return and build out the suggestion list. The suggestion
 * list is cleared if only one suggestion is returned and it matches what the
 * user has entered. This prevents the lookahead component from displaying the
 * single suggestion in the dropdown list.
 */
WorkspaceLookahead.prototype._parseSuggestionList = function(suggestions_text) {
    this.suggestions = [];
    var text = trim(suggestions_text);
    if (text.length != 0)
        this.suggestions = JSON.parse(text);

    var re = new RegExp('^'+this.editField.value+'$', 'i');
    if (this.suggestions.length == 1 && this.suggestions[0].title.match(re)) {
        this.widget.title_and_id.workspace_id.id = this.suggestions[0].name;
        this.suggestions.pop();
        this.perfectMatch = true;
    }
    else
        this.perfectMatch = false;
}

/**
 * Called by the AJAX request. Parse the return from the AJAX call and display
 * the suggestion window if required.
 */
WorkspaceLookahead.prototype.populateSuggestion = function(request) {
    if (!this.isValidTransport(request))
        return;

    if (request.status != 200) {
        if (request.status == 404) {
            this.suggestionBlock.innerHTML = this._error404Message();
        }
        else {
            this.suggestionBlock.innerHTML = this._apiErrorMessage();
        }
        this._showSuggestionBlock();
        return;
    }

    this._parseSuggestionList(request.responseText);
    if (!this.hasFocus) {
        this.activeTransport = null;
        return;
    }

    if (this.suggestions.length == 0) {
        if (!this.perfectMatch) {
            this.widget.title_and_id.workspace_id.id = this.editField.value;
            this.widget.title_and_id.workspace_id.title = this.editField.value;
        }
        this.suggestionBlock.innerHTML = '';
        this._hideSuggestionBlock();
        return;
    }

    var suggestions_text = '';
    for (var i=0; i < this.suggestions.length; i++) {
        suggestions_text +=
            '<span class="' +
            this.suggestionClass +
            '"><a href="#" onclick="return ' + this.variableName + '.acceptSuggestion(\'' +
            this._escapedSuggestion(this.suggestions[i].name) +
            '\')">' +
            this.suggestions[i].title + ' (' + this.suggestions[i].name + ')' +
            '</a>';
        if (i != this.suggestions.length - 1)
            suggestions_text += ',';
        suggestions_text += '</span> ';
    }

    if (this.suggestionBlock == null)
        this._createSuggestionBlock();

    this.suggestionBlock.innerHTML = suggestions_text;

    this._showSuggestionBlock();
}

/**
 * If the user types in the workspace field then we automatically select the 'custom' radio button
 */
WorkspaceLookahead.prototype._keyHandler = function (event) {
    var radioName = this.editFieldId + '-rb';
    ST.setRadioValue(radioName, 'other');
    WorkspaceLookahead.superClass._keyHandler.call(this, event);
}

/**
 * Selects the first available suggestion. Called when the user presses tab and
 * the suggestion window is visible.
 * @return true
 */
WorkspaceLookahead.prototype._setFirstMatchingSuggestion = function () {
    if (this.editField.value.length > 0 && this.suggestions.length > 0) {
        this.acceptSuggestion(this.suggestions[0].name);
    }
    return true;
}

WorkspaceLookahead.prototype.isValidTransport = function(request) {
    if ((this.activeTransport != null && request != this.activeTransport))
        return false;
    else
        return true;
}

/**
 * We need to override the default handling to capture the last call so we can update
 * the ID if appropriate
 */
WorkspaceLookahead.prototype._loseFocus = function() {
    if (this.hasFocus && !this.mouseInSuggestion) {
        this.hasFocus = false;
        this._deleteSuggestionWindow();
//        this.activeTransport = null;
    }
}
// BEGIN PageNameLookahead.js
/**
 * This class handles look ahead for page names. The class supports specifying a workspace
 * will pull page names from that workspace.
 */

// namespace placeholder
if (typeof ST == 'undefined') {
    ST = {};
}

ST.lookaheadCache = { workspacePageCount: {} };

/**
 * Constructor
 *
 * @param dialog_window lightbox dialog window
 * @param edit_field_id CSS id for the input tag
 * @param window_class CSS class to apply to the div for the suggestion window
 * @param suggestion_block_class CSS class for the div that holds the suggestion list
 * @param suggestion_class CSS class for a suggestion
 * @param variable_name name of JS variable that holds the object
 * @param workspace_id CSS id for the workspace input tag
 */
PageNameLookahead = function(dialog_window, edit_field_id, window_class, suggestion_block_class, suggestion_class, variable_name, workspace_id) {
    PageNameLookahead.baseConstructor.call(
        this,
        dialog_window,
        '/data/workspaces/:ws/pages',
        edit_field_id,
        window_class,
        suggestion_block_class,
        suggestion_class,
        variable_name,
        workspace_id
    );

    this.lastEditLength = 0;
    this.minEditLengthForLookup = 1;
    var radioName = this.editFieldId + '-rb';
    this.setMinEditLengthForLookup();

    if (this.editField.value.length == 0)
        ST.setRadioValue(radioName, 'current');
    else
        ST.setRadioValue(radioName, 'other');
};

ST.extend(PageNameLookahead, WorkspaceSupportLookahead);

/**
 * Override the _get_order method to return an empty string; the sections API call returns
 * items in page order by default.
 *
 * @return blank string
 */
PageNameLookahead.prototype._apiErrorMessage = function() {
    return '<span class="st-suggestion-warning">Could not retrieve page list from wiki</span>';
}

PageNameLookahead.prototype.getPageCountForWorkspace = function() {
    if (this.workspace == '')
        return 1;
    if (this.workspace in ST.lookaheadCache.workspacePageCount)
        return ST.lookaheadCache.workspacePageCount[this.workspace];

    var uri = '/data/workspaces/'+this.workspace+'/tags/recent changes';

    var request = new Ajax.Request (
        uri,
        {
            method: 'get',
            asynchronous: false,
            requestHeaders: ['Accept','application/json']
        }
    );

    if (request.transport.status == 200) {
        var details = JSON.parse(request.transport.responseText);
        ST.lookaheadCache.workspacePageCount[this.workspace] = details.page_count;
        return details.page_count;
    }

    return 0;
}

PageNameLookahead.prototype.setMinEditLengthForLookup = function() {
    var pageCount = this.getPageCountForWorkspace();
    if (pageCount < 5000)
        this.minEditLengthForLookup = 1;
    else if (pageCount < 10000)
        this.minEditLengthForLookup = 2;
    else
        this.minEditLengthForLookup = 3;
}

/**
 * We auto-select the current page radio button when the user clears the page title field
 */
PageNameLookahead.prototype._editIsEmpty = function () {
    PageNameLookahead.superClass._editIsEmpty.call(this);
}

/**
 * If the user types in the page title field then we automatically select the 'custom' radio button
 */
PageNameLookahead.prototype._keyHandler = function (event) {
    var radioName = this.editFieldId + '-rb';
    ST.setRadioValue(radioName, 'other');
    PageNameLookahead.superClass._keyHandler.call(this, event);
}

/**
 * We only want to handle a lookahead if the user has typed a minimum number of characters
 */
PageNameLookahead.prototype._findSuggestions = function () {
    if (this.editField.value.length == 0 || this.editField.value.length >= this.minEditLengthForLookup) {
        if (this.lastEditLength > 0 && this.lastEditLength < this.minEditLengthForLookup)
            this.suggestionBlock.innerHTML = '<span class="st-lookahead-info">Searching for matching pages...</span>';
        PageNameLookahead.superClass._findSuggestions.call(this);
    }
    else {
        this.suggestionBlock.innerHTML = '<span class="st-lookahead-info">Page title lookahead requires at least ' + this.minEditLengthForLookup + ' characters</span>';
        this._showSuggestionBlock();
    }
    this.lastEditLength = this.editField.value.length;
}

/**
 * Get latest workspace data when control gains focus
 */
PageNameLookahead.prototype._gainFocus = function() {
    PageNameLookahead.superClass._gainFocus.call(this)
    this.setMinEditLengthForLookup();
}
// BEGIN TagLookahead.js
/**
 * Class to implement a tag name lookahead widget
 *
 * @see WorkspaceSupportLookahead
 * @see ST.extend
 */


/**
 * Constructor
 *
 * @param dialog_window lightbox dialog window
 * @param edit_field_id CSS id for the input tag
 * @param window_class CSS class to apply to the div for the suggestion window
 * @param suggestion_block_class CSS class for the div that holds the suggestion list
 * @param suggestion_class CSS class for a suggestion
 * @param variable_name name of JS variable that holds the object
 * @param workspace_id CSS id for the workspace edit field
 *
 */
TagLookahead = function(dialog_window, edit_field_id, window_class, suggestion_block_class, suggestion_class, variable_name, workspace_id) {
	TagLookahead.baseConstructor.call(
        this,
        dialog_window,
        '/data/workspaces/:ws/tags',
        edit_field_id,
		window_class,
		suggestion_block_class,
		suggestion_class,
		variable_name,
        workspace_id
    );
};

ST.extend(TagLookahead, WorkspaceSupportLookahead);

/**
 * Message to display when an API error occurs
 * @return Error message in HTML format
 */
TagLookahead.prototype._apiErrorMessage = function() {
    return '<span class="st-suggestion-warning">Could not retrieve tag list from wiki</span>';
}

/**
 * Get the sort order for the suggestions
 * @return sort order parameter string for the API call
 */
TagLookahead.prototype._getOrder = function () {
    return 'order=weighted';
}
// BEGIN WeblogLookahead.js
/**
 * This class handles look ahead for Weblog name fields. This is a tag look ahead with a
 * different filter (tags must end with blog
 *
 * @see TagLookahead
 * @see ST.extend
 */

/**
 * Constructor
 *
 * @param dialog_window lightbox dialog window
 * @param edit_field_id CSS id for the input tag
 * @param window_class CSS class to apply to the div for the suggestion window
 * @param suggestion_block_class CSS class for the div that holds the suggestion list
 * @param suggestion_class CSS class for a suggestion
 * @param variable_name name of JS variable that holds the object
 * @param workspace_id CSS id for the workspace edit field
 *
 */
WeblogLookahead = function(dialog_window, edit_field_id, window_class, suggestion_block_class, suggestion_class, variable_name, workspace_id) {
	WeblogLookahead.baseConstructor.call(
        this,
        dialog_window,
        edit_field_id,
		window_class,
		suggestion_block_class,
		suggestion_class,
		variable_name,
        workspace_id
    );
};

ST.extend(WeblogLookahead, TagLookahead);

/**
 * Constructs the regex used to filter the tag list
 *
 * @return filter criteria string
 */
WeblogLookahead.prototype._getFilter = function () {
    return 'filter=\\b'+this.editField.value+'.*(We)?blog$';
}

/**
 * Messge to display in case of an API error
 *
 * @return html string
 */
WeblogLookahead.prototype._apiErrorMessage = function() {
    return '<span class="st-suggestion-warning">Could not retrieve weblog list from wiki</span>';
}
// BEGIN PageNameSupportLookahead.js
/**
 * This class is a base class for all look ahead widgets that pull suggestions from a specific
 * wiki page. The class supports specifying workspace and page name input fields and will use
 * that information when pulling suggestions.
 *
 * You can set the default workspace id using the workspace data member
 *
 * You can set the default page name using the pagename data member
 *
 * @see LookaheadWidget
 * @see ST.extend
 */

/**
 * Constructor
 *
 * @param dialog_window lightbox dialog window
 * @param edit_field_id CSS id for the input tag
 * @param window_class CSS class to apply to the div for the suggestion window
 * @param suggestion_block_class CSS class for the div that holds the suggestion list
 * @param suggestion_class CSS class for a suggestion
 * @param variable_name name of JS variable that holds the object
 * @param workspace_widget Wikiwyg Workspace widget object
 * @param pagename_id CSS id for the page name input tag
 */
PageNameSupportLookahead = function(dialog_window, api, edit_field_id, window_class, suggestion_block_class, suggestion_class, variable_name, workspace_widget, pagename_id) {
	PageNameSupportLookahead.baseConstructor.call(
        this,
        dialog_window,
        api,
        edit_field_id,
        window_class,
        suggestion_block_class,
        suggestion_class,
        variable_name
    );
    this.workspace = '';
    this.workspaceWidget = workspace_widget;
    this.defaultWorkspace = '';

    this.pagename = '';
    this.pagenameId = pagename_id;
    this.defaultPagename = '';
};

ST.extend(PageNameSupportLookahead, LookaheadWidget);

PageNameSupportLookahead.prototype.currentWorkspaceSelected = function () {
    var nodes = document.getElementsByName('st-rb-workspace_id');
    for (var i = 0; i < nodes.length; i++)
        if (nodes[i].checked)
            return nodes[i].value == 'current';
    return false;
}

PageNameSupportLookahead.prototype.currentPageSelected = function () {
    var nodes = document.getElementsByName('st-rb-page_title');
    for (var i = 0; i < nodes.length; i++)
        if (nodes[i].checked)
            return nodes[i].value == 'current';
    return false;
}

/**
 * When the edit field gains focus update the workspace and page name fields
 * from the values in the form
 */
PageNameSupportLookahead.prototype._gainFocus = function() {
	try {
		this.workspace = this.defaultWorkspace;
	    if (!this.currentWorkspaceSelected())
	        if (this.workspaceWidget && this.workspaceWidget.title_and_id.workspace_id.id)
	            this.workspace = this.workspaceWidget.title_and_id.workspace_id.id;

		this.pagename = this.defaultPagename;
	    if (!this.currentPageSelected())
			if (this.pagenameId && trim($(this.pagenameId).value))
				this.pagename = trim($(this.pagenameId).value);
	}
	catch(e) {
		this.pagename = '';
		this.workspace = '';
	}
    PageNameSupportLookahead.superClass._gainFocus.call(this)
},

/**
 * Get the error message to display when the API returns a 404 error
 * @return error message in HTML format
 */
PageNameSupportLookahead.prototype._error404Message = function() {
    return '<span class="st-suggestion-warning">Workspace "' + this.workspace + '" or page"' + this.pagename + '" does not exist on wiki</span>';
}

/**
 * Build the URI for the API call
 * @return URI
 */
PageNameSupportLookahead.prototype._apiURI = function() {
    var uri = PageNameSupportLookahead.superClass._apiURI.call(this)
    uri = this._tokenReplace(uri, ':ws', this.workspace);
    return this._tokenReplace(uri, ':pname', this.pagename);
}
// BEGIN PageSectionLookahead.js
/**
 * This class handles look ahead for page sections. The class supports specifying workspace
 * and page edit fields and will use those values when pulling page sections.
 *
 * @see PageNameSupportLookahead
 * @see ST.extend
 */

/**
 * Constructor
 *
 * @param dialog_window lightbox dialog window
 * @param edit_field_id CSS id for the input tag
 * @param window_class CSS class to apply to the div for the suggestion window
 * @param suggestion_block_class CSS class for the div that holds the suggestion list
 * @param suggestion_class CSS class for a suggestion
 * @param variable_name name of JS variable that holds the object
 * @param workspace_id CSS id for the workspace input tag
 * @param pagename_id CSS id for the page name input tag
 */
PageSectionLookahead = function(dialog_window, edit_field_id, window_class, suggestion_block_class, suggestion_class, variable_name, workspace_id, pagename_id) {
	PageSectionLookahead.baseConstructor.call(
        this,
        dialog_window,
        '/data/workspaces/:ws/pages/:pname/sections',
        edit_field_id,
		window_class,
		suggestion_block_class,
		suggestion_class,
        variable_name,
        workspace_id,
        pagename_id
    );
};

ST.extend(PageSectionLookahead, PageNameSupportLookahead);

/**
 * Messge to display in case of an API error
 *
 * @return html string
 */
PageSectionLookahead.prototype._apiErrorMessage = function() {
    return '<span class="st-suggestion-warning">Could not retrieve section list from wiki</span>';
}

/**
 * Override the _getOrder method to return an empty string; the sections API call returns
 * items in page order by default.
 *
 * @return blank string
 */
PageSectionLookahead.prototype._getOrder = function () {
    return '';
}
// BEGIN PageAttachmentLookahead.js
/**
 * This class handles look ahead for page attachments. The class supports specifying workspace
 * and page edit fields and will use those values when pulling attachments.
 *
 * @see PageNameSupportLookahead
 * @see ST.extend
 */

/**
 * Constructor
 *
 * @param dialog_window lightbox dialog window
 * @param edit_field_id CSS id for the input tag
 * @param window_class CSS class to apply to the div for the suggestion window
 * @param suggestion_block_class CSS class for the div that holds the suggestion list
 * @param suggestion_class CSS class for a suggestion
 * @param variable_name name of JS variable that holds the object
 * @param workspace_id CSS id for the workspace input tag
 * @param pagename_id CSS id for the page name input tag
 */
PageAttachmentLookahead = function(dialog_window, edit_field_id, window_class, suggestion_block_class, suggestion_class, variable_name, workspace_id, pagename_id) {
	PageAttachmentLookahead.baseConstructor.call(
        this,
        dialog_window,
        '/data/workspaces/:ws/pages/:pname/attachments',
        edit_field_id,
		window_class,
		suggestion_block_class,
		suggestion_class,
        variable_name,
        workspace_id,
        pagename_id
    );
};

ST.extend(PageAttachmentLookahead, PageNameSupportLookahead);

/**
 * Messge to display in case of an API error
 *
 * @return html string
 */
PageAttachmentLookahead.prototype._apiErrorMessage = function() {
    return '<span class="st-suggestion-warning">Could not retrieve attachment list from wiki</span>';
}
// BEGIN startup.js

if (Socialtext.box_javascript) {
    createPageObject();
    window.Attachments = new ST.Attachments ();
    window.Tags = new ST.Tags ();
    window.TagQueue = new ST.TagQueue ();
    window.Watchlist = new ST.Watchlist();
    Event.observe(window, 'load',
        function() {
            window.Watchlist._loadInterface('st-watchlist-indicator');
        }
    );
}

window.NavBar = new ST.NavBar ();

Event.observe(window, 'load', function() {
    var toggles = document.getElementsByClassName('watchlist-list-toggle');
    for (var ii = 0; ii < toggles.length; ii++) {
        var toggle = toggles[ii];
        var page_id = toggle.getAttribute('alt');
        var wl = new ST.Watchlist();
        wl.page_id = page_id;
        wl._loadInterface(toggle);
    }
});
// BEGIN ../../../js-modules/Wikiwyg-copy/lib/Wikiwyg.js
/*==============================================================================
Wikiwyg - Turn any HTML div into a wikitext /and/ wysiwyg edit area.

DESCRIPTION:

Wikiwyg is a Javascript library that can be easily integrated into any
wiki or blog software. It offers the user multiple ways to edit/view a
piece of content: Wysiwyg, Wikitext, Raw-HTML and Preview.

The library is easy to use, completely object oriented, configurable and
extendable.

See the Wikiwyg documentation for details.

AUTHORS:

    Ingy döt Net <ingy@cpan.org>
    Casey West <casey@geeknest.com>
    Chris Dent <cdent@burningchrome.com>
    Matt Liggett <mml@pobox.com>
    Ryan King <rking@panoptic.com>
    Dave Rolsky <autarch@urth.org>
    Kang-min Liu <gugod@gugod.org>

COPYRIGHT:

    Copyright (c) 2005 Socialtext Corporation 
    655 High Street
    Palo Alto, CA 94301 U.S.A.
    All rights reserved.

Wikiwyg is free software. 

This library is free software; you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or (at
your option) any later version.

This library is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
General Public License for more details.

    http://www.gnu.org/copyleft/lesser.txt

 =============================================================================*/

/*==============================================================================
Subclass - this can be used to create new classes
 =============================================================================*/
Subclass = function(class_name, base_class_name) {
    if (!class_name) throw("Can't create a subclass without a name");

    var parts = class_name.split('.');
    var subclass = window;
    for (var i = 0; i < parts.length; i++) {
        if (! subclass[parts[i]])
            subclass[parts[i]] = function() {};
        subclass = subclass[parts[i]];
    }

    if (base_class_name) {
        var baseclass = eval('new ' + base_class_name + '()');
        subclass.prototype = baseclass;
        subclass.prototype.baseclass = baseclass;
    }

    subclass.prototype.classname = class_name;
    return subclass.prototype;
}

/*==============================================================================
Wikiwyg - Primary Wikiwyg base class
 =============================================================================*/

// Constructor and class methods
proto = new Subclass('Wikiwyg');

Wikiwyg.VERSION = '0.13';

// Browser support properties
Wikiwyg.ua = navigator.userAgent.toLowerCase();
Wikiwyg.is_ie = (
    Wikiwyg.ua.indexOf("msie") != -1 &&
    Wikiwyg.ua.indexOf("opera") == -1 && 
    Wikiwyg.ua.indexOf("webtv") == -1
);
Wikiwyg.is_gecko = (
    Wikiwyg.ua.indexOf('gecko') != -1 &&
    Wikiwyg.ua.indexOf('safari') == -1 &&
    Wikiwyg.ua.indexOf('konqueror') == -1
);
Wikiwyg.is_safari = (
    Wikiwyg.ua.indexOf('safari') != -1
);
Wikiwyg.is_opera = (
    Wikiwyg.ua.indexOf('opera') != -1
);
Wikiwyg.is_konqueror = (
    Wikiwyg.ua.indexOf("konqueror") != -1
)
Wikiwyg.browserIsSupported = (
    Wikiwyg.is_gecko ||
    Wikiwyg.is_ie
);

// Wikiwyg environment setup public methods
proto.createWikiwygArea = function(div, config) {
    this.set_config(config);
    this.initializeObject(div, config);
};

proto.default_config = {
    javascriptLocation: 'lib/',
    doubleClickToEdit: false,
    toolbarClass: 'Wikiwyg.Toolbar',
    firstMode: null,
    modeClasses: [
        'Wikiwyg.Wysiwyg',
        'Wikiwyg.Wikitext',
        'Wikiwyg.Preview'
    ]
};

proto.initializeObject = function(div, config) {
    if (! Wikiwyg.browserIsSupported) return;
    if (this.enabled) return;
    this.enabled = true;
    this.div = div;
    this.divHeight = this.div.offsetHeight;
    if (!config) config = {};

    this.set_config(config);

    this.mode_objects = {};
    for (var i = 0; i < this.config.modeClasses.length; i++) {
        var class_name = this.config.modeClasses[i];
        var mode_object = eval('new ' + class_name + '()');
        mode_object.wikiwyg = this;
        mode_object.set_config(config[mode_object.classtype]);
        mode_object.initializeObject();
        this.mode_objects[class_name] = mode_object;
    }
    var firstMode = this.config.firstMode
        ? this.config.firstMode
        : this.config.modeClasses[0];
    this.setFirstModeByName(firstMode);

    if (this.config.toolbarClass) {
        var class_name = this.config.toolbarClass;
        this.toolbarObject = eval('new ' + class_name + '()');
        this.toolbarObject.wikiwyg = this;
        this.toolbarObject.set_config(config.toolbar);
        this.toolbarObject.initializeObject();
        this.placeToolbar(this.toolbarObject.div);
    }

    // These objects must be _created_ before the toolbar is created
    // but _inserted_ after.
    for (var i = 0; i < this.config.modeClasses.length; i++) {
        var mode_class = this.config.modeClasses[i];
        var mode_object = this.modeByName(mode_class);
        this.insert_div_before(mode_object.div);
    }

    if (this.config.doubleClickToEdit) {
        var self = this;
        this.div.ondblclick = function() { self.editMode() }; 
    }
}

// Wikiwyg environment setup private methods
proto.set_config = function(user_config) {
    var new_config = {};
    var keys = [];
    for (var key in this.default_config) {
        keys.push(key);
    }
    if (user_config != null) {
        for (var key in user_config) {
            keys.push(key);
        }
    }
    for (var ii = 0; ii < keys.length; ii++) {
        var key = keys[ii];
        if (user_config != null && user_config[key] != null) {
            new_config[key] = user_config[key];
        } else if (this.default_config[key] != null) {
            new_config[key] = this.default_config[key];
        } else if (this[key] != null) {
            new_config[key] = this[key];
        }
    }
    this.config = new_config;
}

proto.insert_div_before = function(div) {
    div.style.display = 'none';
    if (! div.iframe_hack) {
        this.div.parentNode.insertBefore(div, this.div);
    }
}

// Wikiwyg actions - public methods
proto.saveChanges = function() {
    alert('Wikiwyg.prototype.saveChanges not subclassed');
}

proto.editMode = function() { // See IE, below
    this.current_mode = this.first_mode;
    this.current_mode.fromHtml(this.div.innerHTML);
    this.toolbarObject.resetModeSelector();
    this.current_mode.enableThis();
}

proto.displayMode = function() {
    for (var i = 0; i < this.config.modeClasses.length; i++) {
        var mode_class = this.config.modeClasses[i];
        var mode_object = this.modeByName(mode_class);
        mode_object.disableThis();
    }
    this.toolbarObject.disableThis();
    this.div.style.display = 'block';
    this.divHeight = this.div.offsetHeight;
}

proto.switchMode = function(new_mode_key) {
    var new_mode = this.modeByName(new_mode_key);
    var old_mode = this.current_mode;
    var self = this;
    new_mode.enableStarted();
    old_mode.disableStarted();
    old_mode.toHtml(
        function(html) {
            self.previous_mode = old_mode;
            new_mode.fromHtml(html);
            old_mode.disableThis();
            new_mode.enableThis();
            new_mode.enableFinished();
            old_mode.disableFinished();
            self.current_mode = new_mode;
        }
    );
}

proto.modeByName = function(mode_name) {
    return this.mode_objects[mode_name]
}

proto.cancelEdit = function() {
    this.displayMode();
}

proto.fromHtml = function(html) {
    this.div.innerHTML = html;
}

proto.placeToolbar = function(div) {
    this.insert_div_before(div);
}

proto.setFirstModeByName = function(mode_name) {
    if (!this.modeByName(mode_name))
        die('No mode named ' + mode_name);
    this.first_mode = this.modeByName(mode_name);
}

// Class level helper methods
Wikiwyg.unique_id_base = 0;
Wikiwyg.createUniqueId = function() {
    return 'wikiwyg_' + Wikiwyg.unique_id_base++;
}

// This method is deprecated. Use Ajax.get and Ajax.post.
Wikiwyg.liveUpdate = function(method, url, query, callback) {
    if (method == 'GET') {
        return Ajax.get(
            url + '?' + query,
            callback
        );
    }
    if (method == 'POST') {
        return Ajax.post(
            url,
            query,
            callback
        );
    }
    throw("Bad method: " + method + " passed to Wikiwyg.liveUpdate");
}

Wikiwyg.htmlUnescape = function(escaped) {
    // thanks to Randal Schwartz for the correct solution to this one
    // (from CGI.pm, CGI::unescapeHTML())
    return escaped.replace(
        /&(.*?);/g,
        function(dummy,s) {
            return s.match(/^amp$/i) ? '&' :
                s.match(/^quot$/i) ? '"' :
                s.match(/^gt$/i) ? '>' :
                s.match(/^lt$/i) ? '<' :
                s.match(/^#(\d+)$/) ?
                    String.fromCharCode(s.replace(/#/,'')) :
                s.match(/^#x([0-9a-f]+)$/i) ?
                    String.fromCharCode(s.replace(/#/,'0')) :
                s
        }
    );
}

Wikiwyg.showById = function(id) {
    document.getElementById(id).style.visibility = 'inherit';
}

Wikiwyg.hideById = function(id) {
    document.getElementById(id).style.visibility = 'hidden';
}


Wikiwyg.changeLinksMatching = function(attribute, pattern, func) {
    var links = document.getElementsByTagName('a');
    for (var i = 0; i < links.length; i++) {
        var link = links[i];
        var my_attribute = link.getAttribute(attribute);
        if (my_attribute && my_attribute.match(pattern)) {
            link.setAttribute('href', '#');
            link.onclick = func;
        }
    }
}

Wikiwyg.createElementWithAttrs = function(element, attrs, doc) {
    if (doc == null)
        doc = document;
    return Wikiwyg.create_element_with_attrs(element, attrs, doc);
}

Wikiwyg.create_element_with_attrs = function(element, attrs, doc) {
    var elem = doc.createElement(element);
    for (name in attrs)
        elem.setAttribute(name, attrs[name]);
    return elem;
}

die = function(e) { // See IE, below
    throw(e);
}

String.prototype.times = function(n) {
    return n ? this + this.times(n-1) : "";
}

String.prototype.ucFirst = function () {
    return this.substr(0,1).toUpperCase() + this.substr(1,this.length);
}

/*==============================================================================
Base class for Wikiwyg classes
 =============================================================================*/
proto = new Subclass('Wikiwyg.Base');

proto.set_config = function(user_config) {
    if (Wikiwyg.Widgets && this.setup_widgets)
        this.setup_widgets();

    for (var key in this.config) {
        if (user_config != null && user_config[key] != null)
            this.merge_config(key, user_config[key]);
        else if (this[key] != null)
            this.merge_config(key, this[key]);
        else if (this.wikiwyg.config[key] != null)
            this.merge_config(key, this.wikiwyg.config[key]);
    }
}

proto.merge_config = function(key, value) {
    if (value instanceof Array) {
        this.config[key] = value;
    }
    // cross-browser RegExp object check
    else if (typeof value.test == 'function') {
        this.config[key] = value;
    }
    else if (value instanceof Object) {
        if (!this.config[key])
            this.config[key] = {};
        for (var subkey in value) {
            this.config[key][subkey] = value[subkey];
        }
    }
    else {
        this.config[key] = value;
    }
}

/*==============================================================================
Base class for Wikiwyg Mode classes
 =============================================================================*/
proto = new Subclass('Wikiwyg.Mode', 'Wikiwyg.Base');

proto.enableThis = function() {
    this.div.style.display = 'block';
    this.display_unsupported_toolbar_buttons('none');
    this.wikiwyg.toolbarObject.enableThis();
    this.wikiwyg.div.style.display = 'none';
}

proto.display_unsupported_toolbar_buttons = function(display) {
    if (!this.config) return;
    var disabled = this.config.disabledToolbarButtons;
    if (!disabled || disabled.length < 1) return;

    var toolbar_div = this.wikiwyg.toolbarObject.div;
    var toolbar_buttons = toolbar_div.childNodes;
    for (var i in disabled) {
        var action = disabled[i];

        for (var i in toolbar_buttons) {
            var button = toolbar_buttons[i];
            var src = button.src;
            if (!src) continue;

            if (src.match(action)) {
                button.style.display = display;
                break;
            }
        }
    }
}

proto.enableStarted = function() {}
proto.enableFinished = function() {}
proto.disableStarted = function() {}
proto.disableFinished = function() {}

proto.disableThis = function() {
    this.display_unsupported_toolbar_buttons('inline');
    this.div.style.display = 'none';
}

proto.process_command = function(command) {
    if (this['do_' + command])
        this['do_' + command](command);
}

proto.enable_keybindings = function() { // See IE
    if (!this.key_press_function) {
        this.key_press_function = this.get_key_press_function();
        this.get_keybinding_area().addEventListener(
            'keypress', this.key_press_function, true
        );
    }
}

proto.get_key_press_function = function() {
    var self = this;
    return function(e) {
        if (! e.ctrlKey) return;
        var key = String.fromCharCode(e.charCode).toLowerCase();
        var command = '';
        switch (key) {
            case 'b': command = 'bold'; break;
            case 'i': command = 'italic'; break;
            case 'u': command = 'underline'; break;
            case 'd': command = 'strike'; break;
            case 'l': command = 'link'; break;
        };

        if (command) {
            e.preventDefault();
            e.stopPropagation();
            self.process_command(command);
        }
    };
}

proto.get_edit_height = function() {
    var height = parseInt(
        this.wikiwyg.divHeight *
        this.config.editHeightAdjustment
    );
    var min = this.config.editHeightMinimum;
    return height < min
        ? min
        : height;
}

proto.setHeightOf = function(elem) {
    elem.height = this.get_edit_height() + 'px';
}

proto.sanitize_dom = function(dom) { // See IE, below
    this.element_transforms(dom, {
        del: {
            name: 'strike',
            attr: { }
        },
        strong: {
            name: 'span',
            attr: { style: 'font-weight: bold;' }
        },
        em: {
            name: 'span',
            attr: { style: 'font-style: italic;' }
        }
    });
}

proto.element_transforms = function(dom, el_transforms) {
    for (var orig in el_transforms) {
        var elems = dom.getElementsByTagName(orig);
        var elems_arr = [];
        for (var ii = 0; ii < elems.length; ii++) {
            elems_arr.push(elems[ii])
        }

        while ( elems_arr.length > 0 ) {
            var elem = elems_arr.shift();
            var replace = el_transforms[orig];
            var new_el =
              Wikiwyg.createElementWithAttrs(replace.name, replace.attr);
            new_el.innerHTML = elem.innerHTML;
            elem.parentNode.replaceChild(new_el, elem);
        }
    }
}

/*==============================================================================
Support for Internet Explorer in Wikiwyg
 =============================================================================*/
if (Wikiwyg.is_ie) {

die = function(e) {
    alert(e);
    throw(e);
}

proto = Wikiwyg.Mode.prototype;

proto.enable_keybindings = function() {}

proto.sanitize_dom = function(dom) {
    this.element_transforms(dom, {
        del: {
            name: 'strike',
            attr: { }
        }
    });
}

} // end of global if statement for IE overrides
// BEGIN ../../../js-modules/Wikiwyg-copy/lib/Wikiwyg/Toolbar.js
/*==============================================================================
This Wikiwyg class provides toolbar support

COPYRIGHT:

    Copyright (c) 2005 Socialtext Corporation 
    655 High Street
    Palo Alto, CA 94301 U.S.A.
    All rights reserved.

Wikiwyg is free software. 

This library is free software; you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or (at
your option) any later version.

This library is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
General Public License for more details.

    http://www.gnu.org/copyleft/lesser.txt

 =============================================================================*/

proto = new Subclass('Wikiwyg.Toolbar', 'Wikiwyg.Base');
proto.classtype = 'toolbar';

proto.config = {
    divId: null,
    imagesLocation: 'images/',
    imagesExtension: '.gif',
    selectorWidth: '100px',
    controlLayout: [
        'save', 'cancel', 'mode_selector', '/',
        // 'selector',
        'h1', 'h2', 'h3', 'h4', 'p', 'pre', '|',
        'bold', 'italic', 'underline', 'strike', '|',
        'link', 'hr', '|',
        'ordered', 'unordered', '|',
        'indent', 'outdent', '|',
        'table', '|',
        'help'
    ],
    styleSelector: [
        'label', 'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'pre'
    ],
    controlLabels: {
        save: 'Save',
        cancel: 'Cancel',
        bold: 'Bold (Ctrl+b)',
        italic: 'Italic (Ctrl+i)',
        underline: 'Underline (Ctrl+u)',
        strike: 'Strike Through (Ctrl+d)',
        hr: 'Horizontal Rule',
        ordered: 'Numbered List',
        unordered: 'Bulleted List',
        indent: 'More Indented',
        outdent: 'Less Indented',
        help: 'About Wikiwyg',
        label: '[Style]',
        p: 'Normal Text',
        pre: 'Preformatted',
        h1: 'Heading 1',
        h2: 'Heading 2',
        h3: 'Heading 3',
        h4: 'Heading 4',
        h5: 'Heading 5',
        h6: 'Heading 6',
        link: 'Create Link',
        unlink: 'Remove Linkedness',
        table: 'Create Table'
    }
};

proto.initializeObject = function() {
    if (this.config.divId) {
        this.div = document.getElementById(this.config.divId);
    }
    else {
        this.div = Wikiwyg.createElementWithAttrs(
            'div', {
                'class': 'wikiwyg_toolbar',
                id: 'wikiwyg_toolbar'
            }
        );
    }

    var config = this.config;
    for (var i = 0; i < config.controlLayout.length; i++) {
        var action = config.controlLayout[i];
        var label = config.controlLabels[action];
        if (action == 'save')
            this.addControlItem(label, 'saveChanges');
        else if (action == 'cancel')
            this.addControlItem(label, 'cancelEdit');
        else if (action == 'mode_selector')
            this.addModeSelector();
        else if (action == 'selector')
            this.add_styles();
        else if (action == 'help')
            this.add_help_button(action, label);
        else if (action == '|')
            this.add_separator();
        else if (action == '/')
            this.add_break();
        else
            this.add_button(action, label);
    }
}

proto.enableThis = function() {
    this.div.style.display = 'block';
}

proto.disableThis = function() {
    this.div.style.display = 'none';
}

proto.setup_widgets_pulldown = function(title) {
    var widgets_list = Wikiwyg.Widgets.widgets;
    var widget_data = Wikiwyg.Widgets.widget;

    var tb = eval(this.classname).prototype;

    tb.styleSelector = [ 'label' ];
    for (var i = 0; i < widgets_list.length; i++) {
        var widget = widgets_list[i];
        tb.styleSelector.push('widget_' + widget);
    }
    tb.controlLayout.push('selector');

    tb.controlLabels.label = title;
    for (var i = 0; i < widgets_list.length; i++) {
        var widget = widgets_list[i];
        tb.controlLabels['widget_' + widget] = widget_data[widget].label;
    }
}

proto.make_button = function(type, label) {
    var base = this.config.imagesLocation;
    var ext = this.config.imagesExtension;
    return Wikiwyg.createElementWithAttrs(
        'img', {
            'class': 'wikiwyg_button',
            onmouseup: "this.style.border='1px outset';",
            onmouseover: "this.style.border='1px outset';",
            onmouseout:
                "this.style.borderColor=this.style.backgroundColor;" +
                "this.style.borderStyle='solid';",
            onmousedown:     "this.style.border='1px inset';",
            alt: label,
            title: label,
            src: base + type + ext
        }
    );
}

proto.add_button = function(type, label) {
    var img = this.make_button(type, label);
    var self = this;
    img.onclick = function() {
        self.wikiwyg.current_mode.process_command(type);
    };
    this.div.appendChild(img);
}

proto.add_help_button = function(type, label) {
    var img = this.make_button(type, label);
    var a = Wikiwyg.createElementWithAttrs(
        'a', {
            target: 'wikiwyg_button',
            href: 'http://www.wikiwyg.net/about/'
        }
    );
    a.appendChild(img);
    this.div.appendChild(a);
}

proto.add_separator = function() {
    var base = this.config.imagesLocation;
    var ext = this.config.imagesExtension;
    this.div.appendChild(
        Wikiwyg.createElementWithAttrs(
            'img', {
                'class': 'wikiwyg_separator',
                alt: ' | ',
                title: '',
                src: base + 'separator' + ext
            }
        )
    );
}

proto.addControlItem = function(text, method) {
    var span = Wikiwyg.createElementWithAttrs(
        'span', { 'class': 'wikiwyg_control_link' }
    );

    var link = Wikiwyg.createElementWithAttrs(
        'a', { href: '#' }
    );
    link.appendChild(document.createTextNode(text));
    span.appendChild(link);
    
    var self = this;
    link.onclick = function() { eval('self.wikiwyg.' + method + '()'); return false };

    this.div.appendChild(span);
}

proto.resetModeSelector = function() {
    if (this.firstModeRadio) {
        var temp = this.firstModeRadio.onclick;
        this.firstModeRadio.onclick = null;
        this.firstModeRadio.click();
        this.firstModeRadio.onclick = temp;
    }
}

proto.addModeSelector = function() {
    var span = document.createElement('span');

    var radio_name = Wikiwyg.createUniqueId();
    for (var i = 0; i < this.wikiwyg.config.modeClasses.length; i++) {
        var class_name = this.wikiwyg.config.modeClasses[i];
        var mode_object = this.wikiwyg.mode_objects[class_name];
 
        var radio_id = Wikiwyg.createUniqueId();
 
        var checked = i == 0 ? 'checked' : '';
        var radio = Wikiwyg.createElementWithAttrs(
            'input', {
                type: 'radio',
                name: radio_name,
                id: radio_id,
                value: mode_object.classname,
                'checked': checked
            }
        );
        if (!this.firstModeRadio)
            this.firstModeRadio = radio;
 
        var self = this;
        radio.onclick = function() { 
            self.wikiwyg.switchMode(this.value);
        };
 
        var label = Wikiwyg.createElementWithAttrs(
            'label', { 'for': radio_id }
        );
        label.appendChild(document.createTextNode(mode_object.modeDescription));

        span.appendChild(radio);
        span.appendChild(label);
    }
    this.div.appendChild(span);
}

proto.add_break = function() {
    this.div.appendChild(document.createElement('br'));
}

proto.add_styles = function() {
    var options = this.config.styleSelector;
    var labels = this.config.controlLabels;

    this.styleSelect = document.createElement('select');
    this.styleSelect.className = 'wikiwyg_selector';
    if (this.config.selectorWidth)
        this.styleSelect.style.width = this.config.selectorWidth;

    for (var i = 0; i < options.length; i++) {
        value = options[i];
        var option = Wikiwyg.createElementWithAttrs(
            'option', { 'value': value }
        );
        option.appendChild(document.createTextNode(labels[value] || value));
        this.styleSelect.appendChild(option);
    }
    var self = this;
    this.styleSelect.onchange = function() { 
        self.set_style(this.value) 
    };
    this.div.appendChild(this.styleSelect);
}

proto.set_style = function(style_name) {
    var idx = this.styleSelect.selectedIndex;
    // First one is always a label
    if (idx != 0)
        this.wikiwyg.current_mode.process_command(style_name);
    this.styleSelect.selectedIndex = 0;
}
// BEGIN ../../../js-modules/Wikiwyg-copy/lib/Wikiwyg/Preview.js
/*==============================================================================
This Wikiwyg mode supports a preview of current changes

COPYRIGHT:

    Copyright (c) 2005 Socialtext Corporation 
    655 High Street
    Palo Alto, CA 94301 U.S.A.
    All rights reserved.

Wikiwyg is free software. 

This library is free software; you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or (at
your option) any later version.

This library is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
General Public License for more details.

    http://www.gnu.org/copyleft/lesser.txt

 =============================================================================*/

proto = new Subclass('Wikiwyg.Preview', 'Wikiwyg.Mode');

proto.classtype = 'preview';
proto.modeDescription = 'Preview';

proto.config = {
    divId: null
}

proto.initializeObject = function() {
    if (this.config.divId)
        this.div = document.getElementById(this.config.divId);
    else
        this.div = document.createElement('div');
    // XXX Make this a config option.
    this.div.style.backgroundColor = 'lightyellow';
}

proto.fromHtml = function(html) {
    this.div.innerHTML = html;
}

proto.toHtml = function(func) {
    func(this.div.innerHTML);
}

proto.disableStarted = function() {
    this.wikiwyg.divHeight = this.div.offsetHeight;
}
// BEGIN ../../../js-modules/Wikiwyg-copy/lib/Wikiwyg/Wikitext.js
/*==============================================================================
This Wikiwyg mode supports a textarea editor with toolbar buttons.

COPYRIGHT:

    Copyright (c) 2005 Socialtext Corporation
    655 High Street
    Palo Alto, CA 94301 U.S.A.
    All rights reserved.

Wikiwyg is free software.

This library is free software; you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or (at
your option) any later version.

This library is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
General Public License for more details.

    http://www.gnu.org/copyleft/lesser.txt

 =============================================================================*/

proto = new Subclass('Wikiwyg.Wikitext', 'Wikiwyg.Mode');
klass = Wikiwyg.Wikitext;

proto.classtype = 'wikitext';
proto.modeDescription = 'Wikitext';

proto.config = {
    textareaId: null,
    supportCamelCaseLinks: false,
    javascriptLocation: null,
    clearRegex: null,
    editHeightMinimum: 10,
    editHeightAdjustment: 1.3,
    markupRules: {
        link: ['bound_phrase', '[', ']'],
        bold: ['bound_phrase', '*', '*'],
        code: ['bound_phrase', '`', '`'],
        italic: ['bound_phrase', '/', '/'],
        underline: ['bound_phrase', '_', '_'],
        strike: ['bound_phrase', '-', '-'],
        p: ['start_lines', ''],
        pre: ['start_lines', '    '],
        h1: ['start_line', '= '],
        h2: ['start_line', '== '],
        h3: ['start_line', '=== '],
        h4: ['start_line', '==== '],
        h5: ['start_line', '===== '],
        h6: ['start_line', '====== '],
        ordered: ['start_lines', '#'],
        unordered: ['start_lines', '*'],
        indent: ['start_lines', '>'],
        hr: ['line_alone', '----'],
        table: ['line_alone', '| A | B | C |\n|   |   |   |\n|   |   |   |'],
        www: ['bound_phrase', '[', ']']
    }
}

proto.initializeObject = function() { // See IE
    this.initialize_object();
}

proto.initialize_object = function() {
    this.div = document.createElement('div');
    if (this.config.textareaId)
        this.textarea = document.getElementById(this.config.textareaId);
    else
        this.textarea = document.createElement('textarea');
    this.textarea.setAttribute('id', 'wikiwyg_wikitext_textarea');
    this.div.appendChild(this.textarea);
    this.area = this.textarea;
    this.clear_inner_text();
}

proto.clear_inner_text = function() {
    if ( Wikiwyg.is_safari ) return;
    var self = this;
    this.area.onclick = function() {
        var inner_text = self.area.value;
        var clear = self.config.clearRegex;
        if (clear && inner_text.match(clear))
            self.area.value = '';
    }
}

proto.enableThis = function() {
    Wikiwyg.Mode.prototype.enableThis.call(this);
    this.textarea.style.width = '100%';
    this.setHeightOfEditor();
    this.enable_keybindings();
}

proto.setHeightOfEditor = function() {
    var config = this.config;
    var adjust = config.editHeightAdjustment;
    var area   = this.textarea;

    if ( Wikiwyg.is_safari) return area.setAttribute('rows', 25);

    var text   = this.getTextArea() ;
    var rows   = text.split(/\n/).length;

    var height = parseInt(rows * adjust);
    if (height < config.editHeightMinimum)
        height = config.editHeightMinimum;

    area.setAttribute('rows', height);
}

proto.toWikitext = function() {
    return this.getTextArea();
}

proto.toHtml = function(func) {
    var wikitext = this.canonicalText();
    this.convertWikitextToHtml(wikitext, func);
}

proto.canonicalText = function() {
    var wikitext = this.getTextArea();
    if (wikitext[wikitext.length - 1] != '\n')
        wikitext += '\n';
    return wikitext;
}

proto.fromHtml = function(html) {
    this.setTextArea('Loading...');
    var self = this;
    this.convertHtmlToWikitext(
        html,
        function(value) { self.setTextArea(value) }
    );
}

proto.getTextArea = function() {
    return this.textarea.value;
}

proto.setTextArea = function(text) {
    this.textarea.value = text;
}

proto.convertWikitextToHtml = function(wikitext, func) {
    alert('Wikitext changes cannot be converted to HTML\nWikiwyg.Wikitext.convertWikitextToHtml is not implemented here');
    func(this.copyhtml);
}

proto.convertHtmlToWikitext = function(html, func) {
    func(this.convert_html_to_wikitext(html));
}

proto.get_keybinding_area = function() {
    return this.textarea;
}

/*==============================================================================
Code to markup wikitext
 =============================================================================*/
Wikiwyg.Wikitext.phrase_end_re = /[\s\.\:\;\,\!\?\(\)\"]/;

proto.find_left = function(t, selection_start, matcher) {
    var substring = t.substr(selection_start - 1, 1);
    var nextstring = t.substr(selection_start - 2, 1);
    if (selection_start == 0)
        return selection_start;
    if (substring.match(matcher)) {
        // special case for word.word
        if ((substring != '.') || (nextstring.match(/\s/)))
            return selection_start;
    }
    return this.find_left(t, selection_start - 1, matcher);
}

proto.find_right = function(t, selection_end, matcher) {
    var substring = t.substr(selection_end, 1);
    var nextstring = t.substr(selection_end + 1, 1);
    if (selection_end >= t.length)
        return selection_end;
    if (substring.match(matcher)) {
        // special case for word.word
        if ((substring != '.') || (nextstring.match(/\s/)))
            return selection_end;
    }
    return this.find_right(t, selection_end + 1, matcher);
}

proto.get_lines = function() {
    var t = this.area;
    var selection_start = t.selectionStart;
    var selection_end = t.selectionEnd;

    if (selection_start == null) {
        selection_start = selection_end;
        if (selection_start == null) {
            return false
        }
        selection_start = selection_end =
            t.value.substr(0, selection_start).replace(/\r/g, '').length;
    }

    var our_text = t.value.replace(/\r/g, '');
    selection = our_text.substr(selection_start,
        selection_end - selection_start);

    selection_start = this.find_right(our_text, selection_start, /[^\r\n]/);
    selection_end = this.find_left(our_text, selection_end, /[^\r\n]/);

    this.selection_start = this.find_left(our_text, selection_start, /[\r\n]/);
    this.selection_end = this.find_right(our_text, selection_end, /[\r\n]/);
    t.setSelectionRange(selection_start, selection_end);
    t.focus();

    this.start = our_text.substr(0,this.selection_start);
    this.sel = our_text.substr(this.selection_start, this.selection_end -
        this.selection_start);
    this.finish = our_text.substr(this.selection_end, our_text.length);

    return true;
}

proto.alarm_on = function() {
    var area = this.area;
    var background = area.style.background;
    area.style.background = '#f88';

    function alarm_off() {
        area.style.background = background;
    }

    window.setTimeout(alarm_off, 250);
    area.focus()
}

proto.get_words = function() {
    function is_insane(selection) {
        return selection.match(/\r?\n(\r?\n|\*+ |\#+ |\=+ )/);
    }

    t = this.area; // XXX needs "var"?
    var selection_start = t.selectionStart;
    var selection_end = t.selectionEnd;

    if (selection_start == null) {
        selection_start = selection_end;
        if (selection_start == null) {
            return false
        }
        selection_start = selection_end =
            t.value.substr(0, selection_start).replace(/\r/g, '').length;
    }

    var our_text = t.value.replace(/\r/g, '');
    selection = our_text.substr(selection_start,
        selection_end - selection_start);

    selection_start = this.find_right(our_text, selection_start, /(\S|\r?\n)/);
    if (selection_start > selection_end)
        selection_start = selection_end;
    selection_end = this.find_left(our_text, selection_end, /(\S|\r?\n)/);
    if (selection_end < selection_start)
        selection_end = selection_start;

    if (is_insane(selection)) {
        this.alarm_on();
        return false;
    }

    this.selection_start =
        this.find_left(our_text, selection_start, Wikiwyg.Wikitext.phrase_end_re);
    this.selection_end =
        this.find_right(our_text, selection_end, Wikiwyg.Wikitext.phrase_end_re);

    t.setSelectionRange(this.selection_start, this.selection_end);
    t.focus();

    this.start = our_text.substr(0,this.selection_start);
    this.sel = our_text.substr(this.selection_start, this.selection_end -
        this.selection_start);
    this.finish = our_text.substr(this.selection_end, our_text.length);

    return true;
}

proto.markup_is_on = function(start, finish) {
    return (this.sel.match(start) && this.sel.match(finish));
}

proto.clean_selection = function(start, finish) {
    this.sel = this.sel.replace(start, '');
    this.sel = this.sel.replace(finish, '');
}

proto.toggle_same_format = function(start, finish) {
    start = this.clean_regexp(start);
    finish = this.clean_regexp(finish);
    var start_re = new RegExp('^' + start);
    var finish_re = new RegExp(finish + '$');
    if (this.markup_is_on(start_re, finish_re)) {
        this.clean_selection(start_re, finish_re);
        return true;
    }
    return false;
}

proto.clean_regexp = function(string) {
    string = string.replace(/([\^\$\*\+\.\?\[\]\{\}])/g, '\\$1');
    return string;
}

proto.insert_text_at_cursor = function(text) {
    var t = this.area;

    var selection_start = t.selectionStart;
    var selection_end = t.selectionEnd;

    if (selection_start == null) {
        selection_start = selection_end;
        if (selection_start == null) {
            return false
        }
    }

    var before = t.value.substr(0, selection_start);
    var after = t.value.substr(selection_end, t.value.length);
    t.value = before + text + after;
}

proto.set_text_and_selection = function(text, start, end) {
    this.area.value = text;
    this.area.setSelectionRange(start, end);
}

proto.add_markup_words = function(markup_start, markup_finish, example) {
    if (this.toggle_same_format(markup_start, markup_finish)) {
        this.selection_end = this.selection_end -
            (markup_start.length + markup_finish.length);
        markup_start = '';
        markup_finish = '';
    }
    if (this.sel.length == 0) {
        if (example)
            this.sel = example;
        var text = this.start + markup_start + this.sel +
            markup_finish + this.finish;
        var start = this.selection_start + markup_start.length;
        var end = this.selection_end + markup_start.length + this.sel.length;
        this.set_text_and_selection(text, start, end);
    } else {
        var text = this.start + markup_start + this.sel +
            markup_finish + this.finish;
        var start = this.selection_start;
        var end = this.selection_end + markup_start.length +
            markup_finish.length;
        this.set_text_and_selection(text, start, end);
    }
    this.area.focus();
}

// XXX - A lot of this is hardcoded.
proto.add_markup_lines = function(markup_start) {
    var already_set_re = new RegExp( '^' + this.clean_regexp(markup_start), 'gm');
    var other_markup_re = /^(\^+|\=+|\*+|#+|>+|    )/gm;

    var match;
    // if paragraph, reduce everything.
    if (! markup_start.length) {
        this.sel = this.sel.replace(other_markup_re, '');
        this.sel = this.sel.replace(/^\ +/gm, '');
    }
    // if pre and not all indented, indent
    else if ((markup_start == '    ') && this.sel.match(/^\S/m))
        this.sel = this.sel.replace(/^/gm, markup_start);
    // if not requesting heading and already this style, kill this style
    else if (
        (! markup_start.match(/[\=\^]/)) &&
        this.sel.match(already_set_re)
    ) {
        this.sel = this.sel.replace(already_set_re, '');
        if (markup_start != '    ')
            this.sel = this.sel.replace(/^ */gm, '');
    }
    // if some other style, switch to new style
    else if (match = this.sel.match(other_markup_re))
        // if pre, just indent
        if (markup_start == '    ')
            this.sel = this.sel.replace(/^/gm, markup_start);
        // if heading, just change it
        else if (markup_start.match(/[\=\^]/))
            this.sel = this.sel.replace(other_markup_re, markup_start);
        // else try to change based on level
        else
            this.sel = this.sel.replace(
                other_markup_re,
                function(match) {
                    return markup_start.times(match.length);
                }
            );
    // if something selected, use this style
    else if (this.sel.length > 0)
        this.sel = this.sel.replace(/^(.*\S+)/gm, markup_start + ' $1');
    // just add the markup
    else
        this.sel = markup_start + ' ';

    var text = this.start + this.sel + this.finish;
    var start = this.selection_start;
    var end = this.selection_start + this.sel.length;
    this.set_text_and_selection(text, start, end);
    this.area.focus();
}

// XXX - A lot of this is hardcoded.
proto.bound_markup_lines = function(markup_array) {
    var markup_start = markup_array[1];
    var markup_finish = markup_array[2];
    var already_start = new RegExp('^' + this.clean_regexp(markup_start), 'gm');
    var already_finish = new RegExp(this.clean_regexp(markup_finish) + '$', 'gm');
    var other_start = /^(\^+|\=+|\*+|#+|>+) */gm;
    var other_finish = /( +(\^+|\=+))?$/gm;

    var match;
    if (this.sel.match(already_start)) {
        this.sel = this.sel.replace(already_start, '');
        this.sel = this.sel.replace(already_finish, '');
    }
    else if (match = this.sel.match(other_start)) {
        this.sel = this.sel.replace(other_start, markup_start);
        this.sel = this.sel.replace(other_finish, markup_finish);
    }
    // if something selected, use this style
    else if (this.sel.length > 0) {
        this.sel = this.sel.replace(
            /^(.*\S+)/gm,
            markup_start + '$1' + markup_finish
        );
    }
    // just add the markup
    else
        this.sel = markup_start + markup_finish;

    var text = this.start + this.sel + this.finish;
    var start = this.selection_start;
    var end = this.selection_start + this.sel.length;
    this.set_text_and_selection(text, start, end);
    this.area.focus();
}

proto.markup_bound_line = function(markup_array) {
    var scroll_top = this.area.scrollTop;
    if (this.get_lines())
        this.bound_markup_lines(markup_array);
    this.area.scrollTop = scroll_top;
}

proto.markup_start_line = function(markup_array) {
    var markup_start = markup_array[1];
    markup_start = markup_start.replace(/ +/, '');
    var scroll_top = this.area.scrollTop;
    if (this.get_lines())
        this.add_markup_lines(markup_start);
    this.area.scrollTop = scroll_top;
}

proto.markup_start_lines = function(markup_array) {
    var markup_start = markup_array[1];
    var scroll_top = this.area.scrollTop;
    if (this.get_lines())
        this.add_markup_lines(markup_start);
    this.area.scrollTop = scroll_top;
}

proto.markup_bound_phrase = function(markup_array) {
    var markup_start = markup_array[1];
    var markup_finish = markup_array[2];
    var scroll_top = this.area.scrollTop;
    if (markup_finish == 'undefined')
        markup_finish = markup_start;
    if (this.get_words())
        this.add_markup_words(markup_start, markup_finish, null);
    this.area.scrollTop = scroll_top;
}

klass.make_do = function(style) {
    return function() {
        var markup = this.config.markupRules[style];
        var handler = markup[0];
        if (! this['markup_' + handler])
            die('No handler for markup: "' + handler + '"');
        this['markup_' + handler](markup);
    }
}

proto.do_link = klass.make_do('link');
proto.do_bold = klass.make_do('bold');
proto.do_code = klass.make_do('code');
proto.do_italic = klass.make_do('italic');
proto.do_underline = klass.make_do('underline');
proto.do_strike = klass.make_do('strike');
proto.do_p = klass.make_do('p');
proto.do_pre = klass.make_do('pre');
proto.do_h1 = klass.make_do('h1');
proto.do_h2 = klass.make_do('h2');
proto.do_h3 = klass.make_do('h3');
proto.do_h4 = klass.make_do('h4');
proto.do_h5 = klass.make_do('h5');
proto.do_h6 = klass.make_do('h6');
proto.do_ordered = klass.make_do('ordered');
proto.do_unordered = klass.make_do('unordered');
proto.do_hr = klass.make_do('hr');
proto.do_table = klass.make_do('table');

proto.do_www = function() {
    var  url =  prompt("Please enter a link", "Type in your link here");
	var old = this.config.markupRules.www[1];
	this.config.markupRules.www[1] += url + " ";

	// do the transformation
	var markup = this.config.markupRules['www'];
    var handler = markup[0];
     if (! this['markup_' + handler])
    	die('No handler for markup: "' + handler + '"');
    this['markup_' + handler](markup);

	// reset
	this.config.markupRules.www[1] = old;
}

proto.selection_mangle = function(method) {
    var scroll_top = this.area.scrollTop;
    if (! this.get_lines()) {
        this.area.scrollTop = scroll_top;
        return;
    }

    if (method(this)) {
        var text = this.start + this.sel + this.finish;
        var start = this.selection_start;
        var end = this.selection_start + this.sel.length;
        this.set_text_and_selection(text, start, end);
    }
    this.area.focus();
}

proto.do_indent = function() {
    this.selection_mangle(
        function(that) {
            if (that.sel == '') return false;
            that.sel = that.sel.replace(/^(([\*\-\#])+(?=\s))/gm, '$2$1');
            that.sel = that.sel.replace(/^([\>\=])/gm, '$1$1');
            that.sel = that.sel.replace(/^([^\>\*\-\#\=\r\n])/gm, '> $1');
            that.sel = that.sel.replace(/^\={7,}/gm, '======');
            return true;
        }
    )
}

proto.do_outdent = function() {
    this.selection_mangle(
        function(that) {
            if (that.sel == '') return false;
            that.sel = that.sel.replace(/^([\>\*\-\#\=] ?)/gm, '');
            return true;
        }
    )
}

proto.do_unlink = function() {
    this.selection_mangle(
        function(that) {
            that.sel = that.kill_linkedness(that.sel);
            return true;
        }
    );
}

// TODO - generalize this to allow Wikitext dialects that don't use "[foo]"
proto.kill_linkedness = function(str) {
    while (str.match(/\[.*\]/))
        str = str.replace(/\[(.*?)\]/, '$1');
    str = str.replace(/^(.*)\]/, '] $1');
    str = str.replace(/\[(.*)$/, '$1 [');
    return str;
}

proto.markup_line_alone = function(markup_array) {
    var t = this.area;
    var scroll_top = t.scrollTop;
    var selection_start = t.selectionStart;
    var selection_end = t.selectionEnd;
    if (selection_start == null) {
        selection_start = selection_end;
    }

    var text = t.value;
    this.selection_start = this.find_right(text, selection_start, /\r?\n/);
    this.selection_end = this.selection_start;
    t.setSelectionRange(this.selection_start, this.selection_start);
    t.focus();

    var markup = markup_array[1];
    this.start = t.value.substr(0, this.selection_start);
    this.finish = t.value.substr(this.selection_end, t.value.length);
    var text = this.start + '\n' + markup + this.finish;
    var start = this.selection_start + markup.length + 1;
    var end = this.selection_end + markup.length + 1;
    this.set_text_and_selection(text, start, end);
    t.scrollTop = scroll_top;
}


/*==============================================================================
Code to convert from html to wikitext.
 =============================================================================*/
proto.convert_html_to_wikitext = function(html) {
    this.copyhtml = html;
    var dom = document.createElement('div');
    dom.innerHTML = html;
    this.output = [];
    this.list_type = [];
    this.indent_level = 0;
    this.no_collapse_text = false;

    this.normalizeDomWhitespace(dom);
    this.normalizeDomStructure(dom);

    this.walk(dom);

    // add final whitespace
    this.assert_new_line();

    return this.join_output(this.output);
}

proto.normalizeDomStructure = function(dom) {
    this.normalize_styled_blocks(dom, 'p');
    this.normalize_styled_lists(dom, 'ol');
    this.normalize_styled_lists(dom, 'ul');
    this.normalize_styled_blocks(dom, 'li');
    this.normalize_span_whitespace(dom, 'span');
}

proto.normalize_span_whitespace = function(dom,tag ) {
    var grep = function(element) {
        return Boolean(element.getAttribute('style'));
    }

    var elements = this.array_elements_by_tag_name(dom, tag, grep);
    for (var i = 0; i < elements.length; i++) {
        var element = elements[i];
        var node = element.firstChild;
        while (node) {
            if (node.nodeType == 3) {
                node.nodeValue = node.nodeValue.replace(/^\n+/,"");
                break;
            }
            node = node.nextSibling;
        }
        var node = element.lastChild;
        while (node) {
            if (node.nodeType == 3) {
                node.nodeValue = node.nodeValue.replace(/\n+$/,"");
                break;
            }
            node = node.previousSibling;
        }
    }
}

proto.normalize_styled_blocks = function(dom, tag) {
    var elements = this.array_elements_by_tag_name(dom, tag);
    for (var i = 0; i < elements.length; i++) {
        var element = elements[i];
        var style = element.getAttribute('style');
        if (!style || this.style_is_bogus(style)) continue;
        element.removeAttribute('style');
        element.innerHTML =
            '<span style="' + style + '">' + element.innerHTML + '</span>';
    }
}

proto.style_is_bogus = function(style) {
    var attributes = [ 'line-through', 'bold', 'italic', 'underline' ];
    for (var i = 0; i < attributes.length; i++) {
        if (this.check_style_for_attribute(style, attributes[i]))
            return false;
    }
    return true;
}

proto.normalize_styled_lists = function(dom, tag) {
    var elements = this.array_elements_by_tag_name(dom, tag);
    for (var i = 0; i < elements.length; i++) {
        var element = elements[i];
        var style = element.getAttribute('style');
        if (!style) continue;
        element.removeAttribute('style');

        var items = element.getElementsByTagName('li');
        for (var j = 0; j < items.length; j++) {
            items[j].innerHTML =
                '<span style="' + style + '">' + items[j].innerHTML + '</span>';
        }
    }
}

proto.array_elements_by_tag_name = function(dom, tag, grep) {
    var result = dom.getElementsByTagName(tag);
    var elements = [];
    for (var i = 0; i < result.length; i++) {
        if (grep && ! grep(result[i]))
            continue;
        elements.push(result[i]);
    }
    return elements;
}

proto.normalizeDomWhitespace = function(dom) {
    var tags = ['span', 'strong', 'em', 'strike', 'del', 'tt'];
    for (var ii = 0; ii < tags.length; ii++) {
        var elements = dom.getElementsByTagName(tags[ii]);
        for (var i = 0; i < elements.length; i++) {
            this.normalizePhraseWhitespace(elements[i]);
        }
    }
    this.normalizeNewlines(dom, ['br', 'blockquote'], 'nextSibling');
    this.normalizeNewlines(dom, ['p', 'div', 'blockquote'], 'firstChild');
}

proto.normalizeNewlines = function(dom, tags, relation) {
    for (var ii = 0; ii < tags.length; ii++) {
        var nodes = dom.getElementsByTagName(tags[ii]);
        for (var jj = 0; jj < nodes.length; jj++) {
            var next_node = nodes[jj][relation];
            if (next_node && next_node.nodeType == '3') {
                next_node.nodeValue = next_node.nodeValue.replace(/^\n/, '');
            }
        }
    }
}

proto.normalizePhraseWhitespace = function(element) {
    if (this.elementHasComment(element)) return;

    var first_node = this.getFirstTextNode(element);
    var prev_node = this.getPreviousTextNode(element);
    var last_node = this.getLastTextNode(element);
    var next_node = this.getNextTextNode(element);

    // This if() here is for a special condition on firefox.
    // When a bold span is the last visible thing in the dom,
    // Firefox puts an extra <br> in right before </span> when user
    // press space, while normally it put &nbsp;.

    if(Wikiwyg.is_gecko && element.tagName == 'SPAN') {
        var tmp = element.innerHTML;
        element.innerHTML = tmp.replace(/<br>$/i, '');
    }

    if (this.destroyPhraseMarkup(element)) return;

    if (first_node && first_node.nodeValue.match(/^ /)) {
        first_node.nodeValue = first_node.nodeValue.replace(/^ +/, '');
        if (prev_node && ! prev_node.nodeValue.match(/ $/))
            prev_node.nodeValue = prev_node.nodeValue + ' ';
    }

    if (last_node && last_node.nodeValue.match(/ $/)) {
        last_node.nodeValue = last_node.nodeValue.replace(/ $/, '');
        if (next_node && ! next_node.nodeValue.match(/^ /))
            next_node.nodeValue = ' ' + next_node.nodeValue;
    }
}

proto.elementHasComment = function(element) {
    var node = element.lastChild;
    return node && (node.nodeType == 8);
}

proto.destroyPhraseMarkup = function(element) {
    if (this.start_is_no_good(element) || this.end_is_no_good(element))
        return this.destroyElement(element);
    return false;
}

proto.start_is_no_good = function(element) {
    var first_node = this.getFirstTextNode(element);
    var prev_node = this.getPreviousTextNode(element);

    if (! first_node) return true;
    if (first_node.nodeValue.match(/^ /)) return false;
    if (! prev_node || prev_node.nodeValue == '\n') return false;
    return ! prev_node.nodeValue.match(/[ "]$/);
}

proto.end_is_no_good = function(element) {
    var last_node = this.getLastTextNode(element);
    var next_node = this.getNextTextNode(element);

    for (var n = element; n && n.nodeType != 3; n = n.lastChild) {
        if (n.nodeType == 8) return false;
    }

    if (! last_node) return true;
    if (last_node.nodeValue.match(/ $/)) return false;
    if (! next_node || next_node.nodeValue == '\n') return false;
    return ! next_node.nodeValue.match(Wikiwyg.Wikitext.phrase_end_re);
}

proto.destroyElement = function(element) {
    try {
        var range = element.ownerDocument.createRange();
        range.selectNode(element);
        var docfrag = range.createContextualFragment( element.innerHTML );
        element.parentNode.replaceChild(docfrag, element);
        return true;
    }
    catch (e) {
        return false;
    }
}

proto.getFirstTextNode = function(element) {
    for (node = element; node && node.nodeType != 3; node = node.firstChild) {
    }
    return node;
}

proto.getLastTextNode = function(element) {
    for (node = element; node && node.nodeType != 3; node = node.lastChild) {
    }
    return node;
}

proto.getPreviousTextNode = function(element) {
    var node = element.previousSibling;
    if (node && node.nodeType != 3)
        node = null;
    return node;
}

proto.getNextTextNode = function(element) {
    var node = element.nextSibling;
    if (node && node.nodeType != 3)
        node = null;
    return node;
}

proto.appendOutput = function(string) {
    this.output.push(string);
}

proto.join_output = function(output) {
    var list = this.remove_stops(output);
    list = this.cleanup_output(list);
    return list.join('');
}

// This is a noop, but can be subclassed.
proto.cleanup_output = function(list) {
    return list;
}

proto.remove_stops = function(list) {
    var clean = [];
    for (var i = 0 ; i < list.length ; i++) {
        if (typeof(list[i]) != 'string') continue;
        clean.push(list[i]);
    }
    return clean;
}

proto.walk = function(element) {
    if (!element) return;
    for (var part = element.firstChild; part; part = part.nextSibling) {
        /* Saving the part's properties in local vars seems to give us
         * a minor speed boost in this method, which can be called
         * thousands of times for large documents. */
        var nodeType = part.nodeType;
        if (nodeType == 1) {
            this.dispatch_formatter(part);
        }
        else if (nodeType == 3) {
            var nodeValue = part.nodeValue;
            if (nodeValue.match(/[^\n]/) &&
                ! nodeValue.match(/^\n[\n\ \t]*$/)
               ) {
                if (this.no_collapse_text) {
                    this.appendOutput(nodeValue);
                }
                else {
                    this.appendOutput(this.collapse(nodeValue));
                }
            }
        }
    }
    this.no_collapse_text = false;
}

proto.dispatch_formatter = function(element) {
    var dispatch = 'format_' + element.nodeName.toLowerCase();
    if (! this[dispatch])
        dispatch = 'handle_undefined';
    this[dispatch](element);
}

proto.skip = function() { }
proto.pass = function(element) {
    this.walk(element);
}
proto.handle_undefined = function(element) {
    this.appendOutput('<' + element.nodeName + '>');
    this.walk(element);
    this.appendOutput('</' + element.nodeName + '>');
}
proto.handle_undefined = proto.skip;

proto.format_abbr = proto.pass;
proto.format_acronym = proto.pass;
proto.format_address = proto.pass;
proto.format_applet = proto.skip;
proto.format_area = proto.skip;
proto.format_basefont = proto.skip;
proto.format_base = proto.skip;
proto.format_bgsound = proto.skip;
proto.format_big = proto.pass;
proto.format_blink = proto.pass;
proto.format_body = proto.pass;
proto.format_br = proto.skip;
proto.format_button = proto.skip;
proto.format_caption = proto.pass;
proto.format_center = proto.pass;
proto.format_cite = proto.pass;
proto.format_col = proto.pass;
proto.format_colgroup = proto.pass;
proto.format_dd = proto.pass;
proto.format_dfn = proto.pass;
proto.format_dl = proto.pass;
proto.format_dt = proto.pass;
proto.format_embed = proto.skip;
proto.format_field = proto.skip;
proto.format_fieldset = proto.skip;
proto.format_font = proto.pass;
proto.format_form = proto.skip;
proto.format_frame = proto.skip;
proto.format_frameset = proto.skip;
proto.format_head = proto.skip;
proto.format_html = proto.pass;
proto.format_iframe = proto.pass;
proto.format_input = proto.skip;
proto.format_ins = proto.pass;
proto.format_isindex = proto.skip;
proto.format_label = proto.skip;
proto.format_legend = proto.skip;
proto.format_link = proto.skip;
proto.format_map = proto.skip;
proto.format_marquee = proto.skip;
proto.format_meta = proto.skip;
proto.format_multicol = proto.pass;
proto.format_nobr = proto.skip;
proto.format_noembed = proto.skip;
proto.format_noframes = proto.skip;
proto.format_nolayer = proto.skip;
proto.format_noscript = proto.skip;
proto.format_nowrap = proto.skip;
proto.format_object = proto.skip;
proto.format_optgroup = proto.skip;
proto.format_option = proto.skip;
proto.format_param = proto.skip;
proto.format_select = proto.skip;
proto.format_small = proto.pass;
proto.format_spacer = proto.skip;
proto.format_style = proto.skip;
proto.format_sub = proto.pass;
proto.format_submit = proto.skip;
proto.format_sup = proto.pass;
proto.format_tbody = proto.pass;
proto.format_textarea = proto.skip;
proto.format_tfoot = proto.pass;
proto.format_thead = proto.pass;
proto.format_wiki = proto.pass;
proto.format_www = proto.skip;

proto.format_img = function(element) {
    var uri = element.getAttribute('src');
    if (uri) {
        this.assert_space_or_newline();
        this.appendOutput(uri);
    }
}

// XXX This little dance relies on knowning lots of little details about where
// indentation fangs are added and deleted by the various insert/assert calls.
proto.format_blockquote = function(element) {
    var margin  = parseInt(element.style.marginLeft);
    var indents = 0;
    if (margin)
        indents += parseInt(margin / 40);
    if (element.tagName.toLowerCase() == 'blockquote')
        indents += 1;

    if (!this.indent_level)
        this.first_indent_line = true;
    this.indent_level += indents;

    this.output = defang_last_string(this.output);
    this.assert_new_line();
    this.walk(element);
    this.indent_level -= indents;

    if (! this.indent_level)
        this.assert_blank_line();
    else
        this.assert_new_line();

    function defang_last_string(output) {
        function non_string(a) { return typeof(a) != 'string' }

        // Strategy: reverse the output list, take any non-strings off the
        // head (tail of the original output list), do the substitution on the
        // first item of the reversed head (this is the last string in the
        // original list), then join and reverse the result.
        //
        // Suppose the output list looks like this, where a digit is a string,
        // a letter is an object, and * is the substituted string: 01q234op.

        var rev = output.slice().reverse();                     // po432q10
        var rev_tail = takeWhile(non_string, rev);              // po
        var rev_head = dropWhile(non_string, rev);              // 432q10

        if (rev_head.length)
            rev_head[0].replace(/^>+/, '');                     // *32q10

        // po*3210 -> 0123*op
        return rev_tail.concat(rev_head).reverse();             // 01q23*op
    }
}

proto.format_div = function(element) {
    if (this.is_opaque(element)) {
        this.handle_opaque_block(element);
        return;
    }
    if (this.is_indented(element)) {
        this.format_blockquote(element);
        return;
    }
    this.walk(element);
}

proto.format_span = function(element) {
    // This fixes a mysterious wrapper SPAN in IE for the "asap" link.
    if (element.firstChild &&
        element.firstChild.nodeName == 'SPAN' &&
        (! (element.style && element.style.fontWeight != '')) &&
        element.firstChild == element.lastChild
       ) {
        this.walk(element);
        return;
    }
    if (this.is_opaque(element)) {
        this.handle_opaque_phrase(element);
        return;
    }

    var style = element.getAttribute('style') || element.style;
    var style_text = this.squish_style_object_into_string(style);
    if (!style_text) {
        this.pass(element);
        return;
    }

    if (! this.element_has_text_content(element) &&
        ! this.element_has_only_image_content(element)) return;
    var attributes = [ 'line-through', 'bold', 'italic', 'underline' ];
    for (var i = 0; i < attributes.length; i++)
        this.check_style_and_maybe_mark_up(style, attributes[i], 1);
    this.no_following_whitespace();
    this.walk(element);
    for (var i = attributes.length; i >= 0; i--)
        this.check_style_and_maybe_mark_up(style, attributes[i], 2);
}

proto.element_has_text_content = function(element) {
    return element.innerHTML.replace(/<.*?>/g, '')
                            .replace(/&nbsp;/g, '').match(/\S/);
}

proto.element_has_only_image_content = function(element) {
    return    element.childNodes.length == 1
           && element.firstChild.nodeType == 1
           && element.firstChild.tagName.toLowerCase() == 'img';
}

proto.check_style_and_maybe_mark_up = function(style, attribute, open_close) {
    var markup_rule = attribute;
    if (markup_rule == 'line-through')
        markup_rule = 'strike';
    if (this.check_style_for_attribute(style, attribute))
        this.appendOutput(this.config.markupRules[markup_rule][open_close]);
}

proto.check_style_for_attribute = function(style, attribute) {
    var string = this.squish_style_object_into_string(style);
    return string.match("\\b" + attribute + "\\b");
}

proto.squish_style_object_into_string = function(style) {
    if ((style.constructor+'').match('String'))
        return style;
    var interesting_attributes = [
        [ 'font', 'weight' ],
        [ 'font', 'style' ],
        [ 'text', 'decoration' ]
    ];
    var string = '';
    for (var i = 0; i < interesting_attributes.length; i++) {
        var pair = interesting_attributes[i];
        var css = pair[0] + '-' + pair[1];
        var js = pair[0] + pair[1].ucFirst();
        if (style[js])
            string += css + ': ' + style[js] + '; ';
    }
    return string;
}

proto.basic_formatter = function(element, style) {
    var markup = this.config.markupRules[style];
    var handler = markup[0];
    this['handle_' + handler](element, markup);
}

klass.make_empty_formatter = function(style) {
    return function(element) {
        this.basic_formatter(element, style);
    }
}

klass.make_formatter = function(style) {
    return function(element) {
        if (this.element_has_text_content(element) || this.element_has_only_image_content(element) )
            this.basic_formatter(element, style);
    }
}

proto.format_b = klass.make_formatter('bold');
proto.format_strong = proto.format_b;
proto.format_code = klass.make_formatter('code');
proto.format_kbd = proto.format_code;
proto.format_samp = proto.format_code;
proto.format_tt = proto.format_code;
proto.format_var = proto.format_code;
proto.format_i = klass.make_formatter('italic');
proto.format_em = proto.format_i;
proto.format_u = klass.make_formatter('underline');
proto.format_strike = klass.make_formatter('strike');
proto.format_del = proto.format_strike;
proto.format_s = proto.format_strike;
proto.format_hr = klass.make_empty_formatter('hr');
proto.format_h1 = klass.make_formatter('h1');
proto.format_h2 = klass.make_formatter('h2');
proto.format_h3 = klass.make_formatter('h3');
proto.format_h4 = klass.make_formatter('h4');
proto.format_h5 = klass.make_formatter('h5');
proto.format_h6 = klass.make_formatter('h6');
proto.format_pre = klass.make_formatter('pre');

proto.format_p = function(element) {
    if (this.is_indented(element)) {
        this.format_blockquote(element);
        return;
    }
    this.assert_blank_line();
    this.walk(element);
    this.assert_blank_line();
}

proto.format_a = function(element) {
    var label = Wikiwyg.htmlUnescape(element.innerHTML);
    label = label.replace(/<[^>]*?>/g, ' ');
    label = label.replace(/\s+/g, ' ');
    label = label.replace(/^\s+/, '');
    label = label.replace(/\s+$/, '');
    var href = element.getAttribute('href');
    if (! href) href = ''; // Necessary for <a name="xyz"></a>'s
    this.make_wikitext_link(label, href, element);
}

proto.format_table = function(element) {
    this.assert_blank_line();
    this.walk(element);
    this.assert_blank_line();
}

proto.format_tr = function(element) {
    this.walk(element);
    this.appendOutput('|');
    this.insert_new_line();
}

proto.format_td = function(element) {
    this.appendOutput('| ');
    this.no_following_whitespace();
    this.walk(element);
    this.chomp();
    this.appendOutput(' ');
}
proto.format_th = proto.format_td;

// Generic functions on lists taken from the Haskell Prelude.
// See http://xrl.us/jbko
//
// These sorts of thing should probably be moved to some general-purpose
// Javascript library.

function takeWhile(f, a) {
    for (var i = 0; i < a.length; ++i)
        if (! f(a[i])) break;

    return a.slice(0, i);
}

function dropWhile(f, a) {
    for (var i = 0; i < a.length; ++i)
        if (! f(a[i])) break;

    return a.slice(i);
}

proto.previous_line = function() {
    function newline(s) { return s['match'] && s.match(/\n/) }
    function non_newline(s) { return ! newline(s) }

    return this.join_output(
        takeWhile(non_newline,
            dropWhile(newline,
                this.output.slice().reverse()
            )
        ).reverse()
    );
}

proto.make_list = function(element, list_type) {
    if (! this.previous_was_newline_or_start())
        this.insert_new_line();

    this.list_type.push(list_type);
    this.walk(element);
    this.list_type.pop();
    if (this.list_type.length == 0)
        this.assert_blank_line();
}

proto.format_ol = function(element) {
    this.make_list(element, 'ordered');
}

proto.format_ul = function(element) {
    this.make_list(element, 'unordered');
}

proto.format_li = function(element) {
    var level = this.list_type.length;
    if (!level) die("Wikiwyg list error");
    var type = this.list_type[level - 1];
    var markup = this.config.markupRules[type];
    this.appendOutput(markup[1].times(level) + ' ');

    // Nasty ie hack which I don't want to talk about.
    // But I will...
    // *Sometimes* when pulling html out of the designmode iframe it has
    // <LI> elements with no matching </LI> even though the </LI>s existed
    // going in. This needs to be delved into, and we need to see if
    // quirksmode and friends can/should be set somehow on the iframe
    // document for wikiwyg. Also research whether we need an iframe at all on
    // IE. Could we just use a div with contenteditable=true?
    if (Wikiwyg.is_ie &&
        element.firstChild &&
        element.firstChild.nextSibling &&
        element.firstChild.nextSibling.nodeName.match(/^[uo]l$/i))
    {
        try {
            element.firstChild.nodeValue =
              element.firstChild.nodeValue.replace(/ $/, '');
        }
        catch(e) { }
    }

    this.walk(element);

    this.chomp();
    this.insert_new_line();
}

proto.chomp = function() {
    var string;
    while (this.output.length) {
        string = this.output.pop();
        if (typeof(string) != 'string') {
            this.appendOutput(string);
            return;
        }
        if (! string.match(/^\n+>+ $/) && string.match(/\S/))
            break;
    }
    if (string) {
        string = string.replace(/[\r\n\s]+$/, '');
        this.appendOutput(string);
    }
}

proto.collapse = function(string) {
    return string.replace(/[ \u00a0\r\n]+/g, ' ');
}

proto.trim = function(string) {
    return string.replace(/^\s+/, '');
}

proto.insert_new_line = function() {
    var fang = '';
    var indentChar = this.config.markupRules.indent[1];
    var newline = '\n';
    if (this.indent_level > 0) {
        fang = indentChar.times(this.indent_level);
        if (fang.length)
            fang += ' ';
    }
    // XXX - ('\n' + fang) MUST be in the same element in this.output so that
    // it can be properly matched by chomp above.
    if (fang.length && this.first_indent_line) {
        this.first_indent_line = false;
        newline = newline + newline;
    }
    if (this.output.length)
        this.appendOutput(newline + fang);
    else if (fang.length)
        this.appendOutput(fang);
}

proto.previous_was_newline_or_start = function() {
    for (var ii = this.output.length - 1; ii >= 0; ii--) {
        var string = this.output[ii];
        if (typeof(string) != 'string')
            continue;
        return string.match(/\n$/);
    }
    return true;
}

proto.assert_new_line = function() {
    this.chomp();
    this.insert_new_line();
}

proto.assert_blank_line = function() {
    if (! this.should_whitespace()) return
    this.chomp();
    this.insert_new_line();
    this.insert_new_line();
}

proto.assert_space_or_newline = function() {
    if (! this.output.length || ! this.should_whitespace()) return;
    if (! this.previous_output().match(/(\s+|[\(])$/))
        this.appendOutput(' ');
}

proto.no_following_whitespace = function() {
    this.appendOutput({whitespace: 'stop'});
}

proto.should_whitespace = function() {
    return ! this.previous_output().whitespace;
}

// how_far_back defaults to 1
proto.previous_output = function(how_far_back) {
    if (! how_far_back)
        how_far_back = 1;
    var length = this.output.length;
    return length && how_far_back <= length ? this.output[length - how_far_back] : '';
}

proto.handle_bound_phrase = function(element, markup) {
    if (! this.element_has_text_content(element)) return;

    /* If an italics/bold/etc element starts with a
       <br> tag we want to make sure the newline comes _before_ the
       wiki markup we are adding, or we end up with this:

       _
       foo_
    */
    if (element.innerHTML.match(/^\s*<br\s*\/?\s*>/)) {
        this.appendOutput("\n");
        element.innerHTML = element.innerHTML.replace(/^\s*<br\s*\/?\s*>/, '');
    }
    this.appendOutput(markup[1]);
    this.no_following_whitespace();
    this.walk(element);
    // assume that walk leaves no trailing whitespace.
    this.appendOutput(markup[2]);
}

// XXX - A very promising refactoring is that we don't need the trailing
// assert_blank_line in block formatters.
proto.handle_bound_line = function(element,markup) {
    this.assert_blank_line();
    this.appendOutput(markup[1]);
    this.walk(element);
    this.appendOutput(markup[2]);
    this.assert_blank_line();
}

proto.handle_start_line = function (element, markup) {
    this.assert_blank_line();
    this.appendOutput(markup[1]);
    this.walk(element);
    this.assert_blank_line();
}

proto.handle_start_lines = function (element, markup) {
    var text = element.firstChild.nodeValue;
    if (!text) return;
    this.assert_blank_line();
    text = text.replace(/^/mg, markup[1]);
    this.appendOutput(text);
    this.assert_blank_line();
}

proto.handle_line_alone = function (element, markup) {
    this.assert_blank_line();
    this.appendOutput(markup[1]);
    this.assert_blank_line();
}

proto.COMMENT_NODE_TYPE = 8;
proto.get_wiki_comment = function(element) {
    for (var node = element.firstChild; node; node = node.nextSibling) {
        if (node.nodeType == this.COMMENT_NODE_TYPE
            && node.data.match(/^\s*wiki/)
        ) {
            return node;
        }
    }
    return null;
}

proto.is_indented = function (element) {
    var margin = parseInt(element.style.marginLeft);
    return margin > 0;
}

proto.is_opaque = function(element) {
    var comment = this.get_wiki_comment(element);
    if (!comment) return false;

    var text = comment.data;
    if (text.match(/^\s*wiki:/)) return true;
    return false;
}

proto.handle_opaque_phrase = function(element) {
    var comment = this.get_wiki_comment(element);
    if (comment) {
        var text = comment.data;
        text = text.replace(/^ wiki:\s+/, '')
                   .replace(/-=/g, '-')
                   .replace(/==/g, '=')
                   .replace(/\s$/, '')
                   .replace(/\{(\w+):\s*\}/, '{$1}');
        this.appendOutput(Wikiwyg.htmlUnescape(text))
        this.smart_trailing_space(element);
    }
}

proto.smart_trailing_space = function(element) {
    var next = element.nextSibling;
    if (! next) return;
    if (next.nodeType == 1) {
        if (next.nodeName != 'BR') {
            this.appendOutput(' ');
        }
    }
    else if (next.nodeType == 3) {
        if (next.nodeValue.match(/^\w/))
            this.appendOutput(' ');
        else if (! next.nodeValue.match(/^\s/))
            this.no_following_whitespace();
    }
}

proto.handle_opaque_block = function(element) {
    var comment = this.get_wiki_comment(element);
    if (!comment) return;

    var text = comment.data;
    text = text.replace(/^\s*wiki:\s+/, '');
    this.appendOutput(text);
}

proto.make_wikitext_link = function(label, href, element) {
    var before = this.config.markupRules.link[1];
    var after  = this.config.markupRules.link[2];

	// handle external links
	if (this.looks_like_a_url(href)) {
		before = this.config.markupRules.www[1];
		after = this.config.markupRules.www[2];
	}

    this.assert_space_or_newline();
    if (! href) {
        this.appendOutput(label);
    }
    else if (href == label) {
        this.appendOutput(href);
    }
    else if (this.href_is_wiki_link(href)) {
        if (this.camel_case_link(label))
            this.appendOutput(label);
        else
            this.appendOutput(before + label + after);
    }
    else {
        this.appendOutput(before + href + ' ' + label + after);
    }
}

proto.camel_case_link = function(label) {
    if (! this.config.supportCamelCaseLinks)
        return false;
    return label.match(/[a-z][A-Z]/);
}

proto.href_is_wiki_link = function(href) {
    if (! this.looks_like_a_url(href))
        return true;
    if (! href.match(/\?/))
        return false;
    if (href.match(/\/static\//) && href.match(/\/js-test\//))
        href = location.href;
    var no_arg_input   = href.split('?')[0];
    var no_arg_current = location.href.split('?')[0];
    if (no_arg_current == location.href)
        no_arg_current =
          location.href.replace(new RegExp(location.hash), '');
    return no_arg_input == no_arg_current;
}

proto.looks_like_a_url = function(string) {
    return string.match(/^(http|https|ftp|irc|mailto|file):/);
}

/*==============================================================================
Support for Internet Explorer in Wikiwyg.Wikitext
 =============================================================================*/
if (Wikiwyg.is_ie) {

proto.setHeightOf = function() {
    // XXX hardcode this until we can keep window from jumping after button
    // events.
    this.textarea.style.height = '200px';
}

proto.initializeObject = function() {
    this.initialize_object();
    this.area.addBehavior(this.config.javascriptLocation + "Selection.htc");
}

} // end of global if
// BEGIN ../../../js-modules/Wikiwyg-copy/lib/Wikiwyg/Wysiwyg.js
/*==============================================================================
This Wikiwyg mode supports a DesignMode wysiwyg editor with toolbar buttons

COPYRIGHT:

    Copyright (c) 2005 Socialtext Corporation
    655 High Street
    Palo Alto, CA 94301 U.S.A.
    All rights reserved.

Wikiwyg is free software.

This library is free software; you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or (at
your option) any later version.

This library is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
General Public License for more details.

    http://www.gnu.org/copyleft/lesser.txt

 =============================================================================*/

proto = new Subclass('Wikiwyg.Wysiwyg', 'Wikiwyg.Mode');

proto.classtype = 'wysiwyg';
proto.modeDescription = 'Wysiwyg';

proto.config = {
    useParentStyles: true,
    useStyleMedia: 'wikiwyg',
    iframeId: null,
    iframeObject: null,
    disabledToolbarButtons: [],
    editHeightMinimum: 150,
    editHeightAdjustment: 1.3,
    clearRegex: null
};

proto.initializeObject = function() {
    this.edit_iframe = this.get_edit_iframe();
    this.div = this.edit_iframe;
}

proto.fromHtml = function(html) {
    var dom = document.createElement('div');
    dom.innerHTML = html;
    this.sanitize_dom(dom);
    this.set_inner_html(dom.innerHTML);
}

proto.toHtml = function(func) {
    func(this.get_inner_html());
}

// This is needed to work around the broken IMGs in Firefox design mode.
// Works harmlessly on IE, too.
// TODO - IMG URLs that don't match /^\//
proto.fix_up_relative_imgs = function() {
    var base = location.href.replace(/(.*?:\/\/.*?\/).*/, '$1');
    var imgs = this.get_edit_document().getElementsByTagName('img');
    for (var ii = 0; ii < imgs.length; ++ii)
        imgs[ii].src = imgs[ii].src.replace(/^\//, base);
}

proto.enableThis = function() {
    Wikiwyg.Mode.prototype.enableThis.call(this);
    this.edit_iframe.style.border = '1px black solid';
    this.edit_iframe.width = '100%';
    this.setHeightOf(this.edit_iframe);
    this.fix_up_relative_imgs();
    if (!Wikiwyg.is_ie)
        this.get_edit_document().designMode = 'on';
    this.apply_stylesheets();
    this.enable_keybindings();
    this.clear_inner_html();
}

proto.clear_inner_html = function() {
    var inner_html = this.get_inner_html();
    var clear = this.config.clearRegex;
    if (clear && inner_html.match(clear))
        this.set_inner_html('');
}

proto.get_keybinding_area = function() {
    return this.get_edit_document();
}

proto.get_edit_iframe = function() {
    var iframe;
    if (this.config.iframeId) {
        iframe = document.getElementById(this.config.iframeId);
        iframe.iframe_hack = true;
    }
    else if (this.config.iframeObject) {
        iframe = this.config.iframeObject;
        iframe.iframe_hack = true;
    }
    else {
        // XXX in IE need to wait a little while for iframe to load up
        iframe = document.createElement('iframe');
    }
    return iframe;
}

proto.get_edit_window = function() { // See IE, below
    return this.edit_iframe.contentWindow;
}

proto.get_edit_document = function() { // See IE, below
    return this.get_edit_window().document;
}

proto.get_inner_html = function() {
    return this.get_edit_document().body.innerHTML;
}

proto.set_inner_html = function(html) {
    this.get_edit_document().body.innerHTML = html;
}

proto.apply_stylesheets = function() {
    var styles = document.styleSheets;
    var head   = this.get_edit_document().getElementsByTagName("head")[0];

    for (var i = 0; i < styles.length; i++) {
        var style = styles[i];

        if (style.href == location.href)
            this.apply_inline_stylesheet(style, head);
        else
            if (this.should_link_stylesheet(style))
                this.apply_linked_stylesheet(style, head);
    }
}

proto.apply_inline_stylesheet = function(style, head) {
    var style_string = "";
    for ( var i = 0 ; i < style.cssRules.length ; i++ ) {
        if ( style.cssRules[i].type == 3 ) {
            // IMPORT_RULE

            /* It's pretty strange that this doesnt work.
               That's why Ajax.get() is used to retrive the css text.

            this.apply_linked_stylesheet({
                href: style.cssRules[i].href,
                type: 'text/css'
            }, head);
            */

            style_string += Ajax.get(style.cssRules[i].href);
        } else {
            style_string += style.cssRules[i].cssText + "\n";
        }
    }
    if (style_string.length > 0) {
        style_string += "\nbody { padding: 5px; }\n";
        this.append_inline_style_element(style_string, head);
    }
}

proto.append_inline_style_element = function(style_string, head) {
    // Add a body padding so words are not touching borders.
    var style_elt = document.createElement("style");
    style_elt.setAttribute("type", "text/css");
    if ( style_elt.styleSheet ) { /* IE */
        style_elt.styleSheet.cssText = style_string;
    }
    else { /* w3c */
        var style_text = document.createTextNode(style_string);
        style_elt.appendChild(style_text);
        head.appendChild(style_elt);
    }
    // XXX This doesn't work in IE!!
    // head.appendChild(style_elt);
}

proto.should_link_stylesheet = function(style, head) {
        var media = style.media;
        var config = this.config;
        var media_text = media.mediaText ? media.mediaText : media;
        var use_parent =
             ((!media_text || media_text == 'screen') &&
             config.useParentStyles);
        var use_style = (media_text && (media_text == config.useStyleMedia));
        if (!use_parent && !use_style) // TODO: simplify
            return false;
        else
            return true;
}

proto.apply_linked_stylesheet = function(style, head) {
    var link = Wikiwyg.createElementWithAttrs(
        'link', {
            href:  style.href,
            type:  style.type,
            media: 'screen',
            rel:   'STYLESHEET'
        }, this.get_edit_document()
    );
    head.appendChild(link);
}

proto.process_command = function(command) {
    if (this['do_' + command])
        this['do_' + command](command);
    if (! Wikiwyg.is_ie)
        this.get_edit_window().focus();
}

proto.exec_command = function(command, option) {
    this.get_edit_document().execCommand(command, false, option);
}

proto.format_command = function(command) {
    this.exec_command('formatblock', '<' + command + '>');
}

proto.do_bold = proto.exec_command;
proto.do_italic = proto.exec_command;
proto.do_underline = proto.exec_command;
proto.do_strike = function() {
    this.exec_command('strikethrough');
}
proto.do_hr = function() {
    this.exec_command('inserthorizontalrule');
}
proto.do_ordered = function() {
    this.exec_command('insertorderedlist');
}
proto.do_unordered = function() {
    this.exec_command('insertunorderedlist');
}
proto.do_indent = proto.exec_command;
proto.do_outdent = proto.exec_command;

proto.do_h1 = proto.format_command;
proto.do_h2 = proto.format_command;
proto.do_h3 = proto.format_command;
proto.do_h4 = proto.format_command;
proto.do_h5 = proto.format_command;
proto.do_h6 = proto.format_command;
proto.do_pre = proto.format_command;
proto.do_p = proto.format_command;

proto.do_table = function() {
    var html =
        '<table><tbody>' +
        '<tr><td>A</td>' +
            '<td>B</td>' +
            '<td>C</td></tr>' +
        '<tr><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td></tr>' +
        '<tr><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td></tr>' +
        '</tbody></table>';
    this.insert_html(html);
}

proto.insert_html = function(html) { // See IE
    this.get_edit_window().focus();
    this.exec_command('inserthtml', html);
}

proto.do_unlink = proto.exec_command;

proto.do_link = function() {
    var selection = this.get_link_selection_text();
    if (! selection) return;
    var url;
    var match = selection.match(/(.*?)\b((?:http|https|ftp|irc|file):\/\/\S+)(.*)/);
    if (match) {
        if (match[1] || match[3]) return null;
        url = match[2];
    }
    else {
        url = '?' + escape(selection);
    }
    this.exec_command('createlink', url);
}

proto.do_www = function() {
    var selection = this.get_link_selection_text();
	if (selection != null) {
		var  url =  prompt("Please enter a link", "Type in your link here");
		this.exec_command('createlink', url);
	}
}

proto.get_selection_text = function() { // See IE, below
    return this.get_edit_window().getSelection().toString();
}

proto.get_link_selection_text = function() {
    var selection = this.get_selection_text();
    if (! selection) {
        alert("Please select the text you would like to turn into a link.");
        return;
    }
    return selection;
}

/*==============================================================================
Support for Internet Explorer in Wikiwyg.Wysiwyg
 =============================================================================*/
if (Wikiwyg.is_ie) {

proto.get_edit_window = function() {
    return this.edit_iframe;
}

proto.get_edit_document = function() {
    return this.edit_iframe.contentWindow.document;
}

proto.onbeforedeactivate = function() {
    this.__range = this.get_edit_document().selection.createRange();
}

proto.onactivate = function() {
    this.__range = undefined;
}

proto.get_selection_text = function() {
    var selection = this.get_edit_document().selection;

    if (selection != null) {
        this.__range = selection.createRange();
        return this.__range.htmlText;
    }
    return '';
}

proto.insert_html = function(html) {
    var doc = this.get_edit_document();
    var range = this.__range;
    if (!range) {
        range = this.get_edit_document().selection.createRange();
    }
    if (range.boundingTop == 2 && range.boundingLeft == 2)
        return;
    range.pasteHTML(html);
    range.collapse(false);
    range.select();
    if (this.__range) {
        this.__range = null;
    }
}

proto.get_inner_html = function( cb ) {
    if ( cb ) {
        this.get_inner_html_async( cb );
        return;
    }
    return this.get_editable_div().innerHTML;
}

proto.get_editable_div = function () {
    if (!this._editable_div) {
        this._editable_div = this.get_edit_document().createElement('div');
        this._editable_div.contentEditable = true;
        this._editable_div.style.overflow = 'auto';
        this._editable_div.style.border = 'none'
        this._editable_div.id = 'wysiwyg-editable-div';
        this._editable_div.onmousedown = function () { this.focus() };
        this._editable_div.onbeforedeactivate = this.onbeforedeactivate.bind(this);
        this._editable_div.onactivate = this.onactivate.bind(this);
        this.get_edit_document().body.appendChild(this._editable_div);
    }
    return this._editable_div;
}

proto.get_inner_html_async = function( cb ) {
    var self = this;
    var doc = this.get_edit_document();
    if ( doc.readyState == 'loading' ) {
        setTimeout( function() {
            self.get_inner_html(cb);
        }, 50);
    } else {
        var html = this.get_editable_div().innerHTML;
        cb(html);
        return html;
    }
}

proto.set_inner_html = function(html) {
    var self = this;
    var doc = this.get_edit_document();
    if ( doc.readyState == 'loading' ) {
        setTimeout( function() {
            self.set_inner_html(html);
        }, 50);
    } else {
        this.get_editable_div().innerHTML = html;
    }
}

// Use IE's design mode default key bindings for now.
proto.enable_keybindings = function() {}

} // end of global if
// BEGIN ../../../js-modules/Wikiwyg-copy/lib/Wikiwyg/HTML.js

/*==============================================================================
This Wikiwyg mode supports a simple HTML editor

COPYRIGHT:

    Copyright (c) 2005 Socialtext Corporation 
    655 High Street
    Palo Alto, CA 94301 U.S.A.
    All rights reserved.

Wikiwyg is free software. 

This library is free software; you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or (at
your option) any later version.

This library is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
General Public License for more details.

    http://www.gnu.org/copyleft/lesser.txt

 =============================================================================*/

proto = new Subclass('Wikiwyg.HTML', 'Wikiwyg.Mode');

proto.classtype = 'html';
proto.modeDescription = 'HTML';

proto.config = {
    textareaId: null
}

proto.initializeObject = function() {
    this.div = document.createElement('div');
    if (this.config.textareaId)
        this.textarea = document.getElementById(this.config.textareaId);
    else
        this.textarea = document.createElement('textarea');
    this.div.appendChild(this.textarea);
}

proto.enableThis = function() {
    Wikiwyg.Mode.prototype.enableThis.call(this);
    this.textarea.style.width = '100%';
    this.textarea.style.height = '200px';
}

proto.fromHtml = function(html) {
    this.textarea.value = this.sanitize_html(html);
}

proto.toHtml = function(func) {
    func(this.textarea.value);
}

proto.sanitize_html = function(html) {
    return html;
}

proto.process_command = function(command) {};
// BEGIN Wikiwyg/Socialtext.js
/*==============================================================================
Wikiwyg - Turn any HTML div into a wikitext /and/ wysiwyg edit area.

DESCRIPTION:

Wikiwyg is a Javascript library that can be easily integrated into any
wiki or blog software. It offers the user multiple ways to edit/view a
piece of content: Wysiwyg, Wikitext, Raw-HTML and Preview.

The library is easy to use, completely object oriented, configurable and
extendable.

See the Wikiwyg documentation for details.

AUTHORS:

    Ingy döt Net <ingy@cpan.org>
    Casey West <casey@geeknest.com>
    Chris Dent <cdent@burningchrome.com>
    Matt Liggett <mml@pobox.com>
    Ryan King <rking@panoptic.com>
    Dave Rolsky <autarch@urth.org>

COPYRIGHT:

    Copyright (c) 2005 Socialtext Corporation
    655 High Street
    Palo Alto, CA 94301 U.S.A.
    All rights reserved.

Wikiwyg is free software.

This library is free software; you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or (at
your option) any later version.

This library is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
General Public License for more details.

    http://www.gnu.org/copyleft/lesser.txt

 =============================================================================*/

if (! window.wikiwyg_nlw_debug)
    window.wikiwyg_nlw_debug = false;

var WW_SIMPLE_MODE = 'Wikiwyg.Wysiwyg.Socialtext';
var WW_ADVANCED_MODE = 'Wikiwyg.Wikitext.Socialtext';
var WW_PREVIEW_MODE = 'Wikiwyg.Preview.Socialtext';
var WW_HTML_MODE = 'Wikiwyg.HTML';

Wikiwyg.browserIsSupported = (
    Wikiwyg.is_gecko ||
    Wikiwyg.is_ie ||
    Wikiwyg.is_safari
);

Wikiwyg.is_old_firefox = (
    Wikiwyg.ua.indexOf('firefox/1.0.7') != -1 &&
    Wikiwyg.ua.indexOf('safari') == -1 &&
    Wikiwyg.ua.indexOf('konqueror') == -1
);

function setup_wikiwyg() {
    if (! Wikiwyg.browserIsSupported) return;

    // The div that holds the page HTML
    var myDiv = $('wikiwyg-page-content');
    if (! myDiv)
        return false;
    if (window.wikiwyg_nlw_debug)
        Wikiwyg.Socialtext.prototype.modeClasses.push(WW_HTML_MODE);

    // Get the "opening" mode from a cookie, or reasonable default
    var firstMode = Cookie.get('first_wikiwyg_mode')
    if (firstMode == null ||
        (firstMode != WW_SIMPLE_MODE && firstMode != WW_ADVANCED_MODE)
    ) firstMode = WW_SIMPLE_MODE;

    if ( Wikiwyg.is_safari ) firstMode = WW_ADVANCED_MODE;

    // Wikiwyg configuration
    var myConfig = {
        doubleClickToEdit: false,
        firstMode: firstMode,
        javascriptLocation: nlw_make_static_path('/javascript/'),
        toolbar: {
            imagesLocation: nlw_make_static_path('/images/wikiwyg_icons/')
        },
        wysiwyg: {
            iframeId: 'st-page-editing-wysiwyg',
            editHeightMinimum: 200,
            editHeightAdjustment: 1.3
        },
        wikitext: {
            clearRegex: /^Replace this text with your own.\s*$/,
            textareaId: 'st-page-editing-pagebody-decoy'
        },
        preview: {
            divId: 'st-page-preview'
        }
    };

    // The Wikiwyg object must be stored as a global (aka window property)
    // so that it stays in scope for the duration of the window. The Wikiwyg
    // code should not make reference to the global wikiwyg variable, though,
    // since that breaks encapsulation. (It's an easy trap to fall into.)
    var ww = new Wikiwyg.Socialtext();
    window.wikiwyg = ww;

    ww.createWikiwygArea(myDiv, myConfig);
    if (! ww.enabled) return;

    ww.message = new Wikiwyg.MessageCenter();

    // node handles
    var edit_bar = $('st-editing-tools-edit'); // XXX I think this is wrong
    var edit_link = $('st-edit-button-link');
    var save_link = $('st-save-button-link');
    var html_link = $('edit-wikiwyg-html-link');
    var preview_link = $('st-preview-button-link');
    var cancel_link = $('st-cancel-button-link');
    var wysiwyg_link = $('st-mode-wysiwyg-button');
    var wikitext_link = $('st-mode-wikitext-button');

    ww.wikitext_link = wikitext_link;

    Wikiwyg.setup_newpage();

    // Control functions
    var noop = function() { return false };

    // For example, because of a unregistered user on a self-register space:
    if (!edit_bar || !edit_link)
        return;
    // XXX use a class!

    Wikiwyg.Socialtext.edit_bar = edit_bar;
    // XXX Surely we could use plain HTML here
    Wikiwyg.Socialtext.loading_bar = document.createElement("div");
    Wikiwyg.Socialtext.loading_bar.innerHTML =
        '<span style="color: red" id="loading-message">Loading...</span>';
    Wikiwyg.Socialtext.loading_bar.style.display = 'none';
    Wikiwyg.Socialtext.edit_bar.parentNode.appendChild(Wikiwyg.Socialtext.loading_bar);

    // XXX start_nlw_wikiwyg goes in the object because display_edit.js
    // wants it there.
    ww.start_nlw_wikiwyg = function() {
        Wikiwyg.transition_message({
            show: true,
            message: "Loading editor..."
        });
        try {
            if (Wikiwyg.is_safari) {
                delete ww.current_wikitext;
            }
            if (Wikiwyg.is_safari || Wikiwyg.is_old_firefox) {
                $('st-page-editing-uploadbutton').style.display = 'none';
            }
            $('st-display-mode-container').style.display = 'none';
            $('st-edit-mode-container').style.display = 'block';
            Page.refresh_page_content();
            myDiv.innerHTML = $('st-page-content').innerHTML;
            ww.set_edit_tips_span_display('none');
            ww.editMode();
            ww.preview_link_reset();
            Element.hide('st-pagetools');
            Wikiwyg.transition_message({
                show: false
            });
            Element.setStyle('st-editing-tools-display', {display: 'none'});
            Element.setStyle('st-editing-tools-edit', {display: 'block'});
            Element.setStyle('wikiwyg_toolbar', {display: 'block'});
            if (Element.visible('st-page-boxes')) {
                Element.setStyle('st-page-maincontent', {marginRight: '240px'});
            }
            nlw_edit_controls_visible = true;
            ww.enableLinkConfirmations();
            window.onresize = function () {
                ww.resizeEditor();
            }
        } catch(e) {
            alert(e);    // XXX - Useful for debugging
        }
        return false;
    }

    // XXX observe
    edit_link.onclick = ww.start_nlw_wikiwyg;

    if ($('st-edit-actions-below-fold-edit')) {
        $('st-edit-actions-below-fold-edit').onclick = function () {
            ww.start_nlw_wikiwyg();
        };
    }
    if (Socialtext.double_click_to_edit) {
        $('st-page-content').ondblclick = ww.start_nlw_wikiwyg;
    }

    // XXX Observe
    save_link.onclick = function() {
        return ww.saveButtonHandler();
    }

    // XXX observe
    cancel_link.onclick = function() {
        try {
            if (ww.contentIsModified()) {
                // If it's not confirmed somewhere else, do it right here.
                if (ww.confirmed != true && !confirm("If you click 'OK', all edit changes will be lost!"))
                    return false;
            }
            if (Socialtext.new_page) {
                window.location = '?action=homepage';
            }
            $('st-edit-mode-container').style.display = 'none';
            $('st-display-mode-container').style.display = 'block';
            ww.cancelEdit();
            ww.preview_link_reset();
            window.EditQueue.reset_dialog();
            window.TagQueue.clear_list();
            Element.show('st-pagetools');
            Element.setStyle('st-editing-tools-display', {display: 'block'});
            Element.setStyle('st-editing-tools-edit', {display: 'none'});
            Element.setStyle('st-page-maincontent', {marginRight: '0px'});

            $(Page.element.content).style.height = "100%";

            // XXX WTF? ENOFUNCTION
            //do_post_cancel_tidying();
            ww.disableLinkConfirmations();
            if (location.href.match(/caller_action=weblog_display;?/))
                location.href = 'index.cgi?action=weblog_redirect;start=' +
                    encodeURIComponent(location.href);
        } catch(e) {}
        return false;
    }

    // XXX observe
    preview_link.onclick = function() {
        return ww.preview_link_action();
    }

    // XXX observe
    if (window.wikiwyg_nlw_debug) {
        html_link.onclick = function() {
            ww.switchMode(WW_HTML_MODE);
            return false;
        }
    }

    wysiwyg_link.onclick = function() {
        ww.button_enabled_func(WW_SIMPLE_MODE)();
        return false;
    }

    // Disable simple mode button for Safari browser.
    if ( Wikiwyg.is_safari )  {
        wysiwyg_link.style.textDecoration = 'line-through';
        // XXX stopObserving
        wysiwyg_link.onclick = function() {
            alert("Safari does not support simple mode editing");
            return false;
        }
    }

    // XXX observe
    wikitext_link.onclick = function() {
        ww.button_enabled_func(WW_ADVANCED_MODE)();
        return false;
    }

    ww.modeButtonMap = {};
    ww.modeButtonMap[WW_SIMPLE_MODE] = wysiwyg_link;
    ww.modeButtonMap[WW_ADVANCED_MODE] = wikitext_link;
    ww.modeButtonMap[WW_PREVIEW_MODE] = preview_link;
    ww.modeButtonMap[WW_HTML_MODE] = html_link;

    if (Socialtext.new_page || Socialtext.start_in_edit_mode || location.hash.toLowerCase() == '#edit' ) {
        setTimeout(edit_link.onclick, 1);
    }
}

function try_wikiwyg() {
    try {
        setup_wikiwyg();
    } catch(e) {
        alert('Error: ' + e);
    }
}

Event.observe(window, 'load', try_wikiwyg);

Wikiwyg.in_transition = false;
Wikiwyg.transition_message = function (arg) {
    var msg = $('st-editing-tools-transition-message');
    var toolbar = $('st-editing-tools-edit');
    if (arg.message) {
        Element.update(msg, arg.message);
    }
    if (arg.show) {
        Element.setStyle(toolbar, {display: 'none'});
        Element.setStyle(msg, {display: 'block'});
        Wikiwyg.in_transition = true;
    } else {
        Element.setStyle(msg, {display: 'none'});
        Element.setStyle(toolbar, {display: 'block'});
        Wikiwyg.in_transition = false;
    }
};

Wikiwyg.setup_newpage = function() {
    var newpage_saveName;
    var newpage_saveButton;
    var newpage_cancelButton;
    var newpage_duplicate_saveButton;
    var newpage_duplicate_cancelButton;
    if (Socialtext.new_page) {
        newpage_saveButton = $('st-newpage-save-savebutton');
        newpage_saveButton.onclick = function() {
            return wikiwyg.newpage_saveClicked();
        };

        newpage_cancelButton = $('st-newpage-save-cancelbutton');
        newpage_cancelButton.onclick = function() {
            return wikiwyg.newpage_cancel();
        };

        // XXX Observe
        newpage_saveName = $('st-newpage-save-pagename');
        newpage_saveName.onkeyup = function(event) {
            wikiwyg.newpage_keyupHandler(event);
        }

        newpage_duplicate_okButton = $('st-newpage-duplicate-okbutton');
        newpage_duplicate_okButton.onclick = function() {
            wikiwyg.newpage_duplicate_ok();
            return false;
        };

        newpage_duplicate_cancelButton = $('st-newpage-duplicate-cancelbutton');
        newpage_duplicate_cancelButton.onclick = function() {
            wikiwyg.newpage_duplicate_cancel();
            return false;
        };

        // XXX Observe
        $('st-newpage-duplicate-pagename').onkeyup = function(event) {
            wikiwyg.newpage_duplicate_pagename_keyupHandler(event);
        }
        $('st-newpage-duplicate-option-different').onkeyup = function(event) {
            wikiwyg.newpage_duplicate_keyupHandler(event);
        }
        $('st-newpage-duplicate-option-suggest').onkeyup = function(event) {
            wikiwyg.newpage_duplicate_keyupHandler(event);
        }
        $('st-newpage-duplicate-option-append').onkeyup = function(event) {
            wikiwyg.newpage_duplicate_keyupHandler(event);
        }

    }
}

/*==============================================================================
Socialtext Wikiwyg subclass
 =============================================================================*/
proto = new Subclass('Wikiwyg.Socialtext', 'Wikiwyg');

proto.default_config = {
    toolbarClass: 'Wikiwyg.Toolbar.Socialtext',
    modeClasses: [ WW_SIMPLE_MODE, WW_ADVANCED_MODE, WW_PREVIEW_MODE ]
}

if (window.wikiwyg_nlw_debug)
    proto.default_config.modeClasses.push(WW_HTML_MODE);

proto.placeToolbar = function(toolbar_div) {
    var wikiwyg_edit_page_bar =
        $('st-page-editing-toolbar');
    if (! wikiwyg_edit_page_bar) {
        return;
    }
    wikiwyg_edit_page_bar.appendChild(toolbar_div);
}

proto.resizeEditor = function () {
    this.modeByName(WW_SIMPLE_MODE).setHeightOf(this.modeByName(WW_SIMPLE_MODE).edit_iframe);
    this.modeByName(WW_ADVANCED_MODE).setHeightOfEditor();
}

proto.preview_link_text = 'Preview';
proto.preview_link_more = 'Edit More';

proto.preview_link_action = function() {
    var preview = this.modeButtonMap[WW_PREVIEW_MODE];
    var current = this.current_mode;

    preview.innerHTML = this.preview_link_more;
    Wikiwyg.hideById('st-edit-mode-toolbar');

    var self = this;
    preview.onclick = this.button_disabled_func();
    this.enable_edit_more = function() {
        preview.onclick = function () {
            if (Element.visible('st-page-boxes')) {
                Element.setStyle('st-page-maincontent', {marginRight: '240px'});
            }
            self.switchMode(current.classname);
            self.preview_link_reset();
            return false;
        }
    }
    this.modeByName(WW_PREVIEW_MODE).div.innerHTML = "";
    this.switchMode(WW_PREVIEW_MODE)
    this.disable_button(current.classname);

    if (window.wikiwyg_nlw_double_click_to_edit)
        this.mode_objects[WW_PREVIEW_MODE].div.ondblclick = preview.onclick;

    Element.setStyle('st-page-maincontent', {marginRight: '0px'});
    return false;
}

proto.preview_link_reset = function() {
    var preview = this.modeButtonMap[WW_PREVIEW_MODE];

    preview.innerHTML = this.preview_link_text;
    Wikiwyg.showById('st-edit-mode-toolbar');

    var self = this;
    preview.onclick = function() {
        return self.preview_link_action();
    }
}

proto.enable_button = function(mode_name) {
    if (mode_name == WW_PREVIEW_MODE) return;
    var button = this.modeButtonMap[mode_name];
    if (! button) return; // for when the debugging button doesn't exist
    button.style.fontWeight = 'normal';
    button.style.background = 'none';
    button.style.textDecoration = 'underline';
    button.style.color = 'blue';  // XXX should not be hardcoded
    button.onclick = this.button_enabled_func(mode_name);
}

proto.button_enabled_func = function(mode_name) {
    var self = this;
    return function() {
        self.message.clear();
        self.switchMode(mode_name);
        for (var mode in self.modeButtonMap) {
            if (mode != mode_name)
                self.enable_button(mode);
        }
        self.preview_link_reset();
        Cookie.set('first_wikiwyg_mode', mode_name);
        self.setFirstModeByName(mode_name);
        return false;
    }
}

proto.disable_button = function(mode_name) {
    if (mode_name == WW_PREVIEW_MODE) return;
    var button = this.modeButtonMap[mode_name];
    button.style.fontWeight = 'bold';
    button.style.textDecoration = 'none';
    button.style.background = 'none';
    button.style.color = 'black';
    button.onclick = this.button_disabled_func(mode_name);
}

proto.button_disabled_func = function(mode_name) {
    return function() { return false }
}

proto.newpage_keyupHandler = function(event) {
    var key;

    if (window.event) {
        key = window.event.keyCode;
    }
    else if (event.which) {
        key = event.which;
    }

    if (key == Event.KEY_RETURN) {
        this.newpage_saveClicked();
        return false;
    }
}

proto.newpage_duplicate_pagename_keyupHandler = function(event) {
    $('st-newpage-duplicate-option-different').checked = true;
    $('st-newpage-duplicate-option-suggest').checked = false;
    $('st-newpage-duplicate-option-append').checked = false;
    return this.newpage_duplicate_keyupHandler(event);
}

proto.newpage_duplicate_keyupHandler = function(event) {
    var key;

    if (window.event) {
        key = window.event.keyCode;
    }
    else if (event.which) {
        key = event.which;
    }

    if (key == Event.KEY_RETURN) {
        this.newpage_duplicate_ok();
        return false;
    }
}

proto.newpage_display_duplicate_dialog = function(page_name) {
    Element.update('st-newpage-duplicate-suggest',
        Socialtext.username + ': ' + page_name
    );
    Element.update('st-newpage-duplicate-appendname', page_name);
    Element.update('st-newpage-duplicate-link', page_name);
    $('st-newpage-duplicate-link').href = Page.ContentUri() + "?" + page_name;
    $('st-newpage-duplicate-link').target = page_name;
    $('st-newpage-duplicate-pagename').value = page_name;
    $('st-newpage-duplicate-option-different').checked = true;
    $('st-newpage-duplicate-option-suggest').checked = false;
    $('st-newpage-duplicate-option-append').checked = false;
    $('st-newpage-duplicate').style.display = 'block';
    $('st-newpage-duplicate-pagename').focus();

    var divs = {
        wrapper: $('st-newpage-duplicate'),
        background: $('st-newpage-duplicate-overlay'),
        content: $('st-newpage-duplicate-interface'),
        contentWrapper: $('st-newpage-duplicate-interface').parentNode
    }
    Widget.Lightbox.show({ divs:divs, effects:['RoundedCorners'] });
    divs.contentWrapper.style.width="520px";

    return false;
}

proto.newpage_save = function(page_name, pagename_editfield) {
    var saved = false;
    page_name = trim(page_name);
    if (page_name.length == 0) {
        alert('You must specify a page name');
        if (pagename_editfield) {
            pagename_editfield.focus();
        }
    }
    else if (is_reserved_pagename(page_name)) {
        alert('"' + page_name + '" is a reserved page name. Please use a different name');
        if (pagename_editfield) {
            pagename_editfield.focus();
        }
    }
    else {
        if (Page.active_page_exists(page_name)) {
            this.newpage_cancel();
            this.newpage_display_duplicate_dialog(page_name);
        } else {
            var formPageNameField = $('st-page-editing-pagename');
            formPageNameField.value = page_name;
            this.saveContent();
            saved = true;
        }
    }
    return saved;
}

proto.saveContent = function() {
    Wikiwyg.Socialtext.edit_bar.style.display = 'none';
    Wikiwyg.Socialtext.loading_bar.innerHTML =
        '<span style="color: red" id="saving-message">Saving...</span>';
    Wikiwyg.Socialtext.loading_bar.style.display = 'block';
    this.saveChanges();
}


proto.newpage_saveClicked = function() {
    var edit_field = $('st-newpage-save-pagename');
    var saved = this.newpage_save(edit_field.value, edit_field);
    if (saved) {
        $('st-newpage-save').style.display = 'none';
    }
    return saved;
}

proto.newpage_cancel = function() {
    $('st-newpage-save').style.display = 'none';
    return false;
}

proto.newpage_duplicate_ok = function() {
    // Ok - this is the suck. I am duplicating the radio buttons in the HTML form here
    // in the JavaScript code. Damn deadlines
    var options = ['different', 'suggest', 'append'];
    var option;
    for (var i=0; i< options.length; i++) {
        var node = $('st-newpage-duplicate-option-' + options[i]);
        if (node.checked) {
            option = node.value;
            break;
        }
    }
    if (!option) {
        alert('You must select one of the options or click cancel');
        return;
    }
    switch(option) {
        case 'different':
            var edit_field = $('st-newpage-duplicate-pagename');
            if (this.newpage_save(edit_field.value, edit_field)) {
                $('st-newpage-duplicate').style.display = 'none';
            } else {
                if (!is_reserved_pagename(edit_field.value)) {
                    Element.addClassName(
                        'st-newpage-duplicate-emphasis',
                        'st-newpage-duplicate-emphasis'
                    );
                }
            }
            break;
        case 'suggest':
            var suggest_name = $('st-newpage-duplicate-suggest');
            if (this.newpage_save(suggest_name.innerHTML)) {
                $('st-newpage-duplicate').style.display = 'none';
            }
            break;
        case 'append':
            $('st-page-editing-append').value='bottom';
            var pagename = $('st-newpage-duplicate-appendname').innerHTML;
            var formPageNameField = $('st-page-editing-pagename');
            formPageNameField.value = pagename;
            $('st-newpage-duplicate').style.display = 'none';
            this.saveContent();
            break;
    }
    return false;
}

proto.newpage_duplicate_cancel = function() {
    $('st-newpage-duplicate').style.display = 'none';
    return false;
}

proto.displayNewPageDialog = function() {
    $('st-newpage-save-pagename').value = '';
    $('st-newpage-duplicate-option-different').checked = false;
    $('st-newpage-duplicate-option-suggest').checked = false;
    $('st-newpage-duplicate-option-append').checked = false;
    Element.removeClassName(
        'st-newpage-duplicate-emphasis',
        'st-newpage-duplicate-emphasis'
    );
    // $('st-newpage-save').style.display = 'block';
    $('st-newpage-save-pagename').focus();

    var divs = {
        wrapper: $('st-newpage-save'),
        background: $('st-newpage-save-overlay'),
        content: $('st-newpage-save-interface'),
        contentWrapper: $('st-newpage-save-interface').parentNode
    }
    Widget.Lightbox.show({ 'divs': divs, 'effects': ['RoundedCorners'] });

    return false;
}

proto.saveButtonHandler = function() {
    if (Socialtext.new_page) {
        this.saveNewPage();
    }
    else {
        this.saveContent();
    }

    return false;
}

proto.saveNewPage = function() {
    var new_page_name = $('st-newpage-pagename-edit');
    var edit_page_name = $('st-page-editing-pagename');
    if (! is_reserved_pagename(new_page_name.value)
    ) {
        if (Page.active_page_exists(new_page_name.value)) {
            edit_page_name.value = new_page_name.value;
            $('st-newpage-save-pagename').value = new_page_name.value;
            return this.newpage_saveClicked();
        }
        else  {
            edit_page_name.value = new_page_name.value;
            this.saveContent();
        }
    }
    else {
        this.displayNewPageDialog();
    }
}

proto.saveChanges = function() {
    this.disableLinkConfirmations();
    var submit_changes = function(wikitext) {
        /*
        if ( Wikiwyg.is_safari ) {
            var e = $("content-edit-body");
            e.style.display = "block";
            e.style.height = "1px";
        }
        */

        var saver = function() {
            var editList = $('st-page-editing-files');
            for (var i=0; i < window.EditQueue.count(); i++) {
                var node = window.EditQueue.file(i);
                editList.appendChild(node.field);
                var new_input = document.createElement( 'input' );
                new_input.type = 'text';
                new_input.name = 'embed';
                new_input.value = window.EditQueue.is_embed_checked() ? '1' : '0';
                editList.appendChild(new_input);

                new_input = document.createElement( 'input' );
                new_input.type = 'text';
                new_input.name = 'unpack';
                new_input.value = window.EditQueue.is_unpack_checked() ? '1' : '0';
                editList.appendChild(new_input);

            }

            for (var i=0; i < window.TagQueue.count(); i++) {
                var new_input = document.createElement( 'input' );
                new_input.type = 'hidden';
                new_input.name = 'add_tag';
                new_input.value = window.TagQueue.tag(i);
                editList.appendChild(new_input);
            }
            window.TagQueue.clear_list();

            $('st-page-editing-pagebody').value = wikitext;
            $('st-page-editing-form').submit();
            return true;
        }

        // Safari 2.0.4 crashes while submitting form in unload handler.
        // Use XHR here to prevent it from crashing.
        if (Wikiwyg.is_safari && wikiwyg.lastChance) {
            saver = function() {
                var uri = Page.ContentUri();
                var post = new Ajax.Request (
                        uri,
                        {
                            method: 'post',
                            parameters: $H({
                                action: 'edit_content',
                                page_name: $('st-page-editing-pagename').value,
                                revision_id: $('st-page-editing-revisionid').value,
                                page_body: wikitext,
                                caller_action: ''
                                }).toQueryString(),
                            asynchronous: false
                        }
                );
            }
        }

        if (wikiwyg.lastChance) {
            // You can't use a callback from within onunload!!
            return saver();
        }
        else {
            // This timeout is so that safari's text box is ready
            setTimeout(function() { return saver() }, 1);
        }

        return true;
    }

    // This fixes {rt: 15680} - Navigate away from advanced mode.
    if (wikiwyg.lastChance &&
        this.current_mode.classname == WW_ADVANCED_MODE
       ) {
        submit_changes(this.current_mode.toWikitext());
        return;
    }
    // Safari just saves the wikitext, with no conversion.
    if (Wikiwyg.is_safari) {
        var wikitext_mode = this.modeByName(WW_ADVANCED_MODE);
        var wikitext = wikitext_mode.toWikitext();
        submit_changes(wikitext);
        return;
    }
    var self = this;
    this.current_mode.toHtml(
        function(html) {
            var wikitext_mode = self.modeByName(WW_ADVANCED_MODE);
            wikitext_mode.convertHtmlToWikitext(
                html,
                function(wikitext) { submit_changes(wikitext) }
            );
        }
    );
}

proto.confirmLinkFromEdit = function() {
    if (wikiwyg.contentIsModified()) {
        var response = confirm("You have unsaved changes. Are you sure you want to navigate away from this page? If you click 'OK', all edit changes will be lost. Click 'Cancel' if you want to stay on the current page.");

        // wikiwyg.confirmed is for the situations when multiple confirmations
        // are considered. It store the value of this confirmation for
        // other handlers to check whether user has already confirmed
        // or not.
        wikiwyg.confirmed = response;

        if (response)
            wikiwyg.disableLinkConfirmations();
        return response;
    }
    return true;
}

proto.enableLinkConfirmations = function() {
    this.originalWikitext = Wikiwyg.is_safari
        ? this.mode_objects[WW_ADVANCED_MODE].getTextArea()
        : this.get_wikitext_from_html(this.div.innerHTML);
    Event.stopObserving(window, 'unload', Event.unloadCache, false);
    window.onunload = function() {
        if (wikiwyg.contentIsModified()) {
            var the_question = [
                "You have unsaved changes. Are you sure you want to navigate away from this page? If you click 'OK', all edit changes will be lost. Click 'Cancel' if you want to save changes and stay on the current page.",
                "You have unsaved changes. Do you want to save those changes? If you click 'OK', all edit changes will be lost. Click 'Cancel' if you want to save changes before navigating away from this page."
            ];
            if (!confirm(the_question[Wikiwyg.is_safari ? 1 : 0])) {
                wikiwyg.lastChance = true;
                  Event.unloadCache();
                wikiwyg.saveButtonHandler();
            }
        }
        Event.unloadCache();
        return true;
    };

    var links = document.getElementsByTagName('a');
    for (var i = 0; i < links.length; i++) {
        if (links[i].id == 'st-cancel-button-link') continue;
        if (links[i].onclick) continue;
        if (links[i].id == 'st-save-button-link') continue;
        if (links[i].id == 'st-edit-mode-uploadbutton') continue;
        if (links[i].id == 'st-edit-mode-tagbutton') continue;
        if (links[i].id == 'st-attachmentsqueue-submitbutton') continue;
        if (links[i].id == 'st-attachmentsqueue-closebutton') continue;
        if (links[i].id == 'st-tagqueue-closebutton') continue;
        if (links[i].id == 'st-tagqueue-submitbutton') continue;

        links[i].onclick = this.confirmLinkFromEdit;
    }
    return false;
}

proto.disableLinkConfirmations = function() {
    this.originalWikitext = null;
    window.onunload = null;

    var links = document.getElementsByTagName('a');
    for (var i = 0; i < links.length; i++) {
        if (links[i].onclick == this.confirmLinkFromEdit)
            links[i].onclick = null;
    }
}

proto.contentIsModified = function() {
    if (this.originalWikitext == null) {
        return true;
    }
    // XXX This could be done more upstream...
    var current_wikitext = this.get_current_wikitext().replace(
        /\r/g, ''
    );
    return (current_wikitext != this.originalWikitext);
}

proto.get_current_wikitext = function() {
    if (this.current_mode.classname.match(/Wikitext/))
        return this.current_mode.toWikitext();
    var html = (this.current_mode.classname.match(/Wysiwyg/))
        ? this.current_mode.get_inner_html()
        : this.current_mode.div.innerHTML;
    return this.get_wikitext_from_html(html);
}

proto.get_wikitext_from_html = function(html) {
    return eval(WW_ADVANCED_MODE).prototype.convert_html_to_wikitext(html);
}

proto.set_edit_tips_span_display = function(display) {
    var edit_tips = $('st-edit-tips');
    edit_tips.style.display = display;
}

proto.editMode = function() {
    this.current_mode = this.first_mode;
    this.current_mode.fromHtml(this.div.innerHTML);
    this.toolbarObject.resetModeSelector();
    this.current_mode.enableThis();
}

/*==============================================================================
Mode class generic overrides.
 =============================================================================*/
proto = Wikiwyg.Mode.prototype;

proto.footer_offset = 20; // magic constant to make sure edit window does not scroll off page

// XXX - Hardcoded until we can get height of Save/Preview/Cancel buttons
proto.get_edit_height = function() {
    var available_height;
    if (self.innerHeight) {
        available_height = self.innerHeight;
    } else if (document.documentElement && document.documentElement.clientHeight) {
        available_height = document.documentElement.clientHeight;
    } else if (document.body) {
        available_height = document.body.clientHeight;
    }

    var x = 0;
    var e = this.div;
    while (e) {
        x += e.offsetTop;
        e = e.offsetParent;
    }

    var edit_height = available_height -
                      x -
                      this.wikiwyg.toolbarObject.div.offsetHeight -
                      this.footer_offset;
    return edit_height;
}

proto.enableStarted = function() {
    Wikiwyg.Socialtext.edit_bar.style.display = 'none';
    Wikiwyg.Socialtext.loading_bar.style.display = 'block';
    this.wikiwyg.disable_button(this.classname);
    this.wikiwyg.enable_button(this.wikiwyg.current_mode.classname);
}

proto.enableFinished = function() {
    Wikiwyg.Socialtext.loading_bar.style.display = 'none';
    Wikiwyg.Socialtext.edit_bar.style.display = 'block';
}

var WW_ERROR_TABLE_SPEC_BAD =
    "That doesn't appear to be a valid number.";
var WW_ERROR_TABLE_SPEC_TOO_BIG =
    "That seems like a bit too large for a table.";
var WW_ERROR_TABLE_SPEC_HAS_ZERO =
    "Can't have a 0 for a size.";
proto.parse_input_as_table_spec = function(input) {
    var match = input.match(/^\s*(\d+)(?:\s*x\s*(\d+))?\s*$/i);
    if (match == null)
        return [ false, WW_ERROR_TABLE_SPEC_BAD ];
    var one = match[1], two = match[2];
    function tooBig(x) { return x > 50 };
    function tooSmall(x) { return x.match(/^0+$/) ? true : false };
    if (two == null) two = ''; // IE hack
    if (tooBig(one) || (two != null) && tooBig(two))
        return [ false, WW_ERROR_TABLE_SPEC_TOO_BIG ];
    if (tooSmall(one) || (two && tooSmall(two)))
        return [ false, WW_ERROR_TABLE_SPEC_HAS_ZERO ];
    return [ true, one, two ];
}

proto.prompt_for_table_dimensions = function() {
    var rows, columns;
    var errorText = '';
    while (!(rows && columns)) {
        var promptText = 'Please enter the number of table ' +
            (rows ? 'columns' : 'rows') + ':';
        if (errorText)
            promptText = errorText + "\n" + promptText;
        var answer = prompt(promptText, '3');
        if (!answer)
            return null;
        var result = this.parse_input_as_table_spec(answer);
        if (! result[0]) {
            errorText = result[1];
        }
         else if (! rows || result[2]) {
            rows = result[1];
            columns = result[2];
        }
        else {
            columns = result[1];
        }
    }
    return [ rows, columns ];
}

/*==============================================================================
Socialtext Wikiwyg Toolbar subclass
 =============================================================================*/
proto = new Subclass('Wikiwyg.Toolbar.Socialtext', 'Wikiwyg.Toolbar');

proto.controlLayout = [
    'bold', 'italic', 'strike', '|',
    'h1', 'h2', 'h3', 'h4', 'p', '|',
    'hr', '|',
    'ordered', 'unordered', 'outdent', 'indent', '|',
    'link', 'www', 'unlink', 'attach', 'image', 'table'
];

proto.controlLabels = {
    www: 'External Link',
    attach: 'Link to Attachment',
    image: 'Include an Image',
    unlink: 'Unlink'
};

proto.resetModeSelector = function() {
    this.wikiwyg.disable_button(this.wikiwyg.first_mode.classname);
}

/*==============================================================================
Socialtext Wysiwyg subclass.
 =============================================================================*/
proto = new Subclass(WW_SIMPLE_MODE, 'Wikiwyg.Wysiwyg');

proto.fromHtml = function(html) {
    this.show_messages(html);
    Wikiwyg.Wysiwyg.prototype.fromHtml.call(this, html);
}

proto.show_messages = function(html) {
    var advanced_link = this.advanced_link_html();
    var message_titles = {
        wiki:  'Advanced Content in Grey Border',
        table: 'Table Edit Tip',
        both:  'Table & Advanced Editing'
    };
    var message_bodies = {
        wiki:
            'Advanced content is shown inside a grey border. Switch to ' +
            advanced_link +
            ' to edit areas inside a grey border.',
        table: 'Use ' +
            advanced_link +
            ' to change the number of rows and columns in a table.',
        both: ''
    };
    message_bodies.both = message_bodies.table + ' ' + message_bodies.wiki;

    var wiki    = html.match(/<!--\s*wiki:/);
    var table   = html.match(/<table /i);
    var message = null;
    if      (wiki && table) message = 'both'
    else if (table)         message = 'table'
    else if (wiki)          message = 'wiki';

    if (message) {
        this.wikiwyg.message.display({
            title: message_titles[message],
            body: message_bodies[message],
            timeout: 60
        });
    }
}

proto.do_attach = function() {
    this.wikiwyg.message.display(this.use_advanced_mode_message('Attachments'));
}

proto.do_image = function() {
    this.wikiwyg.message.display(this.use_advanced_mode_message('Images'));
}

proto.use_advanced_mode_message = function(subject) {
    return {
        title: 'Use Advanced Mode for ' + subject,
        body: 'Switch to ' + this.advanced_link_html() +
              ' to use this feature.'
    }
}

proto.advanced_link_html = function() {
    return '<a onclick="wikiwyg.wikitext_link.onclick(); return false" href="#">Advanced Mode</a>';
}

proto.make_table_html = function(rows, columns) {
    var innards = '';
    var cell = '<td style="border: 1px solid black;padding: .2em;"><span style="padding:.5em">&nbsp;</span></td>';
    for (var i = 0; i < rows; i++) {
        var row = '';
        for (var j = 0; j < columns; j++)
            row += cell;
        innards += '<tr>' + row + '</tr>';
    }
    return '<table style="border-collapse: collapse;" class="formatter_table">' + innards + '</table>';
}

proto.do_table = function() {
    var result = this.prompt_for_table_dimensions();
    if (! result) return false;
    this.insert_html(this.make_table_html(result[0], result[1]));
}

proto.do_www = function() {
    var selection = this.get_link_selection_text();
    if (! selection) return;
    var url = prompt('Enter your destination url here:', 'http://');
    if (url == null) return;
    this.exec_command('createlink', url);
}

proto.setHeightOf = function (iframe) {
    iframe.style.height = this.get_edit_height() + 'px';
};

proto.socialtext_wikiwyg_image = function(image_name) {
    return this.wikiwyg.config.toolbar.imagesLocation + image_name;
}

/*==============================================================================
Socialtext Wikitext subclass.
 =============================================================================*/
proto = new Subclass(WW_ADVANCED_MODE, 'Wikiwyg.Wikitext');

proto.markupRules = {
    italic: ['bound_phrase', '_', '_'],
    underline: ['bound_phrase', '', ''],
    h1: ['start_line', '^ '],
    h2: ['start_line', '^^ '],
    h3: ['start_line', '^^^ '],
    h4: ['start_line', '^^^^ '],
    h5: ['start_line', '^^^^^ '],
    h6: ['start_line', '^^^^^^ '],
    www: ['bound_phrase', '"', '"<http://...>'],
    attach: ['bound_phrase', '{file: ', '}'],
    image: ['bound_phrase', '{image: ', '}']
}

for (var ii in proto.markupRules) {
    proto.config.markupRules[ii] = proto.markupRules[ii]
}

proto.canonicalText = function() {
    var wikitext = Wikiwyg.Wikitext.prototype.canonicalText.call(this);
    return this.convert_tsv_sections(wikitext);
}

// This rather brutal hack solves an IE problem on new pages.
proto.convert_html_to_wikitext = function(html) {
    html = html.replace(
        /^<DIV class=wiki>([^\n]*?)(?:&nbsp;)*<\/DIV>$/mg, '$1<BR>'
    );
    html = html.replace(
        /<DIV class=wiki>\r?\n<P><\/P><BR>([\s\S]*?)<\/DIV>/g, '$1<BR>'
    );
    return Wikiwyg.Wikitext.prototype.convert_html_to_wikitext.call(this, html);
}

proto.convert_tsv_sections = function(text) {
    var self = this;
    return text.replace(
        /^tsv:\s*\n((.*(?:\t| {2,}).*\n)+)/gim,
        function(s) { return self.detab_table(s) }
    );
}

proto.detab_table = function(text) {
    return text.
        replace(/\r/g, '').
        replace(/^tsv:\s*\n/, '').
        replace(/(\t| {2,})/g, '|').
        replace(/^/gm, '|').
        replace(/\n/g, '|\n').
        replace(/\|$/, '');
}

proto.enableThis = function() {
    this.wikiwyg.set_edit_tips_span_display('inline');
    Wikiwyg.Wikitext.prototype.enableThis.call(this);
    if (Element.visible('st-page-boxes')) {
        Element.setStyle('st-page-maincontent', {marginRight: '240px'});
    }
}

proto.toHtml = function(func) {
    this.wikiwyg.current_wikitext = this.canonicalText();
    Wikiwyg.Wikitext.prototype.toHtml.call(this, func);
}

proto.fromHtml = function(html) {
    if (Wikiwyg.is_safari) {
        if (this.wikiwyg.current_wikitext)
            return this.setTextArea(this.wikiwyg.current_wikitext);
        if ($('st-raw-wikitext-textarea')) {
            return this.setTextArea($('st-raw-wikitext-textarea').value);
        }
    }
    Wikiwyg.Wikitext.prototype.fromHtml.call(this, html);
}

proto.disableThis = function() {
    this.wikiwyg.set_edit_tips_span_display('none');
    Wikiwyg.Wikitext.prototype.disableThis.call(this);
}

proto.setHeightOfEditor = function() {
    this.textarea.style.height = this.get_edit_height() + 'px';
}

proto.do_www = Wikiwyg.Wikitext.make_do('www');
proto.do_attach = Wikiwyg.Wikitext.make_do('attach');
proto.do_image = Wikiwyg.Wikitext.make_do('image');

proto.convertWikitextToHtml = function(wikitext, func) {
    var uri = location.pathname;
    var postdata = 'action=wikiwyg_wikitext_to_html;content=' +
        encodeURIComponent(wikitext);

    var post = new Ajax.Request (
        uri,
        {
            method: 'post',
            parameters: $H({
                action: 'wikiwyg_wikitext_to_html',
                content: wikitext
            }).toQueryString(),
            asynchronous: false
        }
    );

    func(post.transport.responseText);
}

proto.format_pre = function(element) {
    var data = Wikiwyg.htmlUnescape(element.innerHTML);
    data = data.replace(/<br>/g, '\n')
               .replace(/\n$/, '')
               .replace(/^&nbsp;$/, '\n');

    var before = this.output[this.output.length - 1];
    if (before && (typeof(before) == 'string') && before.match(/\n.pre\n$/)) {
        this.output[this.output.length - 1] = before.replace(/.pre\n$/, '');
        data = '\n' + data;
    } else {
        data = '.pre\n' + data;
    }

    this.appendOutput(data + '\n.pre\n');
}

proto.format_a = function(element) {
    if (this.is_opaque(element))
        return this.handle_wafl_block(element);

    Wikiwyg.Wikitext.prototype.format_a.call(this, element);
}

proto.format_div = function(element) {
    if (this.is_opaque(element))
        return this.handle_wafl_block(element);

    Wikiwyg.Wikitext.prototype.format_div.call(this, element);
}

proto.format_span = function(element) {
    this.treat_include_wafl(element);
    Wikiwyg.Wikitext.prototype.format_span.call(this, element);
}

proto.format_table = function(element) {
    this.assert_blank_line();
    this.walk(element);
    this.assert_new_line();
}

proto.format_br = function() {
    this.insert_new_line();
}

proto.make_wikitext_link = function(label, href, element) {
    var mailto = href.match(/^mailto:(.*)/);

    if (this.is_renamed_hyper_link(element)) {
        var link = this.get_wiki_comment(element).data.
            replace(/^\s*wiki-renamed-hyperlink\s*/, '').
            replace(/\s*$/, '').
            replace(/=-/g, '-');
        this.appendOutput(link);
    }
    else if (this.href_is_wiki_link(href) &&
        this.href_is_really_a_wiki_link(href)
    ) {
        this.handle_wiki_link(label, href, element);
    }
    else if (mailto) {
        if (mailto[1] == label)
            this.appendOutput(mailto[1]);
        else
            this.appendOutput('"' + label + '"<' + href + '>');
    }
    else {
        if (href == label)
            this.appendOutput('<' + href + '>');
        else if (this.looks_like_a_url(label))
            this.appendOutput('<' + label + '>');
        else
            this.appendOutput('"' + label + '"<' + href + '>');
    }
}

proto.href_is_really_a_wiki_link = function(href) {
    var query = href.split('?')[1];
    if (!query) return false;
    return ((! query.match(/=/)) || query.match(/action=display\b/));
}

proto.handle_wiki_link = function(label, href, element) {
    var href_orig = href;
    href = href.replace(/.*\?/, '');
    href = decodeURI(escape(href));
    href = href.replace(/_/g, ' ');
    // XXX more conversion/normalization poo
    // We don't yet have a smart way to get to page->Subject->metadata
    // from page->id
    if (label == href_orig && !(label.match(/=/))) {
        this.appendOutput('[' + href + ']');
    }
    else if (this.is_renamed_wiki_link(element) &&
             ! this.href_label_similar(href, label))
    {
        var link = this.get_wiki_comment(element).data.
            replace(/^\s*wiki-renamed-link\s*/, '').
            replace(/\s*$/, '').
            replace(/=-/g, '-');
        this.appendOutput('"' + label + '"[' + link + ']');
    }
    else {
        this.appendOutput('[' + label + ']');
    }
}

proto.href_label_similar = function(href, label) {
    return nlw_name_to_id(href) == nlw_name_to_id(label);
}

proto.is_renamed_wiki_link = function(element) {
    var comment = this.get_wiki_comment(element);
    return comment && comment.data.match(/wiki-renamed-link/);
}

proto.is_renamed_hyper_link = function(element) {
    var comment = this.get_wiki_comment(element);
    return comment && comment.data.match(/wiki-renamed-hyperlink/);
}

proto.handle_wafl_block = function(element) {
    var comment = this.get_wiki_comment(element);
    if (! comment) return;
    var text = comment.data;
    // See Socialtext/Formatter.pm for an explanation of the escaping going on
    // here.
    text = text.replace(/^ wiki:\s+/, '').
                replace(/-=/g, '-').
                replace(/==/g, '=');
    this.appendOutput(text);
}

proto.make_table_wikitext = function(rows, columns) {
    var text = '';
    for (var i = 0; i < rows; i++) {
        var row = ['|'];
        for (var j = 0; j < columns; j++)
            row.push('|');
        text += row.join(' ') + '\n';
    }
    return text;
}

proto.do_table = function() {
    var result = this.prompt_for_table_dimensions();
    if (! result) return false;
    this.markup_line_alone([
        "a table",
        this.make_table_wikitext(result[0], result[1])
    ]);
}

proto.cleanup_output = function(output) {
    // Strip ears off bare URLs if they're at the end of the markup or
    // followed by whitespace.
    for (var ii = 0; ii < output.length; ii++) {
        if ((ii == output.length - 1 || output[ii + 1].match(/^\s/)) &&
            (ii == 0 || output[ii - 1].match(/[\s\'\"]$/)))
        {
            output[ii] = output[ii].replace( /^<(\w+:[^>\s]+?)>$/, "$1" );
        }
    }
    return output;
}

proto.treat_include_wafl = function(element) {
    // Note: element should be a <span>

    var inner = element.innerHTML;
    if(!inner.match(/<!-- wiki: \{include: \[.+\]\} -->/)) {
        return;
    }


    // If this span is a {include} wafl, we squeeze
    // whitepsaces before and after it. Becuase
    // {include} is supposed to be in a <p> of it's own.
    // If user type "{include: Page} Bar", that leaves
    // an extra space in <p>.

    var next = element.nextSibling;
    if (next && next.tagName &&
            next.tagName.toLowerCase() == 'p') {
        next.innerHTML = next.innerHTML.replace(/^ +/,"");
    }

    var prev = element.previousSibling;
    if (prev
        && prev.tagName
        && prev.tagName.toLowerCase() == 'p') {
        if (prev.innerHTML.match(/^[ \n\t]+$/)) {
            // format_p is already called, so it's too late
            // to do this:
            //     prev.parentNode.removeChild( prev );

            // Remove two blank lines for it's the output
            // of an empty <p>
            var line1 = this.output.pop();
            var line2 = this.output.pop();
            // But if they are not newline, put them back
            // beause we don't want to mass around there.
            if ( line1 != "\n" || line2 != "\n" ) {
                this.output.push(line2);
                this.output.push(line1);
            }
        }
    }
}

proto.start_is_no_good = function(element) {
    var first_node = this.getFirstTextNode(element);
    var prev_node = this.getPreviousTextNode(element);

    if (! first_node) return true;
    if (first_node.nodeValue.match(/^ /)) return false;
    if (! prev_node || prev_node.nodeValue == '\n') return false;
    return ! prev_node.nodeValue.match(/[\( "]$/);
}

/*==============================================================================
Socialtext Preview subclass.
 =============================================================================*/
proto = new Subclass(WW_PREVIEW_MODE, 'Wikiwyg.Preview');

proto.fromHtml = function(html) {
    if (this.wikiwyg.previous_mode.classname.match(/Wysiwyg/)) {
        var wikitext_mode = this.wikiwyg.modeByName(WW_ADVANCED_MODE);
        var self = this;
        wikitext_mode.convertHtmlToWikitext(
            html,
            function(wikitext) {
                wikitext_mode.convertWikitextToHtml(
                    wikitext,
                    function(new_html) {
                        self.wikiwyg.enable_edit_more();
                        self.div.innerHTML = new_html;
                        self.div.style.display = 'block';
                        self.wikiwyg.enableLinkConfirmations();
                    }
                );
            }
        );
    }
    else {
        this.wikiwyg.enable_edit_more();
        this.div.innerHTML = html;
        this.div.style.display = 'block';
        this.wikiwyg.enableLinkConfirmations();
    }
}

/*==============================================================================
Socialtext Debugging code
 =============================================================================*/
klass = Wikiwyg;

klass.run_formatting_tests = function(link) {
    var all = document.getDivsByClassName('wikiwyg_formatting_test');
    foreach(all, function (each) {
        klass.run_formatting_test(each);
    })
}

klass.run_formatting_test = function(div) {
    var pre_elements = div.getElementsByTagName('pre');
    var html_text = pre_elements[0].innerHTML;
    var wiki_text = pre_elements[1].innerHTML;
    html_text = Wikiwyg.htmlUnescape(html_text);
    var wikitext = new Wikiwyg.Wikitext.Socialtext();
    var result = wikitext.convert_html_to_wikitext(html_text);
    result = klass.ensure_newline_at_end_of_string(result);
    wiki_text = klass.ensure_newline_at_end_of_string(wiki_text);
    if (! div.wikiwyg_formatting_test_results_shown)
        div.wikiwyg_formatting_test_results_shown = 0;
    if (result == wiki_text) {
        div.style.backgroundColor = '#0f0';
    }
    else if (! div.wikiwyg_formatting_test_results_shown++) {
        div.style.backgroundColor = '#f00';
        div.innerHTML = div.innerHTML + '<br/>Bad: <pre>\n' +
            result + '</pre>';
        var list = $('wikiwyg_test_results');
        list.innerHTML += '<a href="#'+div.id+'">Failed '+div.id+'</a>; ';
    }
}

klass.ensure_newline_at_end_of_string = function(str) {
    return str + ('\n' == str.charAt(str.length-1) ? '' : '\n');
}

wikiwyg_run_all_formatting_tests = function() {
    var divs = document.getElementsByTagName('div');
    for (var i = 0; i < divs.length; i++) {
        var div = divs[i];
        if (div.className != 'wikiwyg_formatting_test') continue;
        klass.formatting_test(div);
    }
}

klass.run_all_formatting_tests = wikiwyg_run_all_formatting_tests;

// BEGIN Wikiwyg/MessageCenter.js
/*==============================================================================
Wikiwyg - Turn any HTML div into a wikitext /and/ wysiwyg edit area.

DESCRIPTION:

Wikiwyg is a Javascript library that can be easily integrated into any
wiki or blog software. It offers the user multiple ways to edit/view a
piece of content: Wysiwyg, Wikitext, Raw-HTML and Preview.

The library is easy to use, completely object oriented, configurable and
extendable.

See the Wikiwyg documentation for details.

SYNOPSIS:

From anywhere you can produce a message box with a call like this:

    this.wikiwyg.message.display({
        title: 'Foo button does not work in Bar mode',
        body: 'To use the Foo button you should first switch to Baz mode'
    });

AUTHORS:

    Brian Ingerson <ingy@cpan.org>
    Casey West <casey@geeknest.com>
    Chris Dent <cdent@burningchrome.com>
    Matt Liggett <mml@pobox.com>
    Ryan King <rking@panoptic.com>
    Dave Rolsky <autarch@urth.org>

COPYRIGHT:

    Copyright (c) 2005 Socialtext Corporation 
    655 High Street
    Palo Alto, CA 94301 U.S.A.
    All rights reserved.

Wikiwyg is free software. 

This library is free software; you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or (at
your option) any later version.

This library is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
General Public License for more details.

    http://www.gnu.org/copyleft/lesser.txt

 =============================================================================*/

/*==============================================================================
NLW Message Center Class
 =============================================================================*/
 
proto = Subclass('Wikiwyg.MessageCenter');
klass = Wikiwyg.MessageCenter;
klass.closeTimer = null;

proto.messageCenter = 'st-message-center';
proto.messageCenterTitle = 'st-message-center-title';
proto.messageCenterBody = 'st-message-center-body';
proto.messageCenterControlClose = 'st-message-center-control-close';
proto.messageCenterControlArrow = 'st-message-center-control-arrow';
proto.closeDelayDefault = 10;

proto.display = function (args) {
    this.closeDelay = 
        (args.timeout ? args.timeout : this.closeDelayDefault) * 1000;
    $(this.messageCenterTitle).innerHTML = args.title;
    $(this.messageCenterBody).innerHTML = args.body;
    var msgCenter = $(this.messageCenter);

    if (! msgCenter) {
        return;
    }

    msgCenter.style.display = 'block';
    this.setCloseTimer();
    this.installEvents();
    this.installControls();
};
proto.clearCloseTimer = function () {
    if (klass.closeTimer)
        window.clearTimeout(klass.closeTimer);
};
proto.setCloseTimer = function () {
    this.clearCloseTimer();
    var self = this;
    klass.closeTimer = window.setTimeout(
        function () { self.closeMessageCenter() },
        this.closeDelay
    );
};
proto.closeMessageCenter = function () {
    var msgCenter = $(this.messageCenter);
    if (! msgCenter) {
        return;
    }
    msgCenter.style.display = 'none';
    this.closeMessage();
    this.clearCloseTimer();
};
proto.clear = proto.closeMessageCenter;
proto.installEvents = function () {
    var msgCenter = $(this.messageCenter);
    var self = this;
    msgCenter.onmouseover = function () { self.openMessage() }
    msgCenter.onmouseout  = function () { self.closeMessage() }
};
proto.openMessage = function () {
    this.clearCloseTimer();
    $(this.messageCenterControlArrow).src
        = $(this.messageCenterControlArrow).src.replace(
              /right/,
              'down'
          );
    $(this.messageCenterBody).style.display
        = 'block';
};
proto.closeMessage = function () {
    this.setCloseTimer();
    $(this.messageCenterControlArrow).src
        = $(this.messageCenterControlArrow).src.replace(
              /down/,
              'right'
          );
    $(this.messageCenterBody).style.display
        = 'none';
};
proto.installControls = function () {
    var self = this;
    $(this.messageCenterControlClose).onclick
        = function () { self.closeMessageCenter() };
}


// BEGIN Widgets.js
Wikiwyg.Widgets =
{"widgets":["link1","link2","image","file","toc","include","section","recent_changes","tag","tag_list","weblog","weblog_list","fetchrss","fetchatom","search","googlesoap","technorati","aim","yahoo","skype","user","date","asis","asap","new_form_page"],"fields":{"search_term":"Search term","image_name":"Image name","tag_name":"Tag name","form_name":"Form name","weblog_name":"Weblog name","date_string":"YYYY-MM-DD&nbsp;HH:MM:SS","section_name":"Section name","file_name":"File name","user_email":"User's email","form_text":"Link text","page_title":"Page title","workspace_id":"Workspace","skype_id":"Skype name","relative_url":"Relative URL","atom_url":"Atom feed URL","rss_url":"RSS feed URL","asis_content":"Unformatted content","yahoo_id":"Yahoo! ID","aim_id":"AIM screen name","label":"Link text","asap_id":"Convoq name"},"api_for_title":{"workspace_id":"/data/workspaces/:workspace_id"},"synonyms":{"callme":"skype","category":"tag","ymsgr":"yahoo","callto":"skype","category_list":"tag_list"},"match":{"date_string":"^(\\d{4}-\\d{2}-\\d{2}\\s+\\d{2}:\\d{2}:\\d{2}.*)$","user_email":"^([a-zA-Z0-9_\\+\\.\\-\\&\\!\\%\\+\\$\\*\\^\\']+\\@(([a-zA-Z0-9\\-])+\\.)+([a-zA-Z0-9:]{2,4})+)$","workspace_id":"^[a-z0-9_\\-]+$","skype_id":"^(\\S+)$","aim_id":"^(\\S+)$","yahoo_id":"^(\\S+)$","asap_id":"^(\\S+)$"},"regexps":{"workspace-value":"^(?:(\\S+);)?\\s*(.*?)?\\s*$","three-part-link":"^(\\S*)?\\s*\\[([^\\]]*)\\]\\s*(.*?)?\\s*$"},"widget":{"asap":{"more_desc":"There are no optional properties for a Convoq Link.","uneditable":true,"on_menu":false,"color":"cyan4","pattern":"asap:%asap_id","required":["asap_id"],"desc":"Display a link to a Convoq name. Clicking the link will start a Convoq call with the person if your Convoq client is properly configured. Use this form to edit the properties of the Convoq link.","markup":["bound_phrase","asap:",""],"label":"Convoq Link","title":"Call '$asap_id' using Convoq. Click to edit.","image_text":[{"text":"Convoq: %asap_id","field":"default"}],"field":"asap_id"},"search":{"more_desc":"Optional properties include the name of the workspace to search, whether to search in the page title, text or tags, and whether to display full results or just page titles.","input":{"workspace_id":"radio"},"parse":{"fields":["workspace_id","search_term"],"regexp":"^(?:<(\\S+)>)?\\s*(.*?)?\\s*$"},"title_and_id":{"workspace_id":{"id":null,"title":null}},"full":"off","pdfields":["workspace_id"],"pattern":"{search: <%workspace_id> %search_term}","color":"gold4","required":["search_term"],"fields":["search_term","workspace_id"],"desc":"Display the search results for the given phrase within a workspace. Use this form to edit the properties for the search.","title":{"default":"Search for '$search_term'. Click to edit.","full":"Display result for searching '$search_term'. Click to edit."},"label":"Search Results","labels":{"seach_term":"Search for","workspace_id":"In"},"image_text":[{"text":"search: %search_term","field":"default"}]},"recent_changes":{"more_desc":"Optionally, specify that the page contents should be displayed.","input":{"workspace_id":"radio"},"parse":{"regexp":"^\\s*(.*?)?\\s*$"},"title_and_id":{"workspace_id":{"id":null,"title":null}},"full":"off","pattern":"{recent_changes: %workspace_id}","color":"gold","fields":["workspace_id"],"desc":"Display a list of pages recently changed in a workspace. By default only the page titles are displayed. Use this form to edit the list properties.","title":{"default":"What's new in the '$workspace_id' workspace. Click to edit.","full":"Display what's new in the '$workspace_id' workspace. Click to edit."},"label":"What's New","labels":{"workspace_id":"Workspace"},"image_text":[{"text":"recent changes: %workspace_id","field":"workspace_id"},{"text":"recent changes","field":"default"}]},"https":{"uneditable":true,"color":"darkorange","title":"HTTP relative link. Edit in Advanced mode."},"tag_list":{"more_desc":"Optional properties include specifying which workspace to use and whether to display page titles or whole pages.","input":{"workspace_id":"radio"},"parse":{"fields":["workspace_id","tag_name"],"regexp":"^(?:<(\\S+)>)?\\s*(.*?)?\\s*$"},"title_and_id":{"workspace_id":{"id":null,"title":null}},"full":"off","pdfields":["workspace_id"],"pattern":"{tag_list: <%workspace_id> %tag_name}","color":"darkviolet","fields":["tag_name","workspace_id"],"required":["tag_name"],"desc":"Display a list of the most recently changed pages in a workspace that have a specific tag. By default only the page title is displayed. Use this form to edit the list properties.","title":{"default":"Pages with the '$tag_name' tag. Click to edit.","full":"Display pages with the '$tag_name' tag. Click to edit."},"label":"Tag List","labels":{"workspace_id":"Pages in"},"image_text":[{"text":"tag list: %tag_name","field":"default"}]},"date":{"more_desc":"There are no optional properties for a date display.","color":"royalblue","pattern":"{date: %date_string}","desc":"Display the given date and time in the individually-set time zone for each reader. Use this form to edit the date and time to be displayed","label":"Date in Local Time","title":"Display '$date_string' in reader's time zone. Click to edit.","image_text":[{"text":"date: %date_string","field":"default"}],"field":"date_string"},"file":{"more_desc":"Optional properties include specifying a different page for the attachment, and link text.","checks":["require_page_if_workspace"],"input":{"workspace_id":"radio","page_title":"radio"},"parse":{"fields":["workspace_id","page_title","file_name"],"regexp":"?three-part-link","no_match":"file_name"},"title_and_id":{"workspace_id":{"id":null,"title":null}},"pdfields":["workspace_id","page_title","label"],"pattern":"\"%label\"{file: %workspace_id [%page_title] %file_name}","color":"brown","fields":["file_name","workspace_id","page_title","label"],"required":["file_name"],"desc":"Display a link to a file attached to a page. Use this form to edit the properities of the link.","title":"Link to file '$file_name'. Click to edit.","label":"Attachment Link","labels":{"workspace_id":"Page in","file_name":"Attachment filename","page_title":"File attached to"},"image_text":[{"text":"file: %label","field":"label"},{"text":"file: %file_name","field":"default"}]},"include":{"more_desc":"There are no optional properties for page include.","checks":["require_page_if_workspace"],"input":{"workspace_id":"radio"},"parse":{"regexp":"^(\\S*)?\\s*\\[([^\\]]*)\\]\\s*$"},"title_and_id":{"workspace_id":{"id":null,"title":null}},"pdfields":[],"pattern":"{include: %workspace_id [%page_title]}","color":"darkblue","fields":["workspace_id","page_title"],"required":["page_title"],"desc":"Display the contents of another page within the current page. Use this form to edit the properties for the page include.","title":"Include the page '$page_title'. Click to edit.","label":"Page Include","labels":{"workspace_id":"Other page in"},"image_text":[{"text":"include: %page_title","field":"default"}]},"section":{"more_desc":"There are no optional properties for a section marker.","color":"darkred","pattern":"{section: %section_name}","desc":"Add a section marker at the current cursor location. You can link to a section marker using a \"Section Link\". Use this form to edit the properties for the section marker.","label":"Section Marker","title":"Section marker '$section_name'. Click to edit.","image_text":[{"text":"section: %section_name","field":"default"}],"field":"section_name"},"weblog_list":{"more_desc":"Optional parameters include specifying which workspace to use and whether to display page titles or whole pages.","input":{"workspace_id":"radio"},"parse":{"fields":["workspace_id","weblog_name"],"regexp":"^(?:<(\\S+)>)?\\s*(.*?)?\\s*$"},"title_and_id":{"workspace_id":{"id":null,"title":null}},"full":"off","pdfields":["workspace_id"],"pattern":"{weblog_list: <%workspace_id> %weblog_name}","color":"forestgreen","fields":["workspace_id","weblog_name"],"required":["weblog_name"],"desc":"Display a list of the most recent entries from a weblog in a workspace. By default only the weblog entry names are displayed. Use this form to edit the list properties.","title":{"default":"Include the weblog '$weblog_name'. Click to edit.","full":"Display the weblog '$weblog_name'. Click to edit."},"label":"Weblog List","labels":{"workspace_id":"in"},"image_text":[{"text":"weblog list: %weblog_name","field":"default"}]},"ftp":{"uneditable":true,"color":"darkorange","title":"FTP link. Edit in Advanced mode."},"http":{"uneditable":true,"color":"darkorange","title":"Relative HTTP link. Edit in Advanced mode."},"html":{"uneditable":true,"color":"indianred","title":"Raw HTML section. Edit in advanced mode."},"irc":{"uneditable":true,"color":"darkorange","title":"IRC link. Edit in Advanced mode."},"technorati":{"more_desc":"There are no optional properties for a Technorati search.","pattern":"{technorati: %search_term}","color":"darkmagenta","desc":"Display the results for a Technorati search. Use this form to edit the properties for the search.","title":"Search Technorati for '$search_term'. Click to edit.","label":"Technorati Search","image_text":[{"text":"Technorati: %search_term","field":"default"}],"labels":{"search_term":"Search for"},"field":"search_term"},"unknown":{"uneditable":true,"color":"darkslategrey","title":"Unknown widget '$unknown_id'. Edit in advanced mode."},"toc":{"more_desc":"Optionally, specify which page's headers and sections to use for the table of contents.","checks":["require_page_if_workspace"],"input":{"workspace_id":"radio","page_title":"radio"},"parse":{"regexp":"^(\\S*)?\\s*\\[([^\\]]*)\\]\\s*$","no_match":"workspace_id"},"title_and_id":{"workspace_id":{"id":null,"title":null}},"pdfields":["workspace_id","page_title"],"pattern":"{toc: %workspace_id [%page_title]}","color":"darkseagreen","fields":["workspace_id","page_title"],"desc":"Display a table of contents for a page. Each header or section on the page is listed as a link in the table of contents. Click \"Save\" now, or click \"More options\" to edit the properties for the table of contents.","title":"Table of contents for '$page_title'. Click to edit.","label":"Table of Contents","labels":{"workspace_id":"Page in","page_title":"Headers and<br/>sections in"},"image_text":[{"text":"toc: %page_title","field":"page_title"},{"text":"toc","field":"default"}]},"user":{"more_desc":"There are no optional properties for a user name.","color":"darkgoldenrod","pattern":"{user: %user_email}","required":["user_email"],"desc":"Display the full name for the given email address or user name. Use this form to edit the properties of the user name.","label":"User Name","title":"Show full name for '$user_email'. Click to edit.","image_text":[{"text":"user: %user_email","field":"default"}],"field":"user_email"},"tag":{"more_desc":"Optional properties include link text, and the name of a different workspace for the tags.","input":{"workspace_id":"radio"},"parse":{"fields":["workspace_id","tag_name"],"regexp":"?workspace-value","no_match":"tag_name"},"title_and_id":{"workspace_id":{"id":null,"title":null}},"pdfields":["label","workspace_id"],"pattern":"\"%label\"{tag: %workspace_id; %tag_name}","color":"green","fields":["tag_name","label","workspace_id"],"required":["tag_name"],"desc":"Display a link to a list of pages with a specific tag. Use this form to edit the properties of the link.","title":"Link to tag '$tag_name'. Click to edit.","label":"Tag Link","labels":{"workspace_id":"Search"},"image_text":[{"text":"tag: %label","field":"label"},{"text":"tag: %tag_name","field":"tag_name"}]},"yahoo":{"more_desc":"There are no optional properties for a Yahoo! link.","pattern":"yahoo:%yahoo_id","required":["yahoo_id"],"desc":"Display a link to a Yahoo! instant message ID. The icon will show whether the person is online. Clicking the link will start an IM conversation with the person if your IM client is properly configured. Use this form to edit the properties of the link.","markup":["bound_phrase","yahoo:",""],"label":"Yahoo! IM Link","title":"Instant message to '$yahoo_id' using Yahoo! Click to edit.","image_text":[{"text":"Yahoo! IM: %yahoo_id","field":"default"}],"field":"yahoo_id"},"link2":{"checks":["require_page_if_workspace"],"input":{"workspace_id":"radio","page_title":"radio"},"parse":{"fields":["workspace_id","page_title","section_name"],"regexp":"?three-part-link","no_match":"section_name"},"primary_field":"section_name","pdfields":["label","workspace_id","page_title"],"color":"blue","required":["section_name"],"select_if":{"blank":["workspace_id"]},"desc":"Use this form to edit the properties of the link to a page section.","labels":{"workspace_id":"Workspace"},"image_text":[{"text":"link: %label","field":"label"},{"text":"link: %page_title (%section_name )","field":"page_title"},{"text":"link: %section_name","field":"default"}],"more_desc":"Optional properties include the text to display for the link, and the title of a different page.","title_and_id":{"workspace_id":{"id":null,"title":null}},"pattern":"\"%label\"{link: %workspace_id [%page_title] %section_name}","fields":["section_name","label","workspace_id","page_title"],"label":"Link to a Section","title":"Link to '$section_name' in '$page_title'. Click to edit."},"googlesoap":{"color":"saddlebrown","desc":"Display the results from a Google search. Use this form to edit the properties for the search.","image_text":[{"text":"Google: %search_term","field":"default"}],"labels":{"search_term":"Search for"},"field":"search_term","more_desc":"There are no optional properties for an Google search.","pattern":"{googlesoap: %search_term}","title":"Search Google for '$search_term'. Click to edit.","label":"Google Search"},"link1":{"checks":["require_page_if_workspace"],"parse":{"fields":["workspace_id","page_title","section_name"],"regexp":"?three-part-link","no_match":"section_name"},"primary_field":"workspace_id","pdfields":["label","section_name"],"color":"blue","required":["page_title","workspace_id"],"select_if":{"defined":["workspace_id"]},"desc":"Use this form to edit the properties of the link.","labels":{"workspace_id":"Other workspace"},"image_text":[{"text":"link: %label","field":"label"},{"text":"link: %page_title","field":"default"}],"more_desc":"Optional properties include the text to display for the link, and a target section within the linked page.","title_and_id":{"workspace_id":{"id":null,"title":null}},"pattern":"\"%label\"{link: %workspace_id [%page_title] %section_name}","fields":["workspace_id","page_title","label","section_name"],"label":"Inter-workspace link","title":"Link to '$page_title'. Click to edit."},"new_form_page":{"parse":{"regexp":"^\\s*(\\S+)\\s+(.+)\\s*$"},"on_menu":false,"color":"maroon","required":["form_name","form_text"],"desc":"Select a form and generates a new form page.","image_text":[{"text":"form: %form_name","field":"default"}],"more_desc":"There are no optional properties for a new form page.","pattern":"{new_form_page: %form_name %form_text}","fields":["form_name","form_text"],"title":"Use $form_name to generate a form. Click to edit.","label":"New Form Page"},"weblog":{"input":{"workspace_id":"radio"},"parse":{"fields":["workspace_id","weblog_name"],"regexp":"?workspace-value","no_match":"weblog_name"},"pdfields":["label","workspace_id"],"color":"purple","required":["weblog_name"],"desc":"Display a link to a weblog. Use this form to edit the properties of the link.","labels":{"workspace_id":"Weblog on"},"image_text":[{"text":"weblog: %label","field":"label"},{"text":"weblog: %weblog_name","field":"default"}],"more_desc":"Optional properties include link text, and the name of a different workspace for the weblog.","title_and_id":{"workspace_id":{"id":null,"title":null}},"pattern":"\"%label\"{weblog: %workspace_id; %weblog_name}","fields":["label","weblog_name","workspace_id"],"title":"Link to weblog '$weblog_name'. Click to edit.","label":"Weblog Link"},"fetchatom":{"color":"darkgreen","desc":"Display the content of an Atom feed. Use this form to edit the properties of the inline Atom feed.","image_text":[{"text":"feed: %atom_url","field":"default"}],"field":"atom_url","more_desc":"There are no optional properties for an Atom feed.","pattern":"{fetchatom: %atom_url}","label":"Inline Atom","title":"Include the '$atom_url' Atom feed. Click to edit."},"fetchrss":{"color":"orange","desc":"Display the content of an RSS feed. Use this form to edit the properties of the inline RSS feed.","image_text":[{"text":"feed: %rss_url","field":"default"}],"field":"rss_url","more_desc":"There are no optional properties for an RSS feed.","pattern":"{fetchrss: %rss_url}","label":"Inline RSS","title":"Include the '$rss_url' RSS feed. Click to edit."},"aim":{"required":["aim_id"],"desc":"Display a link to an AIM screen name. The icon will show whether the person is online. Clicking the link will start an IM conversation with the person if your IM client is properly configured. Use this form to edit the properties of the link.","markup":["bound_phrase","aim:",""],"image_text":[{"text":"AIM: %aim_id","field":"default"}],"field":"aim_id","more_desc":"There are no optional properties for an AIM link.","pattern":"aim:%aim_id","label":"AIM Link","title":"Instant message to '$aim_id' using AIM. Click to edit."},"image":{"checks":["require_page_if_workspace"],"input":{"workspace_id":"radio","page_title":"radio"},"parse":{"fields":["workspace_id","page_title","image_name"],"regexp":"?three-part-link","no_match":"image_name"},"pdfields":["workspace_id","page_title","label"],"color":"red","required":["image_name"],"desc":"Display an image on this page. The image must be already uploaded as an attachment to this page or another page. Use this form to edit the properties of the displayed image.","labels":{"workspace_id":"Page in","image_name":"Attachment filename","page_title":"Attached to"},"image_text":[{"text":"image: %label","field":"label"},{"text":"image: %image_name","field":"default"}],"more_desc":"Optional properties include the title of another page to which the image is attached, and link text. If link text is specified then a link to the image is displayed instead of the image.","title_and_id":{"workspace_id":{"id":null,"title":null}},"pattern":"\"%label\"{image: %workspace_id [%page_title] %image_name}","fields":["image_name","workspace_id","page_title","label"],"title":"Display image '$image_name'. Click to edit.","label":"Attached Image"},"skype":{"required":["skype_id"],"desc":"Display a link to a Skype name. Clicking the link will start a Skype call with the person if your Skype client is properly configured. Use this form to edit the properties of the link.","markup":["bound_phrase","skype:",""],"image_text":[{"text":"Skype: %skype_id","field":"default"}],"field":"skype_id","more_desc":"There are no optional properties for a Skype link.","pattern":"skype:%skype_id","label":"Skype Link","title":"Call '$skype_id' using Skype. Click to edit."},"sharepoint":{"color":"red","uneditable":true,"title":"Sharepoint link. Edit in advanced mode."},"asis":{"color":"darkslateblue","required":["asis_content"],"desc":"Include unformatted text in the page. This text will not be treated as wiki text. Use this form to edit the text.","markup":["bound_phrase","{{","}}"],"image_text":[{"text":"unformatted: %asis_content","field":"default"}],"field":"asis_content","more_desc":"There are no optional properties for unformatted text.","pattern":"{{%asis_content}}","label":"Unformatted","title":"Unformatted Content"}}};
// BEGIN Wikiwyg/Widgets.js
/*
To Do:
- Clicking on widget produces unwanted stretchy-handles.

Refactor:

*/

Wikiwyg.is_ie7 = (
    Wikiwyg.is_ie &&
    Wikiwyg.ua.indexOf("7.0") != -1
);
Wikiwyg.Widgets.resolve_synonyms = function(widget) {
    for (var ii in Wikiwyg.Widgets.synonyms) {
        widget = widget.replace( new RegExp("^" + ii), Wikiwyg.Widgets.synonyms[ii]);
    }
    return widget;
}

Wikiwyg.Widgets.isMultiple = function(widget_id) {
    var nameMatch = new RegExp(widget_id + '\\d+$');
    for (var i = 0; i < Wikiwyg.Widgets.widgets.length; i++)
        if (Wikiwyg.Widgets.widgets[i].match(nameMatch))
            return true;
    return false;
}

Wikiwyg.Widgets.getFirstMultiple = function(widget_id) {
    var nameMatch = new RegExp(widget_id + '\\d+$');
    for (var i = 0; i < Wikiwyg.Widgets.widgets.length; i++)
        if (Wikiwyg.Widgets.widgets[i].match(nameMatch))
            return Wikiwyg.Widgets.widgets[i];
    return widget_id;
}

Wikiwyg.Widgets.mapMultipleSameWidgets = function(widget_parse) {
    var id = widget_parse.id;
    var strippedId = id.replace(/\d+$/, '');
    var nameMatch = new RegExp(strippedId + '\\d+$');
    var widgets_list = Wikiwyg.Widgets.widgets;
    for (var i = 0; i < widgets_list.length; i++) {
        var widget_name = widgets_list[i];
        if (widget_name.match(nameMatch)) {
            if (widget_data[widget_name].select_if) {
                var match = true;
                if (widget_data[widget_name].select_if.defined) {
                    for (var k = 0; k < widget_data[widget_name].select_if.defined.length; k++) {
                        if (!widget_parse[widget_data[widget_name].select_if.defined[k]])
                            match = false;
                    }
                }
                if (widget_data[widget_name].select_if.blank) {
                    for (var k = 0; k < widget_data[widget_name].select_if.blank.length; k++) {
                        if (widget_parse[widget_data[widget_name].select_if.blank[k]])
                            match = false;
                    }
                }
                if (match) {
                    id = widget_name;
                    break;
                }
            }
        }
    }

    return id;
}

// Shortcut globals.
Wikiwyg.Toolbar.Socialtext.prototype.setup_widgets = function() {
    this.setup_widgets_pulldown('Insert...');
}

var widgets_list = Wikiwyg.Widgets.widgets;
var widget_data = Wikiwyg.Widgets.widget;

proto = eval(WW_SIMPLE_MODE).prototype;

proto.fromHtml = function(html) {
    Wikiwyg.Wysiwyg.prototype.fromHtml.call(this, html);
    try {
        setTimeout(this.setWidgetHandlers.bind(this), 200);
    } catch(e) { alert('bleh: ' + e) }
}

proto.toHtml = function(func) {
    Wikiwyg.Wysiwyg.prototype.toHtml.call(this, func);
    clearInterval( this._fixer_interval_id );
    delete this._fixer_interval_id;

    /*
    if (Wikiwyg.is_ie7) {
        clearInterval( this._white_page_fixer_interval_id );
        delete this._white_page_fixer_interval_id;
    }
    */
}

proto.setWidgetHandlers = function() {
    var imgs = this.get_edit_document().getElementsByTagName('img');
    for (var ii = 0; ii < imgs.length; ii++) {
        this.setWidgetHandler(imgs[ii]);
    }
    this.revert_widget_images();
}

proto.setWidgetHandler = function(img) {
    var widget = img.getAttribute('widget');
    if (! widget) return;
    this.currentWidget = this.parseWidgetElement(img);
    this.currentWidget = this.setTitleAndId(this.currentWidget);
    this.attachTooltip(img);
}

proto.need_to_revert_widet = function(img) {
    var style = img.getAttribute("style");
    var has_style_attr = (typeof style == 'string')

    if (   has_style_attr
        || (img.getAttribute("mousedown") == 1)
        || (img.getAttribute("mouseup") == 0)
        || (img.getAttribute("mouseout") == 1)
        || (img.getAttribute("mouseover") == 0)
        || (img.getAttribute("src").match(/^\.\./))
        ) {
        return true;
    }
    return false;
}

proto.revert_widget_images = function() {
    if ( this._fixer_interval_id ) {
        return;
    }
    var self = this;
    var fixer = function() {
        var imgs = self.get_edit_document().getElementsByTagName('img');
        for (var i=0; i < imgs.length; i++) {
            var img = imgs[i];
            if (!img.getAttribute("widget")) { continue; }
            if (self.need_to_revert_widet(img)) {
                /*
                  This two height and width conditions is majorly for IE to revert
                  the image size correctly.
                */
                if ( img.getAttribute("height") ) { img.style.height = img.getAttribute("height") }
                if ( img.getAttribute("width") ) { img.removeAttribute("width"); }

                img.removeAttribute("style");
                img.removeAttribute("mouseup");
                img.removeAttribute("mousedown");
                img.removeAttribute("mouseover");
                img.removeAttribute("mouseout");

                self.attachWidgetHandlers(img);
            }
        }
        self.reclaim_element_registry_space();
    };
    this._fixer_interval_id = setInterval(fixer, 500);

    /*
    if (Wikiwyg.is_ie7) {
        this._white_page_fixer_interval_id = setInterval( function() {
            self.get_edit_document().body.style.display="";
            self.get_edit_document().body.style.display="block";
        }, 10);
    }
    */
}

proto.sanitize_dom = function(dom) {
    Wikiwyg.Wysiwyg.prototype.sanitize_dom.call(this, dom);
    this.widget_walk(dom);
}

proto.attachTooltip = function(elem) {
    if (elem.getAttribute("title"))
        return;

    var title = (typeof widget_data[this.currentWidget.id].title == "object")
      ? this.currentWidget.full
        ? widget_data[this.currentWidget.id].title.full
        : widget_data[this.currentWidget.id].title['default']
      : widget_data[this.currentWidget.id].title;

    var self = this;
    title = title.replace(/\$(\w+)/g, function() {
        var text = self.currentWidget[arguments[1]];
        if (text == '') {
            if (arguments[1] == 'page_title')
                text = Page.page_title;
            else if (arguments[1] == 'workspace_id')
                text = Page.wiki_title;
        }
        return text;
    });
    elem.setAttribute("title", title);

    this.attachWidgetHandlers(elem);
}

proto.attachWidgetHandlers = function(elem) {
    if ( !this.element_registry_push(elem) ) {
        return;
    }

    var self = this;
    DOM.Events.addListener(elem, 'mouseover', function(e) {
        e.target.setAttribute("mouseover", 1);
        e.target.setAttribute("mouseout", 0);
    });
    DOM.Events.addListener(elem, 'mouseout', function(e) {
        e.target.setAttribute("mouseover", 0);
        e.target.setAttribute("mouseout", 1);
    });

    DOM.Events.addListener(elem, 'mousedown', function(e) {
        e.target.setAttribute("mousedown", 1);
        e.target.setAttribute("mouseup", 0);
    });

    var id = this.currentWidget.id;
    if (widget_data[id] && widget_data[id].uneditable) {
        DOM.Events.addListener(elem, 'mouseup', function(e) {
            e.target.setAttribute("mousedown", 0);
            if ( e.target.getAttribute("mouseup") == 0 ) {
                if ( Wikiwyg.Widgets.widget_editing > 0 )
                    return;
                alert("This is not an editable widget. Please edit it in advanced mode.")
            }
            e.target.setAttribute("mouseup", 1);
        });
    }
    else {
        DOM.Events.addListener(elem, 'mouseup', function(e) {
            e.target.setAttribute("mousedown", 0);
            if ( e.target.getAttribute("mouseup") == 0 ) {
                if ( Wikiwyg.Widgets.widget_editing > 0 )
                    return;
                self.getWidgetInput(e.target, false, false);
            }
            e.target.setAttribute("mouseup", 1);
        });
    }
}

var wikiwyg_widgets_element_registry = new Array();
proto.reclaim_element_registry_space = function() {
    var imgs = this.get_edit_document().getElementsByTagName('img');
    for(var i = 0; i < wikiwyg_widgets_element_registry.length; i++ ) {
        var found = false;
        for (var j = 0; j < imgs.length; j++) {
            var img = imgs[j];
            if (!img.getAttribute("widget")) { continue; }
            if (wikiwyg_widgets_element_registry[i] == img) {
                found = true;
                break;
            }
        }
        if ( !found ) {
            delete wikiwyg_widgets_element_registry[i]
        }
    }
    wikiwyg_widgets_element_registry = wikiwyg_widgets_element_registry.compact();
}

proto.element_registry_push = function(elem) {
    var flag = 0;
    wikiwyg_widgets_element_registry.each(function(i) {
        if (i == elem) {
            flag++;
        }
    });
    if ( flag > 0 ) { return false; }
    wikiwyg_widgets_element_registry.push(elem)
    return true;
}

var wikiwyg_widgets_title_lookup = {
};

proto.titleInLoopup = function (field, id) {
    if (field in wikiwyg_widgets_title_lookup)
        if (id in wikiwyg_widgets_title_lookup[field])
            return wikiwyg_widgets_title_lookup[field][id];
    return '';
}

proto.pullTitleFromServer = function (field, id, data) {
    var uri = Wikiwyg.Widgets.api_for_title[field];
    uri = uri.replace(new RegExp(":" + field), id);

    var request = new Ajax.Request (
        uri,
        {
            method: 'get',
            asynchronous: false,
            requestHeaders: ['Accept','application/json']
        }
    );
    if (request.transport.status == 404)
        return id;
    else {
        var details = JSON.parse(request.transport.responseText);
        if (!(field in wikiwyg_widgets_title_lookup))
            wikiwyg_widgets_title_lookup[field] = {};
        wikiwyg_widgets_title_lookup[field][id] = details.title;

        return details.title;
    }
}

proto.setTitleAndId = function (widget) {
    var widgetDefinition = widget_data[widget.id];
    var fields = widgetDefinition.fields || [widgetDefinition.field];

    for (var i=0; i < fields.length; i++) {
        var field = fields[i];
        if (Wikiwyg.Widgets.api_for_title[field]) {
            if (!widget.title_and_id) {
                widget.title_and_id = {};
            }
            if (!widget.title_and_id[field]) {
                widget.title_and_id[field] = {id: '', title: ''};
            }
            if (widget[field]) {
                var title = this.titleInLoopup(field, widget[field]);
                if (!title)
                    title = this.pullTitleFromServer(field, widget[field]);
                widget.title_and_id[field].id = widget[field];
                widget.title_and_id[field].title = title;
            }
        }
    }

    return widget;
}

proto.parseWidgetElement = function(element) {
    return this.parseWidget(element.getAttribute('widget'));
}

proto.parseWidget = function(widget) {
    var matches;

    if ((matches = widget.match(/^(aim|yahoo|ymsgr|skype|callme|callto|http|asap|irc|file|ftp|https):([\s\S]*?)\s*$/)) ||
        (matches = widget.match(/^\{(\{(.+)\})\}$/)) || // AS-IS
        (matches = widget.match(/^"(.+?)"<(.+?)>$/)) || // Named Links
        (matches = widget.match(/^(?:"(.*)")?\{(\w+):?\s*([\s\S]*?)\s*\}$/)) ||
        (matches = widget.match(/^\.(\w+)\s*?\n([\s\S]*?)\1\s*?$/))
    ) {
        var widget_id = matches[1];
        var full = false;
        var args = matches[2];

        var widget_label;
        if ( matches.length == 4 ) {
            widget_label = matches[1];
            widget_id = matches[2];
            args = matches[3];
        }

        if ( widget_id.match(/^\{/) ) {
            widget_id = "asis";
        }

        widget_id = Wikiwyg.Widgets.resolve_synonyms(widget_id);

        if (widget_id.match(/^(.*)_full$/)) {
            var widget_id = RegExp.$1;
            var full = true;
        }

        // Since multiple versions of the same widget have the same wafl
        // structure we can use the parser for any version. Might as well be the first.
        var isAMultipleWidget = Wikiwyg.Widgets.isMultiple(widget_id);
        if (isAMultipleWidget) {
            widget_id = Wikiwyg.Widgets.getFirstMultiple(widget_id);
        }

        var widget_parse;
        if (this['parse_widget_' + widget_id]) {
            widget_parse = this['parse_widget_' + widget_id](args);
            widget_parse.id = widget_id;
        }
        else if (widget_data[widget_id]) {
            widget_parse = {};
            widget_parse.id = widget_id;
        }
        else {
            widget_parse = {};
            widget_parse.id = 'unknown';
            widget_parse.unknown_id = widget_id;
        }

        widget_parse.full = full;
        widget_parse.widget = widget;
        if (widget_label)
            widget_parse.label = widget_label;

        if (isAMultipleWidget) {
            var previousId = widget_parse.id;
            widget_parse.id = Wikiwyg.Widgets.mapMultipleSameWidgets(widget_parse);
            if (widget_parse.id != previousId && this['parse_widget_' + widget_parse.widget_id]) {
                widget_parse = this['parse_widget_' + widget_parse.id](args);
                widget_parse.id = widget_id;
            }
        }

        return widget_parse;
    }
    else
        throw('Unexpected Widget >>' + widget + '<< in parseWidget');
}

for (var i = 0; i < widgets_list.length; i++) {
    var gen_widget_parser = function(data) {
        return function(widget_args) {
            var widget_parse = {};
            if (data.fields) {
                for (var i = 0; i < data.fields.length; i++) {
                    widget_parse[ data.fields[i] ] = '';
                }
            }
            else if (data.field) {
                widget_parse[ data.field ] = '';
            }
            if (! widget_args.match(/\S/)) {
                return widget_parse;
            }

            if (! (data.field || data.parse)) {
                data.field = data.fields[0];
            }

            if (data.field) {
                widget_parse[ data.field ] = widget_args;
                return widget_parse;
            }

            var widgetFields = data.parse.fields || data.fields;
            var regexp = data.parse.regexp;
            var regexp2 = regexp.replace(/^\?/, '');
            if (regexp != regexp2)
                regexp = Wikiwyg.Widgets.regexps[regexp2];
            var tokens = widget_args.match(regexp);
            if (tokens) {
                for (var i = 0; i < widgetFields.length; i++)
                    widget_parse[ widgetFields[i] ] = tokens[i+1];
            }
            else {
                if (data.parse.no_match)
                    widget_parse[ data.parse.no_match ] = widget_args;
            }
            if (widget_parse.search_term) {
                var term = widget_parse.search_term;
                var term2 = term.replace(/^(tag|category|title):/, '');
                if (term == term2) {
                    widget_parse.search_type = 'text';
                }
                else {
                    widget_parse.search_type = RegExp.$1;
                    if (widget_parse.search_type == 'tag')
                        widget_parse.search_type = 'category';
                    widget_parse.search_term = term2;
                }
            }
            return widget_parse;
        }
    }

    var gen_do_widget = function(w) {
        return function() {
            try {
                this.currentWidget = this.parseWidget('{' + w + ': }');
                this.currentWidget = this.setTitleAndId(this.currentWidget);
                var selection = this.get_selection_text();
                selection = selection.replace(/\\s+$/,'');
                this.getWidgetInput(this.currentWidget, selection, true);
            } catch (E) {
                // ignore error from parseWidget
            }
        }
    };

    var widget = widgets_list[i];
    proto['parse_widget_' + widget] = gen_widget_parser(widget_data[widget]);
    proto['do_widget_' + widget] = gen_do_widget(widget);
}

proto.widget_walk = function(elem) {
    for (var part = elem.firstChild; part; part = part.nextSibling) {
        if (part.nodeType != 1) continue;
        if (part.nodeName == 'SPAN' || part.nodeName == 'DIV') {
            var name = part.className;
            if (name && name.match(/(nlw_phrase|wafl_block)/)) {
                part = this.replace_widget(part);
            }
        }
        this.widget_walk(part);
    }
}

proto.replace_widget = function(elem) {
    var comment = elem.lastChild;
    if (comment.nodeType != 8) return;
    if (! comment.nodeValue.match(/^\s*wiki:/)) return;
    var widget = comment.nodeValue.replace(/^\s*wiki:\s*([\s\S]*?)\s*$/, '$1');
    widget = widget.replace(/-=/g, '-');

    var widget_image = Wikiwyg.createElementWithAttrs('img',
        {
            'src': this.getWidgetImageUrl(widget),
            'widget': widget
        }
    );
    elem.parentNode.replaceChild(widget_image, elem);
    return widget_image;
}

proto.insert_widget = function(widget, widget_element) {
    var html = '<img src="' + this.getWidgetImageUrl(widget) +
        '" widget="' + widget.replace(/"/g,"&quot;") + '" />';

    var self = this;
    var docbody = this.get_edit_document().body;

    var changer = function() {
        try {
            if ( widget_element ) {
                if ( widget_element.parentNode ) {
                    var div = self.get_edit_document().createElement("div");
                    div.innerHTML = html;
                    widget_element.parentNode.replaceChild(div.firstChild, widget_element);
                }
                else {
                    self.insert_html(html);
                }
            }
            else {
                self.insert_html(html);
            }
            self.setWidgetHandlers();
        }
        catch(e) {
            setTimeout(changer, 100);
        }
    }

    this.get_edit_window().focus();
    docbody.focus();
    changer();
}

proto.getWidgetImageText = function(widget_text) {
    var text = widget_text;
    try {
        var widget = this.parseWidget(widget_text);

        // XXX Hack for html block. Should key off of 'uneditable' flag.
        if (widget_text.match(/^\.html/))
            text = widget_data.html.title;
        else if (widget.id && widget_data[widget.id].image_text) {
            for (var i=0; i < widget_data[widget.id].image_text.length; i++) {
                if (widget_data[widget.id].image_text[i].field == 'default') {
                    text = widget_data[widget.id].image_text[i].text;
                    break;
                }
                else if (widget[widget_data[widget.id].image_text[i].field]) {
                    text = widget_data[widget.id].image_text[i].text;
                    break;
                }
            }
        }

        var fields = text.match(new RegExp('%\\S+', 'g'));
        if (fields)
            for (var i=0; i < fields.length; i++) {
                var field = fields[i].slice(1);
                if (widget[field])
                    text = text.replace(new RegExp('%' + field), widget[field]);
                else
                    text = text.replace(new RegExp('%' + field), '');
            }
    }
    catch (E) {
        // parseWidget can throw an error
        // Just ignore and set the text to be the widget text
    }

    return text;
}

proto.getWidgetImageUrl = function(widget_text) {
    var md5 = MD5(this.getWidgetImageText(widget_text));
    var url = nlw_make_static_path('/images/widgets/' + md5 + '.png');
    return url;
}

proto.create_wafl_string = function(widget, form) {
    var data = widget_data[widget];
    var result = data.pattern || '{' + widget + ': %s}';

    var fields =
        data.field ? [ data.field ] :
        data.fields ? data.fields :
        [];
    var values = this.form_values(widget, form);
    for (var j = 0; j < fields.length; j++) {
        var token = new RegExp('%' + fields[j]);
        result = result.replace(token, values[fields[j]]);
    }

    result = result.
        replace(/^\"\s*\"/, '').
        replace(/\[\s*\]/, '').
        replace(/\<\s*\>/, '').
        replace(/\s;\s/, ' ').
        replace(/\s\s+/g, ' ').
        replace(/^\{(\w+)\: \}$/,'{$1}');
    if (values.full)
        result = result.replace(/^(\{\w+)/, '$1_full');
    return result;
}

for (var i = 0; i < widgets_list.length; i++) {
    var widget = widgets_list[i];
    var gen_handle = function(widget) {
        return function(form) {
            var values = this.form_values(widget, form);
            this.validate_fields(widget, values);
            return this.create_wafl_string(widget, form);
        };
    };
    proto['handle_widget_' + widget] = gen_handle(widget);
}

proto.form_values = function(widget, form) {
    var data = widget_data[widget];
    var fields =
        data.field ? [ data.field ] :
        data.fields ? data.fields :
        [];
    var values = {};

    for (var i = 0; i < fields.length; i++) {
        var value = '';

        if (this.currentWidget.title_and_id && this.currentWidget.title_and_id[fields[i]] && this.currentWidget.title_and_id[fields[i]].id)
            value = this.currentWidget.title_and_id[fields[i]].id;
        else
            value = form[fields[i]].value.
                replace(/^\s*/, '').
                replace(/\s*$/, '');
        if (form['st-widget-' + fields[i] + '-rb']) {
            var whichValue = ST.getRadioValue('st-widget-' + fields[i] + '-rb');
            if (whichValue == 'current') {
                value = '';
            }
        }
        values[fields[i]] = value;
    }
    if (values.label) {
        values.label = values.label.replace(/^"*/, '').replace(/"*$/, '');
    }
    if (values.search_term) {
        var type = this.get_radio(form.search_type);
        if (type && type.value != 'text')
            values.search_term = type.value + ':' + values.search_term;
    }
    values.full = (form.full && form.full.checked);

    return values;
}

proto.get_radio = function(elem) {
    if (!(elem && elem.length)) return;
    for (var i = 0; i <= elem.length; i++) {
        if (elem[i].checked)
            return elem[i];
    }
}

proto.validate_fields = function(widget, values) {
    var data = widget_data[widget];
    var required = data.required || (data.field ? [data.field] : null);
    if (required) {
        for (var i = 0; i < required.length; i++) {
            var field = required[i];
            if (! values[field].length) {
                var label = Wikiwyg.Widgets.fields[field];
                throw("'" + label + "' is a required field");
            }
        }
    }

    var require = data.require_one;
    if (require) {
        var found = 0;
        labels = [];
        for (var i = 0; i < require.length; i++) {
            var field = require[i];
            labels.push(Wikiwyg.Widgets.fields[field]);
            if (values[field].length)
                found++;
        }
        if (! found)
            throw("Requires one of: " + labels.join(', '));
    }

    for (var field in values) {
        var regexp = Wikiwyg.Widgets.match[field];
        if (! regexp) continue;
        if (! values[field].length) continue;
        var fieldOk = true;
        if (this.currentWidget.title_and_id && this.currentWidget.title_and_id[field])
            fieldOk = this.currentWidget.title_and_id[field].id.match(regexp);
        else
            fieldOk = values[field].match(regexp);

        if (!fieldOk) {
            var label = Wikiwyg.Widgets.fields[field];
            throw("'" + label + "' has an invalid value");
        }
    }

    var checks = data.checks;
    if (checks) {
        for (var i = 0; i < checks.length; i++) {
            var check = checks[i];
            this[check].call(this, values);
        }
    }
}

proto.require_page_if_workspace = function(values) {
    if (values.workspace_id.length && ! values.page_title.length)
        throw("Page Title required if Workspace Id specified");
}

proto.hookLookaheads = function(dialog) {
    var cssSugestionWindow = 'st-widget-lookaheadsuggestionwindow';
    var cssSuggestionBlock = 'st-widget-lookaheadsuggestionblock';
    var cssSuggestionText = 'st-widget-lookaheadsuggestion';

    if ($('st-widget-workspace_id')) {
        window.workspaceLookahead = new WorkspaceLookahead(
            dialog,
            'st-widget-workspace_id',
            cssSugestionWindow,
            cssSuggestionBlock,
            cssSuggestionText,
            'workspaceLookahead',
            this.currentWidget
        );
    }

    if ($('st-widget-page_title')) {
        window.pageLookahead = new PageNameLookahead(
            dialog,
            'st-widget-page_title',
            cssSugestionWindow,
            cssSuggestionBlock,
            cssSuggestionText,
            'pageLookahead',
            this.currentWidget
        );
        window.pageLookahead.defaultWorkspace = Socialtext.wiki_id;
    }

    if ($('st-widget-tag_name')) {
        window.tagLookahead = new TagLookahead(
            dialog,
            'st-widget-tag_name',
            cssSugestionWindow,
            cssSuggestionBlock,
            cssSuggestionText,
            'tagLookahead',
            this.currentWidget
        );
        window.tagLookahead.defaultWorkspace = Socialtext.wiki_id;
    }

    if ($('st-widget-weblog_name')) {
        window.weblogLookahead = new WeblogLookahead(
            dialog,
            'st-widget-weblog_name',
            cssSugestionWindow,
            cssSuggestionBlock,
            cssSuggestionText,
            'weblogLookahead',
            this.currentWidget
        );
        window.weblogLookahead.defaultWorkspace = Socialtext.wiki_id;
    }

    if ($('st-widget-section_name')) {
        window.sectionNameLookahead = new PageSectionLookahead(
            dialog,
            'st-widget-section_name',
            cssSugestionWindow,
            cssSuggestionBlock,
            cssSuggestionText,
            'sectionNameLookahead',
            this.currentWidget,
            'st-widget-page_title'
        );
        window.sectionNameLookahead.defaultWorkspace = Socialtext.wiki_id;
        window.sectionNameLookahead.defaultPagename = $('st-page-editing-pagename').value;
    }

    if ($('st-widget-image_name')) {
        window.imageNameLookahead = new PageAttachmentLookahead(
            dialog,
            'st-widget-image_name',
            cssSugestionWindow,
            cssSuggestionBlock,
            cssSuggestionText,
            'imageNameLookahead',
            widget,
            'st-widget-page_title'
        );
        window.imageNameLookahead.defaultWorkspace = Socialtext.wiki_id;
        window.imageNameLookahead.defaultPagename = $('st-page-editing-pagename').value;
    }

    if ($('st-widget-file_name')) {
        window.fileNameLookahead = new PageAttachmentLookahead(
            dialog,
            'st-widget-file_name',
            cssSugestionWindow,
            cssSuggestionBlock,
            cssSuggestionText,
            'fileNameLookahead',
            widget,
            'st-widget-page_title'
        );
        window.fileNameLookahead.defaultWorkspace = Socialtext.wiki_id;
        window.fileNameLookahead.defaultPagename = $('st-page-editing-pagename').value;
    }
}

Wikiwyg.Widgets.widget_editing = 0;

proto.getWidgetInput = function(widget_element, selection, new_widget) {
    if ( Wikiwyg.Widgets.widget_editing > 0 )
        return;
    Wikiwyg.Widgets.widget_editing++;

    if ( widget_element.nodeName ) {
        this.currentWidget = this.parseWidgetElement(widget_element);
        this.currentWidget = this.setTitleAndId(this.currentWidget);
        this.currentWidget.element = widget_element;
    }
    else {
        this.currentWidget = widget_element;
    }

    var widget = this.currentWidget.id;

    var template = 'widget_' + widget + '_edit.html';
    var html = Jemplate.process(template, this.currentWidget);

    var box = new Widget.Lightbox.Socialtext({contentClassName: 'jsan-widget-lightbox-content-wrapper', wrapperClassName: 'st-lightbox-dialog'});
    box.content( html );
    box.effects('RoundedCorners');
    box.create();

    this.hookLookaheads(box.divs.contentWrapper);

    var self = this;
    // XXX - Had to resort to this because we couldn't figure out how to
    // inspect which button got clicked. Possibly refactor.
    var callback = function(element) {
        if (Wikiwyg.is_ie) {
            wikiwyg.toolbarObject.styleSelect.style.display="none"
        }

        var form = element.getElementsByTagName('form')[0];

        var onreset = function() {
            clearInterval(intervalId);
            box.releaseFocus();
            box.release();
            Wikiwyg.Widgets.widget_editing--;
            return false;
        }
        var onsubmit = function() {
            var error = null;
            try {
                var widget_string = self['handle_widget_' + widget](form);
                var widget_text = self.getWidgetImageText(widget_string);
                clearInterval(intervalId);
                Ajax.post(
                    location.pathname,
                    'action=wikiwyg_generate_widget_image;' +
                    'widget=' + encodeURIComponent(widget_text) +
                    ';widget_string=' + encodeURIComponent(widget_string),
                    function() {
                        self.insert_widget(widget_string, widget_element);
                        box.release();
                        if (Wikiwyg.is_ie)
                            wikiwyg.toolbarObject.styleSelect.style.display = "";
                    }
                );
            }
            catch(e) {
                error = String(e);
                var div = document.getElementById(
                    widget + '_widget_edit_error_msg'
                );
                if (div) {
                    div.style.display = 'block';
                    div.innerHTML = '<span>' + error + '</span>';
                }
                else {
                    alert(error);
                }
                if (Wikiwyg.is_ie)
                    wikiwyg.toolbarObject.styleSelect.style.display = "";
                Wikiwyg.Widgets.widget_editing--;
                return false;
            }
            Wikiwyg.Widgets.widget_editing--;
            return false;
        }
        var i = 0;
        var set_wafl_text = function() {
            var td = document.getElementById(widget + '_wafl_text');
            if (td) {
                var t =
                    ' <span>' +
                    self.create_wafl_string(widget, form).
                        replace(/</g, '&lt;') +
                    '</span> ';
                td.innerHTML = t;
            }
        }

        form.onreset = onreset;
        form.onsubmit = onsubmit;

        box.restrictFocus(form);

        var data = widget_data[widget];
        var primary_field =
            data.primary_field ||
            data.field ||
            (data.required && data.required[0]) ||
            data.fields[data.fields.length - 1];
        if (new_widget && selection) {
            selection = selection.replace(
                /^<DIV class=wiki>([^\n]*?)(?:&nbsp;)*<\/DIV>$/mg, '$1'
            ).replace(
                /<DIV class=wiki>\r?\n<P><\/P><BR>([\s\S]*?)<\/DIV>/g, '$1'
            ).replace(/<BR>/g,'');

            form[primary_field].value = selection;
        }

        setTimeout(function() {try {form[primary_field].focus()} catch(e) {}}, 100);
        var intervalId = setInterval(set_wafl_text.bind(this), 500);
    }

    box.show(callback);
}

Widget.Lightbox.Socialtext = function (param) {
    Widget.Lightbox.call(this,param);
}

Widget.Lightbox.Socialtext.prototype = new Widget.Lightbox;

Widget.Lightbox.Socialtext.prototype.restrictFocus = function(form) {
    this._focusd_form = form;

    // Need to get a list of any tag that can get focus: e.g. input and anchors
    var inputs = new Array(form.getElementsByTagName("input"));
    inputs.concat(form.getElementsByTagName("a"));

    var focused = false ;
    var total_fields = inputs.length;

    for( var ii=0; ii < inputs.length; ii++ ) {
        inputs[ii].onfocus = function() {
            focused = true;
        };
        inputs[ii].onblur = function(idx) {
            return function(e) {
                focused = false;
                setTimeout( function() {
                    // XXX Need to check for visible fields
                    if ( !focused ) {
                        inputs[idx].focus();
                    }
                }, 30);
            }
        }(ii);
    }
}

Widget.Lightbox.Socialtext.prototype.releaseFocus = function(form){
    if ( !form ) form = this._focusd_form;
    if ( !form ) return;
    var inputs = form.getElementsByTagName("input");
    for( var ii=0; ii < inputs.length; ii++ ) {
        var _ = inputs[ii];
        _.onfocus = function() {};
        _.onblur  = function() {};
    }
}

Widget.Lightbox.Socialtext.prototype.applyHandlers = function(){
    if(!this.div)
        return;

    var self = this;
    if (Widget.Lightbox.is_ie) {
        DOM.Events.addListener(window, "resize", function () {
            self.applyStyle();
        });
    }

    if ($('st-widgets-moreoptions')) {
        DOM.Events.addListener(document.getElementById('st-widgets-moreoptions'), 'click', function () {
            self.toggleOptions();
        });
    }
}

Widget.Lightbox.Socialtext.prototype.toggleOptions = function() {
    var link = document.getElementById('st-widgets-moreoptions');
    var panel = document.getElementById('st-widgets-moreoptionspanel');
    var icon = document.getElementById('st-widgets-optionsicon');
    if (panel) {
        if (link.innerHTML == 'More options') {
            panel.style.display = "block";
            link.innerHTML = 'Fewer options';
            icon.src = nlw_make_static_path('/images/st/hide_more.gif');
        }
        else {
            panel.style.display = "none";
            link.innerHTML = 'More options';
            icon.src = nlw_make_static_path('/images/st/show_more.gif');
        }
    }
}

Widget.Lightbox.Socialtext.prototype.release = function() {
    /**
     * What we would prefer to do is remove the entire lighbox from the DOM
     * but IE does not handle the delete well. So, instead, we delete everything
     * inside the wrapper. That way we get rid of the controls that- have unique
     * IDs so the rest of the code will work properly.
     */
    this.div.removeChild(this.divs.contentWrapper);
    this.div.removeChild(this.divs.background);
    this.hide();
}

Widget.Lightbox.Socialtext.prototype.hide = function() {
    Widget.Lightbox.prototype.hide.call(this);
    if (this.div.parentNode) {
        this.releaseFocus();
        if (Wikiwyg.is_ie) {
            wikiwyg.toolbarObject.styleSelect.style.display=""
        }
    }
}

eval(WW_ADVANCED_MODE).prototype.setup_widgets = function() {
    var widgets_list = Wikiwyg.Widgets.widgets;
    var widget_data = Wikiwyg.Widgets.widget;
    var p = eval(this.classname).prototype;
    for (var i = 0; i < widgets_list.length; i++) {
        var widget = widgets_list[i];
        p.markupRules['widget_' + widget] =
            widget_data[widget].markup ||
            ['bound_phrase', '{' + widget + ': ', '}'];
        p['do_widget_' + widget] = Wikiwyg.Wikitext.make_do('widget_' + widget);
    }
}

proto = eval(WW_ADVANCED_MODE).prototype;

proto.format_img = function(element) {
    var widget = element.getAttribute('widget');
    if (! widget) {
        return Wikiwyg.Wikitext.prototype.format_img.call(this, element);
    }

    if ( widget.match(/^\{include/) ) {
        this.treat_include_wafl(element);
    } else if ( widget.match(/^\.\w+\n/) ) {
        this.assert_blank_line();
    } else {
        this.assert_space_or_newline();
    }

    widget = widget.replace(/-=/g, '-').replace(/==/g,'=').replace(/&quot;/g,'"').replace(/&lt;/g,'<').replace(/&gt;/g,'>');
    this.appendOutput(widget);
    this.smart_trailing_space(element);
}

proto.format_a = function(element) {
    if (this.is_opaque(element))
        return this.handle_wafl_block(element);

    Wikiwyg.Wikitext.prototype.format_a.call(this, element);
}

proto.format_div = function(element) {
    if (this.is_opaque(element))
        return this.handle_wafl_block(element);

    Wikiwyg.Wikitext.prototype.format_div.call(this, element);
}

proto.destroyPhraseMarkup = function(element) {
    if (this.contain_widget_image(element))
        return false;
    if (this.start_is_no_good(element) || this.end_is_no_good(element)) {
        return this.destroyElement(element);
    }
    return false;
}

proto.contain_widget_image = function(element) {
    for(var ii = 0; ii < element.childNodes.length; ii++ ) {
        var e = element.childNodes[ii]
        if ( e.nodeType == 1 ) {
            if ( e.nodeName == 'IMG' ) {
                if ( e.getAttribute("widget") )
                    return true;
            }
        }
    }
}

proto.treat_include_wafl = function(element) {
    // Note: element should be a <span> or an <img>

    if ( element.nodeType != 1 )
        return;

    if ( element.nodeName == 'SPAN' ) {
        var inner = element.innerHTML;
        if(!inner.match(/<!-- wiki: \{include: \[.+\]\} -->/)) {
            return;
        }
    }
    else if ( element.nodeName == 'IMG' ) {
        var widget = element.getAttribute("widget");
        if (!widget.match(/^\{include/))
            return;
    }

    // If this is a {include} widget, we squeeze
    // whitepsaces before and after it. Becuase
    // {include} is supposed to be in a <p> of it's own.
    // If user type "{include: Page} Bar", that leaves
    // an extra space in <p>.

    var next = element.nextSibling;
    if (next && next.tagName &&
            next.tagName.toLowerCase() == 'p') {
        next.innerHTML = next.innerHTML.replace(/^ +/,"");
    }

    var prev = element.previousSibling;
    if (prev
        && prev.tagName
        && prev.tagName.toLowerCase() == 'p') {
        if (prev.innerHTML.match(/^[ \n\t]+$/)) {
            // format_p is already called, so it's too late
            // to do this:
            //     prev.parentNode.removeChild( prev );

            // Remove two blank lines for it's the output
            // of an empty <p>
            var line1 = this.output.pop();
            var line2 = this.output.pop();
            // But if they are not newline, put them back
            // beause we don't want to mass around there.
            if ( line1 != "\n" || line2 != "\n" ) {
                this.output.push(line2);
                this.output.push(line1);
            }
        }
    }
}

proto.handle_bound_phrase = function(element, markup) {
    if (! this.element_has_only_image_content(element) )
        if (! this.element_has_text_content(element))
            return;

    if (element.innerHTML.match(/^\s*<br\s*\/?\s*>/)) {
        this.appendOutput("\n");
        element.innerHTML = element.innerHTML.replace(/^\s*<br\s*\/?\s*>/, '');
    }
    this.appendOutput(markup[1]);
    this.no_following_whitespace();
    this.walk(element);
    this.appendOutput(markup[2]);
}

proto.markup_bound_phrase = function(markup_array) {
    var markup_start = markup_array[1];
    markup_start = markup_start.replace(/\d+: $/, ': ');
    var markup_finish = markup_array[2];
    var scroll_top = this.area.scrollTop;
    if (markup_finish == 'undefined')
        markup_finish = markup_start;
    if (this.get_words())
        this.add_markup_words(markup_start, markup_finish, null);
    this.area.scrollTop = scroll_top;
}
// BEGIN Wikiwyg/DataValidator.js
proto = new Subclass('Wikiwyg.DataValidator');

proto.stopped = false;

proto.setup = function(div_id) {
    this.div = document.getElementById(div_id);
    this.setupTest();
}

proto.setupTest = function() {
    var self = this;
    Ajax.get(
        'index.cgi?action=wikiwyg_all_page_ids', 
        function(r) { self.showPageIds(r) }
    );
}

proto.showPageIds = function(page_list) {
    this.all_page_ids = page_list.split('\n');
    this.div.innerHTML =
        "<p>Total Number of pages : " + this.all_page_ids.length + '</p>';
    this.start_submit = Wikiwyg.createElementWithAttrs(
        'input', { type: "submit", value: "Run Tests" }, document);
    var self = this;
    this.start_submit.onclick = function() { self.runAllTests() };
    this.div.appendChild(this.start_submit);
}

proto.stopTests = function() {
    this.stopped = true;
    this.start_submit.onclick = null;
    this.start_submit.value = 'Testing Stopped';
}

proto.runAllTests = function() {
    var self = this;
    this.start_submit.onclick = function() { self.stopTests() };
    this.start_submit.value = 'Stop Tests';
    var run_all = function(session_id) {
        self.session_id = session_id;
        self.initProgressBar();

        self.current_test_number = 0;
        self.runPageTest();
    }
    Ajax.get('index.cgi?action=wikiwyg_start_validation', run_all);
}

proto.initProgressBar = function() {
    this.remaining_tests = this.all_page_ids.length;
    this.current_page_id_span = document.createElement("span");
    this.remaining_tests_span = document.createElement("span");
    this.progress_bar = document.createElement("p");
    var a = document.createElement('span');
    a.appendChild(document.createTextNode('Remaining tests: '));
    var b = document.createElement('span');
    b.appendChild(document.createTextNode('. Running test for: '));
    this.progress_bar.appendChild(a);
    this.progress_bar.appendChild(this.remaining_tests_span);
    this.progress_bar.appendChild(b);
    this.progress_bar.appendChild(this.current_page_id_span);
    this.div.appendChild(this.progress_bar);
    var c = document.createElement('p');
    c.appendChild(document.createTextNode(
        'Results will be in /tmp/wikiwyg_data_validation/' + this.session_id
    ));
    this.div.appendChild(c);
}

proto.updateProgressBar = function() {
    this.current_page_id_span.innerHTML = this.page_id;
    this.remaining_tests_span.innerHTML = this.remaining_tests--;
}

proto.runPageTest = function() {
    if (this.stopped)
        return;
    this.page_id = this.all_page_ids[this.current_test_number];
    this.updateProgressBar();
    var self = this;
    Ajax.get(
        'index.cgi?action=wikiwyg_get_page_html2;page_id=' + this.page_id +
        ';session_id=' + this.session_id,
        function(r) { self.wikiwygRoundTrip(r) }
    );
}

proto.wikiwygRoundTrip = function(html) {
    var simple = wikiwyg.mode_objects[WW_SIMPLE_MODE];
    var self = this;
    simple.fromHtml(html);
    simple.toHtml( function(h) { self.sendBackWikitext(h) } );
}

proto.sendBackWikitext = function(html) {
    var advanced = wikiwyg.mode_objects[WW_ADVANCED_MODE];
    var wikitext = advanced.convert_html_to_wikitext(html);
    var uri = location.pathname;
    var postdata = 'action=wikiwyg_save_validation_result;session_id=' +
        this.session_id + ';page_id=' + this.page_id + ';content=' +
        encodeURIComponent(wikitext);
    var self = this;
    var already_run = false;
    var func = function(who_cares) {
        if (already_run) return;
        already_run = true;
        self.current_test_number++;
        if (self.current_test_number < self.all_page_ids.length) {
            self.runPageTest();
        }
        else {
            self.page_id = '';
            self.updateProgressBar();
        }
    }
    // If not done in 5 seconds, we need to move on. This happens in IE.
    setTimeout(func, 5000);
    Ajax.post(uri, postdata, func);
}
// BEGIN l10ns.js
var LocalizedStrings = {"zj":{"You must select two revisions to compare.":"y\u304a\u3046 m\u3046s7 S\u3048L\u3048C7 7W\u304a r\u3048v\u3044s\u3044\u304aNs 7\u304a C\u304aMp\u3042r\u3048.","You cannot compare a revision to itself.":"y\u304a\u3046 c\u3042nN\u304a7 C\u304aMp\u3042r\u3048 \u3042 R\u3048V\u3044S\u3044\u304an 7\u304a \u30447S\u3048Lf."},"zz":{"You must select two revisions to compare.":"y0u mUs7 S3L3C7 7W0 r3vIsI0Ns 70 C0Mp4r3.","You cannot compare a revision to itself.":"y0u c4nN07 C0Mp4r3 4 R3ViSi0n 70 I7S3Lf."}};

function loc() {
    var locale = Socialtext.loc_lang;
    var dict = LocalizedStrings[locale] || new Array;
    var str = arguments[0] || "";
    var l10n = dict[str];

    if (!l10n) {
        var nstr = str.replace(/\"/g, "\\\"");
        l10n = dict[nstr] || str;
    }

    /* If the hash-lookup failed, convert [_1] into %1 and try again. */
    if (!l10n) {
        var nstr = str.replace(/\[_(\d+)\]/g, "%$1");
        l10n = dict[nstr] || str;
    }

    /* Convert both %1 and [_1] style vars into the given arguments */
    for (var i = 1; i < arguments.length; i++) {
        var rx = new RegExp("\\[_" + i + "\\]", "g");
        var rx2 = new RegExp("%" + i + "", "g");
        l10n = l10n.replace(rx, arguments[i]);
        l10n = l10n.replace(rx2, arguments[i]);
    }

    return l10n;
}

