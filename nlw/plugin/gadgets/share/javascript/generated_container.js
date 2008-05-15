/* FILE: core/util.js */
/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

var gadgets = gadgets || {};

/**
 * @fileoverview General purpose utilities that gadgets can use.
 */

/**
 * @static
 * @class Provides general-purpose utility functions.
 * @name gadgets.util
 */

gadgets.util = function() {
  /**
   * Parses URL parameters into an object.
   * @return {Array.&lt;String&gt;} The parameters
   */
  function parseUrlParams() {
    // Get settings from url, 'hash' takes precedence over 'search' component
    // don't use document.location.hash due to browser differences.
    var query;
    var l = document.location.href;
    var queryIdx = l.indexOf("?");
    var hashIdx = l.indexOf("#");
    if (hashIdx === -1) {
      query = l.substr(queryIdx + 1);
    } else {
      // essentially replaces "#" with "&"
      query = [l.substr(queryIdx + 1, hashIdx - queryIdx - 1), "&",
               l.substr(hashIdx + 1)].join("");
    }
    return query.split("&");
  }

  var parameters = null;
  var features = {};
  var onLoadHandlers = [];

  // Maps code points to the value to replace them with.
  // If the value is "false", the character is removed entirely, otherwise
  // it will be replaced with an html entity.
  var escapeCodePoints = {
   // nul; most browsers truncate because they use c strings under the covers.
   0 : false,
   // new line
   10 : true,
   // carriage return
   13 : true,
   // double quote
   34 : true,
   // single quote
   39 : true,
   // less than
   60 : true,
   // greater than
   62 : true,
   // Backslash
   92 : true,
   // line separator
   8232 : true,
   // paragraph separator
   8233 : true
  };

  /**
   * Regular expression callback that returns strings from unicode code points.
   *
   * @param {Array} match Ignored
   * @param {String} value The codepoint value to convert
   * @return {String} The character corresponding to value.
   */
  function unescapeEntity(match, value) {
    return String.fromCharCode(value);
  }

  /**
   * Initializes feature parameters.
   */
  function init(config) {
    features = config["core.util"] || {};
  }
  if (gadgets.config) {
    gadgets.config.register("core.util", null, init);
  }

  return /** @scope gadgets.util */ {

    /**
     * Gets the URL parameters.
     *
     * @return {Object} Parameters passed into the query string
     * @member gadgets.util
     * @private Implementation detail.
     */
    getUrlParameters : function () {
      if (parameters !== null) {
        return parameters;
      }
      parameters = {};
      var pairs = parseUrlParams();
      var unesc = window.decodeURIComponent ? decodeURIComponent : unescape;
      for (var i = 0, j = pairs.length; i < j; ++i) {
        var pos = pairs[i].indexOf('=');
        if (pos === -1) {
          continue;
        }
        var argName = pairs[i].substring(0, pos);
        var value = pairs[i].substring(pos + 1);
        // difference to IG_Prefs, is that args doesn't replace spaces in
        // argname. Unclear on if it should do:
        // argname = argname.replace(/\+/g, " ");
        value = value.replace(/\+/g, " ");
        parameters[argName] = unesc(value);
      }
      return parameters;
    },

    /**
     * Creates a closure that is suitable for passing as a callback.
     * Any number of arguments
     * may be passed to the callback;
     * they will be received in the order they are passed in.
     *
     * @param {Object} scope The execution scope; may be null if there is no
     *     need to associate a specific instance of an object with this
     *     callback
     * @param {Function} callback The callback to invoke when this is run;
     *     any arguments passed in will be passed after your initial arguments
     * @param {Object} var_args Initial arguments to be passed to the callback
     *
     * @member gadgets.util
     * @private Implementation detail.
     */
    makeClosure : function (scope, callback, var_args) {
      // arguments isn't a real array, so we copy it into one.
      var baseArgs = [];
      for (var i = 2, j = arguments.length; i < j; ++i) {
       baseArgs.push(arguments[i]);
      }
      return function() {
        // append new arguments.
        var tmpArgs = baseArgs.slice();
        for (var i = 0, j = arguments.length; i < j; ++i) {
          tmpArgs.push(arguments[i]);
        }
        return callback.apply(scope, tmpArgs);
      };
    },

    /**
     * Utility function for generating an "enum" from an array.
     *
     * @param {Array.<String>} values The values to generate.
     * @return {Map&lt;String,String&gt;} An object with member fields to handle
     *   the enum.
     *
     * @private Implementation detail.
     */
    makeEnum : function (values) {
      var obj = {};
      for (var i = 0, v; v = values[i]; ++i) {
        obj[v] = v;
      }
      return obj;
    },

    /**
     * Gets the feature parameters.
     *
     * @param {String} feature The feature to get parameters for
     * @return {Object} The parameters for the given feature, or null
     *
     * @member gadgets.util
     */
    getFeatureParameters : function (feature) {
      return typeof features[feature] === "undefined"
          ? null : features[feature];
    },

    /**
     * Returns whether the current feature is supported.
     *
     * @param {String} feature The feature to test for
     * @return {Boolean} True if the feature is supported
     *
     * @member gadgets.util
     */
    hasFeature : function (feature) {
      return typeof features[feature] !== "undefined";
    },

    /**
     * Registers an onload handler.
     * @param {Function} callback The handler to run
     *
     * @member gadgets.util
     */
    registerOnLoadHandler : function (callback) {
      onLoadHandlers.push(callback);
    },

    /**
     * Runs all functions registered via registerOnLoadHandler.
     * @private Only to be used by the container, not gadgets.
     */
    runOnLoadHandlers : function () {
      for (var i = 0, j = onLoadHandlers.length; i < j; ++i) {
        onLoadHandlers[i]();
      }
    },

    /**
     * Escapes the input using html entities to make it safer.
     *
     * If the input is a string, uses gadgets.util.escapeString.
     * If it is an array, calls escape on each of the array elements
     * if it is an object, will only escape all the mapped keys and values if
     * the opt_escapeObjects flag is set. This operation involves creating an
     * entirely new object so only set the flag when the input is a simple
     * string to string map.
     * Otherwise, does not attempt to modify the input.
     *
     * @param {Object} input The object to escape
     * @param {Boolean} opt_escapeObjects Whether to escape objects.
     * @return {Object} The escaped object
     * @private Only to be used by the container, not gadgets.
     */
    escape : function(input, opt_escapeObjects) {
      if (!input) {
        return input;
      } else if (typeof input === "string") {
        return gadgets.util.escapeString(input);
      } else if (typeof input === "array") {
        for (var i = 0, j = input.length; i < j; ++i) {
          input[i] = gadgets.util.escape(input[i]);
        }
      } else if (typeof input === "object" && opt_escapeObjects) {
        var newObject = {};
        for (var field in input) if (input.hasOwnProperty(field)) {
          newObject[gadgets.util.escapeString(field)]
              = gadgets.util.escape(input[field], true);
        }
        return newObject;
      }
      return input;
    },

    /**
     * Escapes the input using html entities to make it safer.
     *
     * Currently not in the spec -- future proposals may change
     * how this is handled.
     *
     * TODO: Parsing the string would probably be more accurate and faster than
     * a bunch of regular expressions.
     *
     * @param {String} str The string to escape
     * @return {String} The escaped string
     */
    escapeString : function(str) {
      var out = [], ch, shouldEscape;
      for (var i = 0, j = str.length; i < j; ++i) {
        ch = str.charCodeAt(i);
        shouldEscape = escapeCodePoints[ch];
        if (shouldEscape === true) {
          out.push("&#", ch, ";");
        } else if (shouldEscape !== false) {
          // undefined or null are OK.
          out.push(str.charAt(i));
        }
      }
      return out.join("");
    },

    /**
     * Reverses escapeString
     *
     * @param {String} str The string to unescape.
     */
    unescapeString : function(str) {
      return str.replace(/&#([0-9]+);/g, unescapeEntity);
    }
  };
}();
// Initialize url parameters so that hash data is pulled in before it can be
// altered by a click.
gadgets.util.getUrlParameters();



/* FILE: core/json.js */
/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

/**
 * @fileoverview
 * The global object gadgets.json contains two methods.
 *
 * gadgets.json.stringify(value) takes a JavaScript value and produces a JSON
 * text. The value must not be cyclical.
 *
 * gadgets.json.parse(text) takes a JSON text and produces a JavaScript value.
 * It will return false if there is an error.
*/

var gadgets = gadgets || {};

/**
 * @static
 * @class Provides operations for translating objects to and from JSON.
 * @name gadgets.json
 */

/**
 * Port of the public domain JSON library by Douglas Crockford.
 * See: http://www.json.org/json2.js
 */
gadgets.json = function () {

  /**
   * Formats integers to 2 digits.
   * @param {Number} n
   */
  function f(n) {
    return n < 10 ? '0' + n : n;
  }

  Date.prototype.toJSON = function () {
    return [this.getUTCFullYear(), '-',
           f(this.getUTCMonth() + 1), '-',
           f(this.getUTCDate()), 'T',
           f(this.getUTCHours()), ':',
           f(this.getUTCMinutes()), ':',
           f(this.getUTCSeconds()), 'Z'].join("");
  };

  // table of character substitutions
  var m = {
    '\b': '\\b',
    '\t': '\\t',
    '\n': '\\n',
    '\f': '\\f',
    '\r': '\\r',
    '"' : '\\"',
    '\\': '\\\\'
  };

  /**
   * Converts a json object into a string.
   */
  function stringify(value) {
    var a,          // The array holding the partial texts.
        i,          // The loop counter.
        k,          // The member key.
        l,          // Length.
        r = /["\\\x00-\x1f\x7f-\x9f]/g,
        v;          // The member value.

    switch (typeof value) {
    case 'string':
    // If the string contains no control characters, no quote characters, and no
    // backslash characters, then we can safely slap some quotes around it.
    // Otherwise we must also replace the offending characters with safe ones.
      return r.test(value) ?
          '"' + value.replace(r, function (a) {
            var c = m[a];
            if (c) {
              return c;
            }
            c = a.charCodeAt();
            return '\\u00' + Math.floor(c / 16).toString(16) +
                (c % 16).toString(16);
            }) + '"'
          : '"' + value + '"';
    case 'number':
    // JSON numbers must be finite. Encode non-finite numbers as null.
      return isFinite(value) ? String(value) : 'null';
    case 'boolean':
    case 'null':
      return String(value);
    case 'object':
    // Due to a specification blunder in ECMAScript,
    // typeof null is 'object', so watch out for that case.
      if (!value) {
        return 'null';
      }
      // toJSON check removed; re-implement when it doesn't break other libs.
      a = [];
      if (typeof value.length === 'number' &&
          !(value.propertyIsEnumerable('length'))) {
        // The object is an array. Stringify every element. Use null as a
        // placeholder for non-JSON values.
        l = value.length;
        for (i = 0; i < l; i += 1) {
          a.push(stringify(value[i]) || 'null');
        }
        // Join all of the elements together and wrap them in brackets.
        return '[' + a.join(',') + ']';
      }
      // Otherwise, iterate through all of the keys in the object.
      for (k in value) if (value.hasOwnProperty(k)) {
        if (typeof k === 'string') {
          v = stringify(value[k]);
          if (v) {
            a.push(stringify(k) + ':' + v);
          }
        }
      }
      // Join all of the member texts together and wrap them in braces.
      return '{' + a.join(',') + '}';
    }
  }

  return {
    stringify: stringify,
    parse: function (text) {
// Parsing happens in three stages. In the first stage, we run the text against
// regular expressions that look for non-JSON patterns. We are especially
// concerned with '()' and 'new' because they can cause invocation, and '='
// because it can cause mutation. But just to be safe, we want to reject all
// unexpected forms.

// We split the first stage into 4 regexp operations in order to work around
// crippling inefficiencies in IE's and Safari's regexp engines. First we
// replace all backslash pairs with '@' (a non-JSON character). Second, we
// replace all simple value tokens with ']' characters. Third, we delete all
// open brackets that follow a colon or comma or that begin the text. Finally,
// we look to see that the remaining characters are only whitespace or ']' or
// ',' or ':' or '{' or '}'. If that is so, then the text is safe for eval.

      if (/^[\],:{}\s]*$/.test(text.replace(/\\["\\\/b-u]/g, '@').
          replace(/"[^"\\\n\r]*"|true|false|null|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?/g, ']').
          replace(/(?:^|:|,)(?:\s*\[)+/g, ''))) {
        return eval('(' + text + ')');
      }
      // If the text is not JSON parseable, then return false.

      return false;
    }
  };
}();



/* FILE: rpc/rpc.js */
/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements. See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership. The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License. You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 */

/**
 * @fileoverview Remote procedure call library for gadget-to-container,
 * container-to-gadget, and gadget-to-gadget communication.
 */

var gadgets = gadgets || {};

/**
 * @static
 * @class Provides operations for making rpc calls.
 * @name gadgets.rpc
 */
gadgets.rpc = function() {
  var services = {};
  var iframePool = [];
  var relayUrl = {};
  var useLegacyProtocol = {};
  var authToken = {};
  var callId = 0;
  var callbacks = {};

  var params = gadgets.util.getUrlParameters();
  authToken['..'] = params.rpctoken || params.ifpctok || 0;

  // Pick the most efficient RPC relay mechanism
  var relayChannel = typeof document.postMessage === 'function' ? 'dpm' :
                     typeof window.postMessage === 'function' ? 'wpm' :
                     'ifpc';
  if (relayChannel === 'dpm' || relayChannel === 'wpm') {
    document.addEventListener('message', function(packet) {
      // TODO validate packet.domain for security reasons
      process(gadgets.json.parse(packet.data));
    }, false);
  }

  // Default RPC handler
  services[''] = function() {
    throw new Error('Unknown RPC service: ' + this.s);
  };

  // Special RPC handler for callbacks
  services['__cb'] = function(callbackId, result) {
    var callback = callbacks[callbackId];
    if (callback) {
      delete callbacks[callbackId];
      callback(result);
    }
  };

  /**
   * Encodes arguments for the legacy IFPC wire format.
   *
   * @param {Object} args
   * @return {String} the encoded args
   */
  function encodeLegacyData(args) {
    var stringify = gadgets.json.stringify;
    var argsEscaped = [];
    for(var i = 0, j = args.length; i < j; ++i) {
      argsEscaped.push(encodeURIComponent(stringify(args[i])));
    }
    return argsEscaped.join('&');
  }

  /**
   * Helper function to process an RPC request
   * @param {Object} rpc RPC request object
   * @private
   */
  function process(rpc) {
    if (rpc && typeof rpc.s === 'string' && typeof rpc.f === 'string' &&
        rpc.a instanceof Array) {
      // Validate auth token.
      if (authToken[rpc.f]) {
        // We allow type coercion here because all the url params are strings.
        if (authToken[rpc.f] != rpc.t) {
          throw new Error("Invalid auth token.");
        }
      }

      // The Gecko engine used by FireFox etc. allows an IFrame to directly call
      // methods on the frameElement property added by the container page even
      // if their domains don't match.
      // Here we try to set up a relay channel using the frameElement technique
      // to greatly reduce the latency of cross-domain calls if the postMessage
      // method is not supported.
      if (relayChannel === 'ifpc') {
        if (rpc.f === '..') {
          // Container-to-gadget call
          try {
            var fel = window.frameElement;
            if (typeof fel.__g2c_rpc === 'function' &&
                typeof fel.__g2c_rpc.__c2g_rpc != 'function') {
              fel.__g2c_rpc.__c2g_rpc = function(args) {
                process(gadgets.json.parse(args));
              };
            }
          } catch (e) {
          }
        } else {
          // Gadget-to-container call
          var iframe = document.getElementById(rpc.f);
          if (iframe && typeof iframe.__g2c_rpc != 'function') {
            iframe.__g2c_rpc = function(args) {
              process(gadgets.json.parse(args));
            };
          }
        }
      }

      var result = (services[rpc.s] || services['']).apply(rpc, rpc.a);
      if (rpc.c) {
        gadgets.rpc.call(rpc.f, '__cb', null, rpc.c, result);
      }
    }
  }

  /**
   * Helper function to emit an invisible IFrame.
   * @param {String} src SRC attribute of the IFrame to emit.
   * @private
   */
  function emitInvisibleIframe(src) {
    var iframe;
    // Recycle IFrames
    for (var i = iframePool.length - 1; i >=0; --i) {
      var ifr = iframePool[i];
      try {
        if (ifr && (ifr.recyclable || ifr.readyState === 'complete')) {
          ifr.parentNode.removeChild(ifr);
          if (window.ActiveXObject) {
            // For MSIE, delete any iframes that are no longer being used. MSIE
            // cannot reuse the IFRAME because a navigational click sound will
            // be triggered when we set the SRC attribute.
            // Other browsers scan the pool for a free iframe to reuse.
            iframePool[i] = ifr = null;
            iframePool.splice(i, 1);
          } else {
            ifr.recyclable = false;
            iframe = ifr;
            break;
          }
        }
      } catch (e) {
        // Ignore; IE7 throws an exception when trying to read readyState and
        // readyState isn't set.
      }
    }
    // Create IFrame if necessary
    if (!iframe) {
      iframe = document.createElement('iframe');
      iframe.style.border = iframe.style.width = iframe.style.height = '0px';
      iframe.style.visibility = 'hidden';
      iframe.style.position = 'absolute';
      iframe.onload = function() { this.recyclable = true; };
      iframePool.push(iframe);
    }
    iframe.src = src;
    setTimeout(function() { document.body.appendChild(iframe); }, 0);
  }

  // gadgets.config might not be available, such as when serving container js.
  if (gadgets.config) {
    /**
     * Initializes RPC from the provided configuration.
     */
    function init(config) {
      // Allow for wild card parent relay files as long as it's from a
      // white listed domain. This is enforced by the rendering servlet.
      if (config.rpc.parentRelayUrl.substring(0, 7) === 'http://') {
        relayUrl['..'] = config.rpc.parentRelayUrl;
      } else {
        // It's a relative path, and we must append to the parent.
        // We're relying on the server validating the parent parameter in this
        // case. Because of this, parent may only be passed in the query, not
        // the fragment.
        var params = document.location.search.substring(0).split("&");
        var parentParam = "";
        for (var i = 0, param; param = params[i]; ++i) {
          // Only the first parent can be validated.
          if (param.indexOf("parent=") === 0) {
            parentParam = decodeURIComponent(param.substring(7));
            break;
          }
        }
        relayUrl['..'] = parentParam + config.rpc.parentRelayUrl;
      }
      useLegacyProtocol['..'] = !!config.rpc.useLegacyProtocol;
    }

    var requiredConfig = {
      parentRelayUrl : gadgets.config.NonEmptyStringValidator
    };
    gadgets.config.register("rpc", requiredConfig, init);
  }

  return /** @scope gadgets.rpc */ {
    /**
     * Registers an RPC service.
     * @param {String} serviceName Service name to register.
     * @param {Function} handler Service handler.
     *
     * @member gadgets.rpc
     */
    register: function(serviceName, handler) {
      services[serviceName] = handler;
    },

    /**
     * Unregisters an RPC service.
     * @param {String} serviceName Service name to unregister.
     *
     * @member gadgets.rpc
     */
    unregister: function(serviceName) {
      delete services[serviceName];
    },

    /**
     * Registers a default service handler to processes all unknown
     * RPC calls which raise an exception by default.
     * @param {Function} handler Service handler.
     *
     * @member gadgets.rpc
     */
    registerDefault: function(handler) {
      services[''] = handler;
    },

    /**
     * Unregisters the default service handler. Future unknown RPC
     * calls will fail silently.
     *
     * @member gadgets.rpc
     */
    unregisterDefault: function() {
      delete services[''];
    },

    /**
     * Calls an RPC service.
     * @param {String} targetId Module Id of the RPC service provider.
     *                          Empty if calling the parent container.
     * @param {String} serviceName Service name to call.
     * @param {Function|null} callback Callback function (if any) to process
     *                                 the return value of the RPC request.
     * @param {*} var_args Parameters for the RPC request.
     *
     * @member gadgets.rpc
     */
    call: function(targetId, serviceName, callback, var_args) {
      ++callId;
      targetId = targetId || '..';
      if (callback) {
        callbacks[callId] = callback;
      }
      var from;
      if (targetId === '..') {
        from = window.name;
      } else {
        from = '..';
      }
      // Not used by legacy, create it anyway...
      var rpcData = gadgets.json.stringify({
        s: serviceName,
        f: from,
        c: callback ? callId : 0,
        a: Array.prototype.slice.call(arguments, 3),
        t: authToken[targetId]
      });

      switch (relayChannel) {
      case 'dpm': // use document.postMessage
        var targetDoc = targetId === '..' ? parent.document :
                                            frames[targetId].document;
        targetDoc.postMessage(rpcData);
        break;
      case 'wpm': // use window.postMessage
        var targetWin = targetId === '..' ? parent : frames[targetId];
        targetWin.postMessage(rpcData);
        break;
      default: // use 'ifpc' as a fallback mechanism
        // Try the frameElement channel if available
        try {
          if (from === '..') {
            // Container-to-gadget
            var iframe = document.getElementById(targetId);
            if (typeof iframe.__g2c_rpc.__c2g_rpc === 'function') {
              iframe.__g2c_rpc.__c2g_rpc(rpcData);
              return;
            }
          } else {
            // Gadget-to-container
            if (typeof window.frameElement.__g2c_rpc === 'function') {
              window.frameElement.__g2c_rpc(rpcData);
              return;
            }
          }
        } catch (e) {
        }

        var relay = gadgets.rpc.getRelayUrl(targetId);

        // TODO split message if too long
        var src;
        if (useLegacyProtocol[targetId]) {
          // #iframe_id&callId&num_packets&packet_num&block_of_data
          src = [relay, '#', encodeLegacyData([from, callId, 1, 0,
                 encodeLegacyData([from, serviceName, '', '', from].concat(
                 Array.prototype.slice.call(arguments, 3)))])].join('');
        } else {
          // # targetId & sourceId@callId & packetNum & packetId & packetData
          src = [relay, '#', targetId, '&', from, '@', callId,
                 '&1&0&', encodeURIComponent(rpcData)].join('');
        }
        emitInvisibleIframe(src);
      }
    },

    /**
     * Gets the relay URL of a target frame.
     * @param {String} targetId Name of the target frame.
     * @return {String|undefined} Relay URL of the target frame.
     *
     * @member gadgets.rpc
     */
    getRelayUrl: function(targetId) {
      return relayUrl[targetId];
    },

    /**
     * Sets the relay URL of a target frame.
     * @param {String} targetId Name of the target frame.
     * @param {String} url Full relay URL of the target frame.
     * @param {Boolean} opt_useLegacy True if this relay needs the legacy IFPC
     *     wire format.
     *
     * @member gadgets.rpc
     */
    setRelayUrl: function(targetId, url, opt_useLegacy) {
      relayUrl[targetId] = url;
      useLegacyProtocol[targetId] = !!opt_useLegacy;
    },

    /**
     * Sets the auth token of a target frame.
     * @param {String} targetId Name of the target frame.
     * @param {String} token The authentication token to use for all
     *     calls to or from this target id.
     *
     * @member gadgets.rpc
     */
    setAuthToken: function(targetId, token) {
      authToken[targetId] = token;
    },

    /**
     * Gets the RPC relay mechanism.
     * @return {String} RPC relay mechanism. Supported types:
     *                  'wpm' - Use window.postMessage (defined by HTML5)
     *                  'dpm' - Use document.postMessage (defined by an early
     *                          draft of HTML5 and implemented by Opera)
     *                  'ifpc' - Use invisible IFrames
     *
     * @member gadgets.rpc
     */
    getRelayChannel: function() {
      return relayChannel;
    },

    /**
     * Receives and processes an RPC request. (Not to be used directly.)
     * @param {Array.<String>} fragment An RPC request fragment encoded as
     *        an array. The first 4 elements are target id, source id & call id,
     *        total packet number, packet id. The last element stores the actual
     *        JSON-encoded and URI escaped packet data.
     *
     * @member gadgets.rpc
     */
    receive: function(fragment) {
      if (fragment.length > 4) {
        // TODO parse fragment[1..3] to merge multi-fragment messages
        process(gadgets.json.parse(
            decodeURIComponent(fragment[fragment.length - 1])));
      }
    }
  };
}();



/* FILE: ifpc/ifpc.js */
/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements. See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership. The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License. You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 */

var gadgets = gadgets || {};

/**
 * IFrame pool
 */
gadgets.IFramePool_ = function() {
  this.pool_ = [];
};

/**
 * Returns a newly created IFRAME with the locked state as specified
 * @param {Boolean} locked whether the created IFRAME is locked by default
 * @returns {HTMLElement} the created IFRAME element
 * @private
 */
gadgets.IFramePool_.prototype.createIFrame_ = function(locked) {
  var div = document.createElement("DIV");

  // MSIE will reliably trigger an IFRAME onload event if the onload is defined
  // inlined but not if it is defined via JS with element.onload = func;
  // We create it within a DIV but eventually is moved directly into doc.body.
  div.innerHTML = "<iframe onload='this.pool_locked=false'></iframe>";

  var iframe = div.getElementsByTagName("IFRAME")[0];
  iframe.style.visibility = 'hidden';
  iframe.style.width = iframe.style.height = '0px';
  iframe.style.border = '0px';
  iframe.style.position = 'absolute';

  iframe.pool_locked = locked;
  this.pool_[this.pool_.length] = iframe;

  // The div was only used to create the iframe. Now we disown and remove it.
  div.removeChild(iframe);
  div = null;
  return iframe;
};

/**
 * Retrieves an available IFrame and sets the URL to 'url'
 * @param {String} url The URL the IFrame is pointed to
 */
gadgets.IFramePool_.prototype.iframe = function(url) {
  // Reject weird urls
  if (!url.match(/^http[s]?:\/\//)) {
    return;
  }
  // We wrap this code in a setTimeout call to avoid tying the UI up too much
  // with a series of repeated IFRAME creation calls.

  var ifp = this;
  window.setTimeout(function() {
    var iframe = null;

    // For MSIE, delete any iframes that are no longer being used. MSIE cannnot
    // re-use the IFRAME because it will 'click' when we set the SRC.
    // Other browsers scan the pool for a free iframe to re-use.
    for (var i = ifp.pool_.length - 1; i >= 0; i--) {
      var ifr = ifp.pool_[i];
      if (ifr && !ifr.pool_locked) {
        ifr.parentNode.removeChild(ifr);
        if (window.ActiveXObject) {  // MSIE
          ifr = null;
          ifp.pool_[i] = null;
          ifp.pool_.splice(i,1);  // Remove it from the array
        } else {
          ifr.pool_locked = true;
          iframe = ifr;
          break;
        }
      }
    }

    // If no iframe was found to re-use we create a new one
    iframe = iframe ? iframe : ifp.createIFrame_(true);
    iframe.src = url;

    // We append to the body after setting the src otherwise MSIE will 'click'
    document.body.appendChild(iframe);
  }, 0);
};

/**
 * Clears the pool and re-initializes it to empty
 */
gadgets.IFramePool_.prototype.clear = function() {
  for (var i = 0; i < this.pool_.length; i++) {
    this.pool_[i].onload = null;
    this.pool_[i] = null;
  }
  this.pool_.length = 0;
  this.pool_ = new Array();
};

/**
 * Inter-frame procedure call
 */
gadgets.ifpc_ = function() {

  var CALLBACK_ID_PREFIX_ = "cbid";
  var CALLBACK_SERVICE_NAME_ = "ifpc_callback";
  var iframePool_ = new gadgets.IFramePool_();
  var packetStore_ = {};
  var services_ = {};
  var callbacks_ = {};
  var callbackCounter_ = 0;
  var callCounter_ = 0;

  /**
   * Registers a new service and associates it with 'handler'
   * @param {String} name the id to used to identify this service when calling
   * @param {Function} handler function to handle incoming requests
   */
  function registerService(name, handler) {
    services_[name] = handler;
  }

  /**
   * Unregisters a registered service
   * @param {String} name the id used to identify the service when calling
   */
  function unregisterService(name) {
    delete services_[name];
  }

  /**
   * dispatches the call
   * @param {String} iframe_id iframe ID to use for this request
   * @param {String} service_name service name
   * @param {Array} args_list array of arguments expected by this service
   * @param {String} remote_relay_url remote relay URL of the relay HTML page
   * @param {Function} callback callback function if a response is expected
   *        (can be null if no callback expected)
   * @param {String} local_relay_url local relay URL of the relay HTML page
   *        (can be null if callback is also null)
   */
  function call(iframe_id,
      service_name,
      args_list,
      remote_relay_url,
      callback,
      local_relay_url,
      opt_shouldThrowError) {
    // We prepend some other arguments that the processRequest
    // method is expecting and will shift off in reverse order
    // once all the packets have been received
    // First make a local copy of args_list
    args_list = args_list.slice(0);
    args_list.unshift(registerCallback_(callback));
    args_list.unshift(local_relay_url);
    args_list.unshift(service_name);
    args_list.unshift(iframe_id);

    // Figure out how much URL space is available for actual data.
    // MSIE puts a limit of 4095 total chars including the # data.
    // Other browsers have limits at least as large as 4095.
    var max_data_len = 4095 - remote_relay_url.length;
    // Because we encodeArgs twice we need to leave room for escape chars
    max_data_len = parseInt(max_data_len / 3, 10);

    if (typeof opt_shouldThrowError == "undefined") {
      opt_shouldThrowError = true;
    }

    // Format of each packet is:
    // #iframe_id&callId&num_packets&packet_num&block_of_data
    var data = encodeArgs_(args_list);
    var num_packets = parseInt(data.length / max_data_len, 10);
    if (data.length % max_data_len > 0) {
      num_packets += 1;
    }
    for (var i = 0; i < num_packets; i++) {
      var data_slice = data.substr(i*max_data_len, max_data_len);
      var packet = [iframe_id, callCounter_, num_packets, i,
          data_slice, opt_shouldThrowError];
      iframePool_.iframe(
          remote_relay_url + "#" + encodeArgs_(packet));
    }
    callCounter_++;
  }

  /**
   * Clears internal state.
   * Should be called from an unload handler to avoid memory leaks.
   */
  function clear() {
    services_ = {};
    callbacks_ = {};
    iframePool_.clear();
  }

  /**
   * Relays a request either from container to gadget, from gadget to container,
   * or from gadget to gadget.
   * @param {String} argsString encoded parameters
   */
  function relayRequest(argsString) {
    // Extract the iframe-id.
    var iframeId = decodeArgs_(argsString)[0];
    // Need to find the destination window to pass the request on to.
    // We are in an IFPC relay iframe within the source window.
    var win = null;
    // If container-to-gadget communication, the window corresponding to
    // 'iframeId' will be our sibling, ie. a child of the container page,
    // and this child is the window we need.
    try {
      win = window.parent.frames[iframeId];
    } catch (e) {
      // Doesn't look like container-to-gadget communication.
      // Just leave 'win' unset.
    }
    // If gadget-to-gadget communication, the window corresponding to
    // 'iframeId' will be a sibling of our outer page, and this is the
    // window we need.
    try {
      if (!win && window.parent.parent.frames[iframeId] != window.parent) {
        win = window.parent.parent.frames[iframeId];
      }
    } catch (e) {
      // Doesn't look like gadget-to-gadget communication.
      // Just leave 'win' unset.
    }
    if (!win) {
      // Wasn't container-to-gadget nor gadget-to-gadget communication.
      // If gadget-to-container communication, 'iframeId' will be our grandparent.
      win = window.parent.parent;
    }
    // Now that 'win' is set appropriately, pass on the request.
    // Obscure Firefox bug sometimes causes an exception when xmlhttp is
    // utilized in an IFPC handler. Wrapping our handleRequest calls
    // with a setTimeout in the target window's scope prevents this
    // exception.
    // See this Mozilla bug for more info:
    // https://bugzilla.mozilla.org/show_bug.cgi?id=249843
    // Also see this blogged account of the bug:
    // http://the-stickman.com/web-development/javascript/iframes-xmlhttprequest-bug-in-firefox
    var fn = function() {
      win.gadgets.ifpc_.handleRequest(argsString);
    };

    if (window.ActiveXObject) { // MSIE
      // call the relay synchronously in IE
      // this is required because the iframe (and its relay closure)
      // may otherwise be deleted/invalidated before this call is made
      fn();
    } else {
      // all other browsers call with timeout, particularly FF. See
      // above comment regarding FF bug for why it's done this way
      win.setTimeout(fn, 0);
    }
  }

  /**
   * Internal function that processes the request
   * @param {String} packet encoded parameters
   */
  function handleRequest(packet) {
    packet = decodeArgs_(packet);

    var iframeId = packet.shift();
    var callId = packet.shift();
    var numPackets = packet.shift();
    var packetNum = packet.shift();
    var data = packet.shift();
    var shouldThrowError = packet.shift();
    // If you see fit to add a parameter here, don't.
    // If you must, be sure to add it to the END of the list!
    // If you don't, lots of problems will occur in situations where
    // IFPC versions mismatch, because ordered arguments will no longer
    // match up, causing all manner of breakages and odd behavior.

    // We store incoming packets in the packet_store object.
    // The key is the iframeId + the unique callId.
    // The value is an array to hold all the packets for the request.
    // The elements in the array are a 2-element array: packetNum and data.
    // When all packets are received, we sort based on the packetNum and then
    // re-create the original data block before passing to the Service Handler.
    var key = iframeId + "_" + callId;
    if (!packetStore_[key]) packetStore_[key] = [];
    packetStore_[key].push([packetNum, data]);

    if (packetStore_[key].length == numPackets) {
      // All packets have been received
      packetStore_[key].sort(function(a,b){
          return parseInt(a[0], 10) - parseInt(b[0], 10);
          });

      data = "";
      for (var i = 0; i < numPackets; i++) {
        data += packetStore_[key][i][1];
      }
      // Clear this entry from the packet_store
      packetStore_[key] = null;

      var args = decodeArgs_(data);

      iframeId = args.shift();
      var serviceName = args.shift();
      var remote_relay_url = args.shift();
      var callbackId = args.shift();

      var handler = getServiceHandler_(serviceName);
      if (handler) {
        var args_list_result = handler.apply(null, args);
        if (isCallbackIdWellFormed_(callbackId)) {
          args_list_result.unshift(callbackId);
          call(iframeId,
              CALLBACK_SERVICE_NAME_,
              args_list_result,
              remote_relay_url,
              null,   // no callback from the callback
              "");    // no callback, no relay needed
        }
      } else if (shouldThrowError) {
        throw new Error("Service " + serviceName + " not registered.");
      }
    }
  }

  /**
   * Returns the service handler given a specific service name
   * @param {String} name service name
   * @returns {Function} service
   * @private
   */
  function getServiceHandler_(name) {
    if(services_.hasOwnProperty(name)) {
      return services_[name];
    } else {
      return null;
    }
  }

  /**
   * Registers a new callback
   * @param {Function} callback callback function
   * @returns {String} a callback ID to use with call()
   * @private
   */
  function registerCallback_(callback) {
    var callbackId = "";
    if (callback && typeof callback == "function") {
      callbackId = getNewCallbackId_();
      callbacks_[callbackId] = callback;
    }
    return callbackId;
  }

  /**
   * Unregisters an existing callback
   * @param {String} callback_id callback ID
   * @private
   */
  function unregisterCallback_(callback_id) {
    if (callbacks_.hasOwnProperty(callback_id)) {
      callbacks_[callback_id] = null;
    }
  }

  /**
   * Returns the callback given a specific callback id
   * @param {String} callback_id callback ID
   * @returns {Function|null} callback function
   * @private
   */
  function getCallback_(callback_id) {
    if (callback_id &&
        callbacks_.hasOwnProperty(callback_id)) {
      return callbacks_[callback_id];
    }
    return null;
  }

  /**
   * Gets a new callback ID
   * @returns {String} a callback ID string
   * @private
   */
  function getNewCallbackId_() {
    return CALLBACK_ID_PREFIX_ + (callbackCounter_++);
  }

  /**
   * Return the decoded arguments a a list. First element is the service name.
   * @param {String} argsString Encoded argument string
   * @returns {Array} decoded argument list
   * @private
   */
  function decodeArgs_(argsString) {
    var args = argsString.split('&');
    for(var i = 0; i < args.length; i++) {
      var arg = decodeURIComponent(args[i]);
      try {
        arg = gadgets.json.parse(arg);
      } catch (e) {
        // unexpected, but ok - treat as a string
      }
      args[i] = arg;
    }
    return args;
  }

  /**
   * Determines whether a callbackId is well-formed.
   * @param {String} callbackId callback ID
   * @returns {Boolean} whether the callbackId is well-formed
   * @private
   */
  function isCallbackIdWellFormed_(callbackId) {
    return (callbackId+"").indexOf(CALLBACK_ID_PREFIX_) === 0;
  }

  /**
   * Private handler for the built-in callback service
   * @param {String} callbackId callback ID
   * @private
   */
  function callbackServiceHandler_(callbackId) {
    var callback = getCallback_(callbackId);
    if (callback) {
      var args = [];
      for (var i = 1; i < arguments.length; i++) {
        args[args.length] = arguments[i];  // append the extra arguments
      }
      callback.apply(null, args);

      // Once the callback is triggered, we remove it.
      unregisterCallback_(callbackId);
    } else {
      throw new Error("Invalid callbackId");
    }
  }

  /**
   * Return the encoded argument string.
   * @param {Array} args list of arguments to encode
   * @returns {String} encoded argument string
   * @private
   */
  function encodeArgs_(args) {
    var argsEscaped = [];
    for(var i = 0; i < args.length; i++) {
      var arg = gadgets.json.stringify(args[i]);
      argsEscaped.push(encodeURIComponent(arg));
    }
    return argsEscaped.join('&');
  }

  // Register the built-in callback handler
  registerService(CALLBACK_SERVICE_NAME_, callbackServiceHandler_);

  // Public methods
  return {
    registerService: registerService,
    unregisterService: unregisterService,
    call: call,
    clear: clear,
    relayRequest: relayRequest,
    processRequest: relayRequest,
    handleRequest: handleRequest
  };

}();

// Alias for legacy code
var _IFPC = gadgets.ifpc_;



/* FILE: socialtext/jquery-1.2.2.pack.js */
/*
 * jQuery 1.2.2 - New Wave Javascript
 *
 * Copyright (c) 2007 John Resig (jquery.com)
 * Dual licensed under the MIT (MIT-LICENSE.txt)
 * and GPL (GPL-LICENSE.txt) licenses.
 *
 * $Date: 2008-01-14 17:56:07 -0500 (Mon, 14 Jan 2008) $
 * $Rev: 4454 $
 */
eval(function(p,a,c,k,e,r){e=function(c){return(c<a?'':e(parseInt(c/a)))+((c=c%a)>35?String.fromCharCode(c+29):c.toString(36))};if(!''.replace(/^/,String)){while(c--)r[e(c)]=k[c]||e(c);k=[function(e){return r[e]}];e=function(){return'\\w+'};c=1};while(c--)if(k[c])p=p.replace(new RegExp('\\b'+e(c)+'\\b','g'),k[c]);return p}('(J(){7(1e.19)L w=1e.19;L E=1e.19=J(a,b){K 1D E.2m.4Y(a,b)};7(1e.$)L D=1e.$;1e.$=E;L u=/^[^<]*(<(.|\\s)+>)[^>]*$|^#(\\w+)$/;L G=/^.[^:#\\[\\.]*$/;E.1i=E.2m={4Y:J(d,b){d=d||T;7(d.15){6[0]=d;6.M=1;K 6}N 7(1v d=="25"){L c=u.39(d);7(c&&(c[1]||!b)){7(c[1])d=E.5c([c[1]],b);N{L a=T.5N(c[3]);7(a)7(a.2s!=c[3])K E().2r(d);N{6[0]=a;6.M=1;K 6}N d=[]}}N K 1D E(b).2r(d)}N 7(E.1q(d))K 1D E(T)[E.1i.21?"21":"43"](d);K 6.6G(d.1n==1N&&d||(d.5j||d.M&&d!=1e&&!d.15&&d[0]!=10&&d[0].15)&&E.2H(d)||[d])},5j:"1.2.2",82:J(){K 6.M},M:0,22:J(a){K a==10?E.2H(6):6[a]},2E:J(b){L a=E(b);a.56=6;K a},6G:J(a){6.M=0;1N.2m.1h.1j(6,a);K 6},V:J(a,b){K E.V(6,a,b)},5E:J(b){L a=-1;6.V(J(i){7(6==b)a=i});K a},1K:J(c,a,b){L d=c;7(c.1n==4d)7(a==10)K 6.M&&E[b||"1K"](6[0],c)||10;N{d={};d[c]=a}K 6.V(J(i){P(c 1r d)E.1K(b?6.Y:6,c,E.1l(6,d[c],b,i,c))})},1m:J(b,a){7((b==\'29\'||b==\'1P\')&&2M(a)<0)a=10;K 6.1K(b,a,"2q")},1t:J(b){7(1v b!="4D"&&b!=W)K 6.4B().3t((6[0]&&6[0].2u||T).5v(b));L a="";E.V(b||6,J(){E.V(6.3p,J(){7(6.15!=8)a+=6.15!=1?6.6M:E.1i.1t([6])})});K a},5r:J(b){7(6[0])E(b,6[0].2u).5J().3n(6[0]).2a(J(){L a=6;2e(a.1B)a=a.1B;K a}).3t(6);K 6},8t:J(a){K 6.V(J(){E(6).6C().5r(a)})},8m:J(a){K 6.V(J(){E(6).5r(a)})},3t:J(){K 6.3P(1a,R,S,J(a){7(6.15==1)6.3k(a)})},6s:J(){K 6.3P(1a,R,R,J(a){7(6.15==1)6.3n(a,6.1B)})},6o:J(){K 6.3P(1a,S,S,J(a){6.1b.3n(a,6)})},5a:J(){K 6.3P(1a,S,R,J(a){6.1b.3n(a,6.2J)})},3h:J(){K 6.56||E([])},2r:J(b){L c=E.2a(6,J(a){K E.2r(b,a)});K 6.2E(/[^+>] [^+>]/.17(b)||b.1g("..")>-1?E.57(c):c)},5J:J(e){L f=6.2a(J(){7(E.14.1d&&!E.3W(6)){L a=6.6c(R),5u=T.2R("1u"),4T=T.2R("1u");5u.3k(a);4T.38=5u.38;K 4T.1B}N K 6.6c(R)});L d=f.2r("*").4R().V(J(){7(6[F]!=10)6[F]=W});7(e===R)6.2r("*").4R().V(J(i){7(6.15==3)K;L c=E.Q(6,"2N");P(L a 1r c)P(L b 1r c[a])E.16.1c(d[i],a,c[a][b],c[a][b].Q)});K f},1F:J(b){K 6.2E(E.1q(b)&&E.3x(6,J(a,i){K b.1O(a,i)})||E.3d(b,6))},4I:J(b){7(b.1n==4d)7(G.17(b))K 6.2E(E.3d(b,6,R));N b=E.3d(b,6);L a=b.M&&b[b.M-1]!==10&&!b.15;K 6.1F(J(){K a?E.35(6,b)<0:6!=b})},1c:J(a){K!a?6:6.2E(E.34(6.22(),a.1n==4d?E(a).22():a.M!=10&&(!a.12||E.12(a,"3i"))?a:[a]))},3K:J(a){K a?E.3d(a,6).M>0:S},7g:J(a){K 6.3K("."+a)},5P:J(b){7(b==10){7(6.M){L c=6[0];7(E.12(c,"2y")){L e=c.44,5L=[],11=c.11,30=c.U=="2y-30";7(e<0)K W;P(L i=30?e:0,2b=30?e+1:11.M;i<2b;i++){L d=11[i];7(d.2p){b=E.14.1d&&!d.9s.1C.9o?d.1t:d.1C;7(30)K b;5L.1h(b)}}K 5L}N K(6[0].1C||"").1p(/\\r/g,"")}K 10}K 6.V(J(){7(6.15!=1)K;7(b.1n==1N&&/5w|5y/.17(6.U))6.3o=(E.35(6.1C,b)>=0||E.35(6.37,b)>=0);N 7(E.12(6,"2y")){L a=b.1n==1N?b:[b];E("90",6).V(J(){6.2p=(E.35(6.1C,a)>=0||E.35(6.1t,a)>=0)});7(!a.M)6.44=-1}N 6.1C=b})},3q:J(a){K a==10?(6.M?6[0].38:W):6.4B().3t(a)},6P:J(a){K 6.5a(a).1Y()},6N:J(i){K 6.2V(i,i+1)},2V:J(){K 6.2E(1N.2m.2V.1j(6,1a))},2a:J(b){K 6.2E(E.2a(6,J(a,i){K b.1O(a,i,a)}))},4R:J(){K 6.1c(6.56)},3P:J(g,f,h,d){L e=6.M>1,3m;K 6.V(J(){7(!3m){3m=E.5c(g,6.2u);7(h)3m.8I()}L b=6;7(f&&E.12(6,"1V")&&E.12(3m[0],"4x"))b=6.3V("1S")[0]||6.3k(6.2u.2R("1S"));L c=E([]);E.V(3m,J(){L a=e?E(6).5J(R)[0]:6;7(E.12(a,"1o")){c=c.1c(a)}N{7(a.15==1)c=c.1c(E("1o",a).1Y());d.1O(b,a)}});c.V(6D)})}};E.2m.4Y.2m=E.2m;J 6D(i,a){7(a.3R)E.3Q({1f:a.3R,3l:S,1G:"1o"});N E.5l(a.1t||a.6A||a.38||"");7(a.1b)a.1b.2X(a)}E.1s=E.1i.1s=J(){L b=1a[0]||{},i=1,M=1a.M,5i=S,11;7(b.1n==8f){5i=b;b=1a[1]||{};i=2}7(1v b!="4D"&&1v b!="J")b={};7(M==1){b=6;i=0}P(;i<M;i++)7((11=1a[i])!=W)P(L a 1r 11){7(b===11[a])6z;7(5i&&11[a]&&1v 11[a]=="4D"&&b[a]&&!11[a].15)b[a]=E.1s(b[a],11[a]);N 7(11[a]!=10)b[a]=11[a]}K b};L F="19"+(1D 3O()).3N(),6y=0,5e={};L H=/z-?5E|89-?87|1y|6q|85-?1P/i;E.1s({81:J(a){1e.$=D;7(a)1e.19=w;K E},1q:J(a){K!!a&&1v a!="25"&&!a.12&&a.1n!=1N&&/J/i.17(a+"")},3W:J(a){K a.1I&&!a.1k||a.28&&a.2u&&!a.2u.1k},5l:J(a){a=E.3f(a);7(a){L b=T.3V("6k")[0]||T.1I,1o=T.2R("1o");1o.U="1t/4l";7(E.14.1d)1o.1t=a;N 1o.3k(T.5v(a));b.3k(1o);b.2X(1o)}},12:J(b,a){K b.12&&b.12.2F()==a.2F()},1Q:{},Q:J(c,d,b){c=c==1e?5e:c;L a=c[F];7(!a)a=c[F]=++6y;7(d&&!E.1Q[a])E.1Q[a]={};7(b!=10)E.1Q[a][d]=b;K d?E.1Q[a][d]:a},3H:J(c,b){c=c==1e?5e:c;L a=c[F];7(b){7(E.1Q[a]){2T E.1Q[a][b];b="";P(b 1r E.1Q[a])1T;7(!b)E.3H(c)}}N{1R{2T c[F]}1W(e){7(c.55)c.55(F)}2T E.1Q[a]}},V:J(c,a,b){7(b){7(c.M==10){P(L d 1r c)7(a.1j(c[d],b)===S)1T}N P(L i=0,M=c.M;i<M;i++)7(a.1j(c[i],b)===S)1T}N{7(c.M==10){P(L d 1r c)7(a.1O(c[d],d,c[d])===S)1T}N P(L i=0,M=c.M,1C=c[0];i<M&&a.1O(1C,i,1C)!==S;1C=c[++i]){}}K c},1l:J(b,a,c,i,d){7(E.1q(a))a=a.1O(b,i);K a&&a.1n==53&&c=="2q"&&!H.17(d)?a+"2P":a},1w:{1c:J(c,b){E.V((b||"").2d(/\\s+/),J(i,a){7(c.15==1&&!E.1w.3E(c.1w,a))c.1w+=(c.1w?" ":"")+a})},1Y:J(c,b){7(c.15==1)c.1w=b!=10?E.3x(c.1w.2d(/\\s+/),J(a){K!E.1w.3E(b,a)}).6g(" "):""},3E:J(b,a){K E.35(a,(b.1w||b).3D().2d(/\\s+/))>-1}},6e:J(b,c,a){L e={};P(L d 1r c){e[d]=b.Y[d];b.Y[d]=c[d]}a.1O(b);P(L d 1r c)b.Y[d]=e[d]},1m:J(d,e,c){7(e=="29"||e=="1P"){L b,3S={3C:"4Z",4X:"23",18:"3u"},3r=e=="29"?["7P","7M"]:["7L","7K"];J 4S(){b=e=="29"?d.7J:d.7I;L a=0,3a=0;E.V(3r,J(){a+=2M(E.2q(d,"7H"+6,R))||0;3a+=2M(E.2q(d,"3a"+6+"62",R))||0});b-=1Z.7E(a+3a)}7(E(d).3K(":4b"))4S();N E.6e(d,3S,4S);K 1Z.2b(0,b)}K E.2q(d,e,c)},2q:J(e,k,j){L d;J 3y(b){7(!E.14.26)K S;L a=T.4a.4L(b,W);K!a||a.4K("3y")==""}7(k=="1y"&&E.14.1d){d=E.1K(e.Y,"1y");K d==""?"1":d}7(E.14.2B&&k=="18"){L c=e.Y.18;e.Y.18="3u";e.Y.18=c}7(k.1E(/4c/i))k=y;7(!j&&e.Y&&e.Y[k])d=e.Y[k];N 7(T.4a&&T.4a.4L){7(k.1E(/4c/i))k="4c";k=k.1p(/([A-Z])/g,"-$1").2w();L h=T.4a.4L(e,W);7(h&&!3y(e))d=h.4K(k);N{L f=[],2L=[];P(L a=e;a&&3y(a);a=a.1b)2L.4U(a);P(L i=0;i<2L.M;i++)7(3y(2L[i])){f[i]=2L[i].Y.18;2L[i].Y.18="3u"}d=k=="18"&&f[2L.M-1]!=W?"2D":(h&&h.4K(k))||"";P(L i=0;i<f.M;i++)7(f[i]!=W)2L[i].Y.18=f[i]}7(k=="1y"&&d=="")d="1"}N 7(e.4j){L g=k.1p(/\\-(\\w)/g,J(a,b){K b.2F()});d=e.4j[k]||e.4j[g];7(!/^\\d+(2P)?$/i.17(d)&&/^\\d/.17(d)){L l=e.Y.2c,3A=e.3A.2c;e.3A.2c=e.4j.2c;e.Y.2c=d||0;d=e.Y.7l+"2P";e.Y.2c=l;e.3A.2c=3A}}K d},5c:J(l,h){L k=[];h=h||T;7(1v h.2R==\'10\')h=h.2u||h[0]&&h[0].2u||T;E.V(l,J(i,d){7(!d)K;7(d.1n==53)d=d.3D();7(1v d=="25"){d=d.1p(/(<(\\w+)[^>]*?)\\/>/g,J(b,a,c){K c.1E(/^(7k|7h|5Q|7f|48|5O|a3|3v|9Y|9W|9T)$/i)?b:a+"></"+c+">"});L f=E.3f(d).2w(),1u=h.2R("1u");L e=!f.1g("<9R")&&[1,"<2y 78=\'78\'>","</2y>"]||!f.1g("<9O")&&[1,"<77>","</77>"]||f.1E(/^<(9K|1S|9I|9F|9A)/)&&[1,"<1V>","</1V>"]||!f.1g("<4x")&&[2,"<1V><1S>","</1S></1V>"]||(!f.1g("<9y")||!f.1g("<9v"))&&[3,"<1V><1S><4x>","</4x></1S></1V>"]||!f.1g("<5Q")&&[2,"<1V><1S></1S><76>","</76></1V>"]||E.14.1d&&[1,"1u<1u>","</1u>"]||[0,"",""];1u.38=e[1]+d+e[2];2e(e[0]--)1u=1u.5D;7(E.14.1d){L g=!f.1g("<1V")&&f.1g("<1S")<0?1u.1B&&1u.1B.3p:e[1]=="<1V>"&&f.1g("<1S")<0?1u.3p:[];P(L j=g.M-1;j>=0;--j)7(E.12(g[j],"1S")&&!g[j].3p.M)g[j].1b.2X(g[j]);7(/^\\s/.17(d))1u.3n(h.5v(d.1E(/^\\s*/)[0]),1u.1B)}d=E.2H(1u.3p)}7(d.M===0&&(!E.12(d,"3i")&&!E.12(d,"2y")))K;7(d[0]==10||E.12(d,"3i")||d.11)k.1h(d);N k=E.34(k,d)});K k},1K:J(d,e,c){7(!d||d.15==3||d.15==8)K 10;L f=E.3W(d)?{}:E.3S;7(e=="2p"&&E.14.26)d.1b.44;7(f[e]){7(c!=10)d[f[e]]=c;K d[f[e]]}N 7(E.14.1d&&e=="Y")K E.1K(d.Y,"9r",c);N 7(c==10&&E.14.1d&&E.12(d,"3i")&&(e=="9q"||e=="9p"))K d.9n(e).6M;N 7(d.28){7(c!=10){7(e=="U"&&E.12(d,"48")&&d.1b)6Z"U 9i 9g\'t 9b 9a";d.99(e,""+c)}7(E.14.1d&&/6T|3R/.17(e)&&!E.3W(d))K d.4z(e,2);K d.4z(e)}N{7(e=="1y"&&E.14.1d){7(c!=10){d.6q=1;d.1F=(d.1F||"").1p(/6W\\([^)]*\\)/,"")+(2M(c).3D()=="93"?"":"6W(1y="+c*6S+")")}K d.1F&&d.1F.1g("1y=")>=0?(2M(d.1F.1E(/1y=([^)]*)/)[1])/6S).3D():""}e=e.1p(/-([a-z])/92,J(a,b){K b.2F()});7(c!=10)d[e]=c;K d[e]}},3f:J(a){K(a||"").1p(/^\\s+|\\s+$/g,"")},2H:J(b){L a=[];7(1v b!="91")P(L i=0,M=b.M;i<M;i++)a.1h(b[i]);N a=b.2V(0);K a},35:J(b,a){P(L i=0,M=a.M;i<M;i++)7(a[i]==b)K i;K-1},34:J(a,b){7(E.14.1d){P(L i=0;b[i];i++)7(b[i].15!=8)a.1h(b[i])}N P(L i=0;b[i];i++)a.1h(b[i]);K a},57:J(a){L c=[],2j={};1R{P(L i=0,M=a.M;i<M;i++){L b=E.Q(a[i]);7(!2j[b]){2j[b]=R;c.1h(a[i])}}}1W(e){c=a}K c},3x:J(c,a,d){7(1v a=="25")a=4A("S||J(a,i){K "+a+"}");L b=[];P(L i=0,M=c.M;i<M;i++)7(!d&&a(c[i],i)||d&&!a(c[i],i))b.1h(c[i]);K b},2a:J(d,a){L c=[];P(L i=0,M=d.M;i<M;i++){L b=a(d[i],i);7(b!==W&&b!=10){7(b.1n!=1N)b=[b];c=c.6Q(b)}}K c}});L v=8X.8V.2w();E.14={5n:(v.1E(/.+(?:8R|8Q|8P|8O)[\\/: ]([\\d.]+)/)||[])[1],26:/6L/.17(v),2B:/2B/.17(v),1d:/1d/.17(v)&&!/2B/.17(v),3X:/3X/.17(v)&&!/(8M|6L)/.17(v)};L y=E.14.1d?"6K":"6J";E.1s({8J:!E.14.1d||T.6I=="6H",3S:{"P":"8G","8E":"1w","4c":y,6J:y,6K:y,38:"38",1w:"1w",1C:"1C",2W:"2W",3o:"3o",8C:"8B",2p:"2p",8A:"8z",44:"44",6F:"6F",28:"28",12:"12"}});E.V({6E:"O.1b",8y:"19.4w(O,\'1b\')",8x:"19.31(O,2,\'2J\')",8w:"19.31(O,2,\'4v\')",8v:"19.4w(O,\'2J\')",8u:"19.4w(O,\'4v\')",8s:"19.5m(O.1b.1B,O)",8r:"19.5m(O.1B)",6C:"19.12(O,\'8q\')?O.8p||O.8o.T:19.2H(O.3p)"},J(c,d){d=4A("S||J(O){K "+d+"}");E.1i[c]=J(b){L a=E.2a(6,d);7(b&&1v b=="25")a=E.3d(b,a);K 6.2E(E.57(a))}});E.V({6B:"3t",8n:"6s",3n:"6o",8l:"5a",8k:"6P"},J(c,b){E.1i[c]=J(){L a=1a;K 6.V(J(){P(L i=0,M=a.M;i<M;i++)E(a[i])[b](6)})}});E.V({8j:J(a){E.1K(6,a,"");7(6.15==1)6.55(a)},8i:J(a){E.1w.1c(6,a)},8h:J(a){E.1w.1Y(6,a)},8g:J(a){E.1w[E.1w.3E(6,a)?"1Y":"1c"](6,a)},1Y:J(a){7(!a||E.1F(a,[6]).r.M){E("*",6).1c(6).V(J(){E.16.1Y(6);E.3H(6)});7(6.1b)6.1b.2X(6)}},4B:J(){E(">*",6).1Y();2e(6.1B)6.2X(6.1B)}},J(a,b){E.1i[a]=J(){K 6.V(b,1a)}});E.V(["8e","62"],J(i,c){L b=c.2w();E.1i[b]=J(a){K 6[0]==1e?E.14.2B&&T.1k["5h"+c]||E.14.26&&1e["8d"+c]||T.6I=="6H"&&T.1I["5h"+c]||T.1k["5h"+c]:6[0]==T?1Z.2b(1Z.2b(T.1k["5g"+c],T.1I["5g"+c]),1Z.2b(T.1k["5f"+c],T.1I["5f"+c])):a==10?(6.M?E.1m(6[0],b):W):6.1m(b,a.1n==4d?a:a+"2P")}});L C=E.14.26&&4t(E.14.5n)<8c?"(?:[\\\\w*4s-]|\\\\\\\\.)":"(?:[\\\\w\\8b-\\8a*4s-]|\\\\\\\\.)",6w=1D 4r("^>\\\\s*("+C+"+)"),6v=1D 4r("^("+C+"+)(#)("+C+"+)"),6u=1D 4r("^([#.]?)("+C+"*)");E.1s({5d:{"":"m[2]==\'*\'||19.12(a,m[2])","#":"a.4z(\'2s\')==m[2]",":":{88:"i<m[3]-0",86:"i>m[3]-0",31:"m[3]-0==i",6N:"m[3]-0==i",3j:"i==0",3M:"i==r.M-1",6r:"i%2==0",6p:"i%2","3j-4m":"a.1b.3V(\'*\')[0]==a","3M-4m":"19.31(a.1b.5D,1,\'4v\')==a","84-4m":"!19.31(a.1b.5D,2,\'4v\')",6E:"a.1B",4B:"!a.1B",83:"(a.6A||a.80||19(a).1t()||\'\').1g(m[3])>=0",4b:\'"23"!=a.U&&19.1m(a,"18")!="2D"&&19.1m(a,"4X")!="23"\',23:\'"23"==a.U||19.1m(a,"18")=="2D"||19.1m(a,"4X")=="23"\',7Y:"!a.2W",2W:"a.2W",3o:"a.3o",2p:"a.2p||19.1K(a,\'2p\')",1t:"\'1t\'==a.U",5w:"\'5w\'==a.U",5y:"\'5y\'==a.U",5b:"\'5b\'==a.U",3J:"\'3J\'==a.U",59:"\'59\'==a.U",6n:"\'6n\'==a.U",6m:"\'6m\'==a.U",2G:\'"2G"==a.U||19.12(a,"2G")\',48:"/48|2y|6l|2G/i.17(a.12)",3E:"19.2r(m[3],a).M",7X:"/h\\\\d/i.17(a.12)",7W:"19.3x(19.3I,J(1i){K a==1i.O;}).M"}},6j:[/^(\\[) *@?([\\w-]+) *([!*$^~=]*) *(\'?"?)(.*?)\\4 *\\]/,/^(:)([\\w-]+)\\("?\'?(.*?(\\(.*?\\))?[^(]*?)"?\'?\\)/,1D 4r("^([:.#]*)("+C+"+)")],3d:J(a,c,b){L d,2o=[];2e(a&&a!=d){d=a;L f=E.1F(a,c,b);a=f.t.1p(/^\\s*,\\s*/,"");2o=b?c=f.r:E.34(2o,f.r)}K 2o},2r:J(t,p){7(1v t!="25")K[t];7(p&&p.15!=1&&p.15!=9)K[];p=p||T;L d=[p],2j=[],3M,12;2e(t&&3M!=t){L r=[];3M=t;t=E.3f(t);L o=S;L g=6w;L m=g.39(t);7(m){12=m[1].2F();P(L i=0;d[i];i++)P(L c=d[i].1B;c;c=c.2J)7(c.15==1&&(12=="*"||c.12.2F()==12))r.1h(c);d=r;t=t.1p(g,"");7(t.1g(" ")==0)6z;o=R}N{g=/^([>+~])\\s*(\\w*)/i;7((m=g.39(t))!=W){r=[];L l={};12=m[2].2F();m=m[1];P(L j=0,3g=d.M;j<3g;j++){L n=m=="~"||m=="+"?d[j].2J:d[j].1B;P(;n;n=n.2J)7(n.15==1){L h=E.Q(n);7(m=="~"&&l[h])1T;7(!12||n.12.2F()==12){7(m=="~")l[h]=R;r.1h(n)}7(m=="+")1T}}d=r;t=E.3f(t.1p(g,""));o=R}}7(t&&!o){7(!t.1g(",")){7(p==d[0])d.4k();2j=E.34(2j,d);r=d=[p];t=" "+t.6i(1,t.M)}N{L k=6v;L m=k.39(t);7(m){m=[0,m[2],m[3],m[1]]}N{k=6u;m=k.39(t)}m[2]=m[2].1p(/\\\\/g,"");L f=d[d.M-1];7(m[1]=="#"&&f&&f.5N&&!E.3W(f)){L q=f.5N(m[2]);7((E.14.1d||E.14.2B)&&q&&1v q.2s=="25"&&q.2s!=m[2])q=E(\'[@2s="\'+m[2]+\'"]\',f)[0];d=r=q&&(!m[3]||E.12(q,m[3]))?[q]:[]}N{P(L i=0;d[i];i++){L a=m[1]=="#"&&m[3]?m[3]:m[1]!=""||m[0]==""?"*":m[2];7(a=="*"&&d[i].12.2w()=="4D")a="3v";r=E.34(r,d[i].3V(a))}7(m[1]==".")r=E.58(r,m[2]);7(m[1]=="#"){L e=[];P(L i=0;r[i];i++)7(r[i].4z("2s")==m[2]){e=[r[i]];1T}r=e}d=r}t=t.1p(k,"")}}7(t){L b=E.1F(t,r);d=r=b.r;t=E.3f(b.t)}}7(t)d=[];7(d&&p==d[0])d.4k();2j=E.34(2j,d);K 2j},58:J(r,m,a){m=" "+m+" ";L c=[];P(L i=0;r[i];i++){L b=(" "+r[i].1w+" ").1g(m)>=0;7(!a&&b||a&&!b)c.1h(r[i])}K c},1F:J(t,r,h){L d;2e(t&&t!=d){d=t;L p=E.6j,m;P(L i=0;p[i];i++){m=p[i].39(t);7(m){t=t.7V(m[0].M);m[2]=m[2].1p(/\\\\/g,"");1T}}7(!m)1T;7(m[1]==":"&&m[2]=="4I")r=G.17(m[3])?E.1F(m[3],r,R).r:E(r).4I(m[3]);N 7(m[1]==".")r=E.58(r,m[2],h);N 7(m[1]=="["){L g=[],U=m[3];P(L i=0,3g=r.M;i<3g;i++){L a=r[i],z=a[E.3S[m[2]]||m[2]];7(z==W||/6T|3R|2p/.17(m[2]))z=E.1K(a,m[2])||\'\';7((U==""&&!!z||U=="="&&z==m[5]||U=="!="&&z!=m[5]||U=="^="&&z&&!z.1g(m[5])||U=="$="&&z.6i(z.M-m[5].M)==m[5]||(U=="*="||U=="~=")&&z.1g(m[5])>=0)^h)g.1h(a)}r=g}N 7(m[1]==":"&&m[2]=="31-4m"){L e={},g=[],17=/(-?)(\\d*)n((?:\\+|-)?\\d*)/.39(m[3]=="6r"&&"2n"||m[3]=="6p"&&"2n+1"||!/\\D/.17(m[3])&&"7U+"+m[3]||m[3]),3j=(17[1]+(17[2]||1))-0,d=17[3]-0;P(L i=0,3g=r.M;i<3g;i++){L j=r[i],1b=j.1b,2s=E.Q(1b);7(!e[2s]){L c=1;P(L n=1b.1B;n;n=n.2J)7(n.15==1)n.4p=c++;e[2s]=R}L b=S;7(3j==0){7(j.4p==d)b=R}N 7((j.4p-d)%3j==0&&(j.4p-d)/3j>=0)b=R;7(b^h)g.1h(j)}r=g}N{L f=E.5d[m[1]];7(1v f!="25")f=E.5d[m[1]][m[2]];f=4A("S||J(a,i){K "+f+"}");r=E.3x(r,f,h)}}K{r:r,t:t}},4w:J(b,c){L d=[];L a=b[c];2e(a&&a!=T){7(a.15==1)d.1h(a);a=a[c]}K d},31:J(a,e,c,b){e=e||1;L d=0;P(;a;a=a[c])7(a.15==1&&++d==e)1T;K a},5m:J(n,a){L r=[];P(;n;n=n.2J){7(n.15==1&&(!a||n!=a))r.1h(n)}K r}});E.16={1c:J(f,i,g,e){7(f.15==3||f.15==8)K;7(E.14.1d&&f.54!=10)f=1e;7(!g.2A)g.2A=6.2A++;7(e!=10){L h=g;g=J(){K h.1j(6,1a)};g.Q=e;g.2A=h.2A}L j=E.Q(f,"2N")||E.Q(f,"2N",{}),1x=E.Q(f,"1x")||E.Q(f,"1x",J(){L a;7(1v E=="10"||E.16.52)K a;a=E.16.1x.1j(1a.3G.O,1a);K a});1x.O=f;E.V(i.2d(/\\s+/),J(c,b){L a=b.2d(".");b=a[0];g.U=a[1];L d=j[b];7(!d){d=j[b]={};7(!E.16.2l[b]||E.16.2l[b].4i.1O(f)===S){7(f.3F)f.3F(b,1x,S);N 7(f.6h)f.6h("4h"+b,1x)}}d[g.2A]=g;E.16.2g[b]=R});f=W},2A:1,2g:{},1Y:J(e,h,f){7(e.15==3||e.15==8)K;L i=E.Q(e,"2N"),2f,5E;7(i){7(h==10)P(L g 1r i)6.1Y(e,g);N{7(h.U){f=h.2k;h=h.U}E.V(h.2d(/\\s+/),J(b,a){L c=a.2d(".");a=c[0];7(i[a]){7(f)2T i[a][f.2A];N P(f 1r i[a])7(!c[1]||i[a][f].U==c[1])2T i[a][f];P(2f 1r i[a])1T;7(!2f){7(!E.16.2l[a]||E.16.2l[a].4g.1O(e)===S){7(e.6f)e.6f(a,E.Q(e,"1x"),S);N 7(e.6d)e.6d("4h"+a,E.Q(e,"1x"))}2f=W;2T i[a]}}})}P(2f 1r i)1T;7(!2f){L d=E.Q(e,"1x");7(d)d.O=W;E.3H(e,"2N");E.3H(e,"1x")}}},1U:J(f,b,c,d,g){b=E.2H(b||[]);7(!c){7(6.2g[f])E("*").1c([1e,T]).1U(f,b)}N{7(c.15==3||c.15==8)K 10;L a,2f,1i=E.1q(c[f]||W),16=!b[0]||!b[0].32;7(16)b.4U(6.51({U:f,2K:c}));b[0].U=f;7(E.1q(E.Q(c,"1x")))a=E.Q(c,"1x").1j(c,b);7(!1i&&c["4h"+f]&&c["4h"+f].1j(c,b)===S)a=S;7(16)b.4k();7(g&&E.1q(g)){2f=g.1j(c,a==W?b:b.6Q(a));7(2f!==10)a=2f}7(1i&&d!==S&&a!==S&&!(E.12(c,\'a\')&&f=="50")){6.52=R;1R{c[f]()}1W(e){}}6.52=S}K a},1x:J(c){L a;c=E.16.51(c||1e.16||{});L b=c.U.2d(".");c.U=b[0];L f=E.Q(6,"2N")&&E.Q(6,"2N")[c.U],3B=1N.2m.2V.1O(1a,1);3B.4U(c);P(L j 1r f){L d=f[j];3B[0].2k=d;3B[0].Q=d.Q;7(!b[1]||d.U==b[1]){L e=d.1j(6,3B);7(a!==S)a=e;7(e===S){c.32();c.41()}}}7(E.14.1d)c.2K=c.32=c.41=c.2k=c.Q=W;K a},51:J(c){L a=c;c=E.1s({},a);c.32=J(){7(a.32)a.32();a.7T=S};c.41=J(){7(a.41)a.41();a.7S=R};7(!c.2K)c.2K=c.7R||T;7(c.2K.15==3)c.2K=a.2K.1b;7(!c.4W&&c.4V)c.4W=c.4V==c.2K?c.7Q:c.4V;7(c.6b==W&&c.6a!=W){L b=T.1I,1k=T.1k;c.6b=c.6a+(b&&b.2i||1k&&1k.2i||0)-(b.68||0);c.7O=c.7N+(b&&b.2x||1k&&1k.2x||0)-(b.67||0)}7(!c.3r&&((c.4f||c.4f===0)?c.4f:c.66))c.3r=c.4f||c.66;7(!c.65&&c.64)c.65=c.64;7(!c.3r&&c.2G)c.3r=(c.2G&1?1:(c.2G&2?3:(c.2G&4?2:0)));K c},2l:{21:{4i:J(){5A();K},4g:J(){K}},47:{4i:J(){7(E.14.1d)K S;E(6).2z("4Q",E.16.2l.47.2k);K R},4g:J(){7(E.14.1d)K S;E(6).42("4Q",E.16.2l.47.2k);K R},2k:J(a){7(I(a,6))K R;1a[0].U="47";K E.16.1x.1j(6,1a)}},46:{4i:J(){7(E.14.1d)K S;E(6).2z("4P",E.16.2l.46.2k);K R},4g:J(){7(E.14.1d)K S;E(6).42("4P",E.16.2l.46.2k);K R},2k:J(a){7(I(a,6))K R;1a[0].U="46";K E.16.1x.1j(6,1a)}}}};E.1i.1s({2z:J(c,a,b){K c=="4O"?6.30(c,a,b):6.V(J(){E.16.1c(6,c,b||a,b&&a)})},30:J(d,b,c){K 6.V(J(){E.16.1c(6,d,J(a){E(6).42(a);K(c||b).1j(6,1a)},c&&b)})},42:J(a,b){K 6.V(J(){E.16.1Y(6,a,b)})},1U:J(c,a,b){K 6.V(J(){E.16.1U(c,a,6,R,b)})},63:J(c,a,b){7(6[0])K E.16.1U(c,a,6[0],S,b);K 10},2h:J(){L b=1a;K 6.50(J(a){6.4N=0==6.4N?1:0;a.32();K b[6.4N].1j(6,1a)||S})},7F:J(a,b){K 6.2z(\'47\',a).2z(\'46\',b)},21:J(a){5A();7(E.2Q)a.1O(T,E);N E.3w.1h(J(){K a.1O(6,E)});K 6}});E.1s({2Q:S,3w:[],21:J(){7(!E.2Q){E.2Q=R;7(E.3w){E.V(E.3w,J(){6.1j(T)});E.3w=W}E(T).63("21")}}});L x=S;J 5A(){7(x)K;x=R;7(T.3F&&!E.14.2B)T.3F("61",E.21,S);7(E.14.1d&&1e==3b)(J(){7(E.2Q)K;1R{T.1I.7D("2c")}1W(3e){3z(1a.3G,0);K}E.21()})();7(E.14.2B)T.3F("61",J(){7(E.2Q)K;P(L i=0;i<T.4M.M;i++)7(T.4M[i].2W){3z(1a.3G,0);K}E.21()},S);7(E.14.26){L a;(J(){7(E.2Q)K;7(T.3c!="60"&&T.3c!="1z"){3z(1a.3G,0);K}7(a===10)a=E("Y, 5O[7B=7A]").M;7(T.4M.M!=a){3z(1a.3G,0);K}E.21()})()}E.16.1c(1e,"43",E.21)}E.V(("7z,7y,43,7x,5g,4O,50,7w,"+"7v,7u,7C,4Q,4P,7t,2y,"+"59,7s,7r,7G,3e").2d(","),J(i,b){E.1i[b]=J(a){K a?6.2z(b,a):6.1U(b)}});L I=J(a,c){L b=a.4W;2e(b&&b!=c)1R{b=b.1b}1W(3e){b=c}K b==c};E(1e).2z("4O",J(){E("*").1c(T).42()});E.1i.1s({43:J(g,d,c){7(E.1q(g))K 6.2z("43",g);L e=g.1g(" ");7(e>=0){L i=g.2V(e,g.M);g=g.2V(0,e)}c=c||J(){};L f="4J";7(d)7(E.1q(d)){c=d;d=W}N{d=E.3v(d);f="5Z"}L h=6;E.3Q({1f:g,U:f,1G:"3q",Q:d,1z:J(a,b){7(b=="1X"||b=="5Y")h.3q(i?E("<1u/>").3t(a.4e.1p(/<1o(.|\\s)*?\\/1o>/g,"")).2r(i):a.4e);h.V(c,[a.4e,b,a])}});K 6},7q:J(){K E.3v(6.5X())},5X:J(){K 6.2a(J(){K E.12(6,"3i")?E.2H(6.7p):6}).1F(J(){K 6.37&&!6.2W&&(6.3o||/2y|6l/i.17(6.12)||/1t|23|3J/i.17(6.U))}).2a(J(i,c){L b=E(6).5P();K b==W?W:b.1n==1N?E.2a(b,J(a,i){K{37:c.37,1C:a}}):{37:c.37,1C:b}}).22()}});E.V("5W,5V,5U,69,5T,5S".2d(","),J(i,o){E.1i[o]=J(f){K 6.2z(o,f)}});L B=(1D 3O).3N();E.1s({22:J(d,b,a,c){7(E.1q(b)){a=b;b=W}K E.3Q({U:"4J",1f:d,Q:b,1X:a,1G:c})},7o:J(b,a){K E.22(b,W,a,"1o")},7n:J(c,b,a){K E.22(c,b,a,"2O")},7m:J(d,b,a,c){7(E.1q(b)){a=b;b={}}K E.3Q({U:"5Z",1f:d,Q:b,1X:a,1G:c})},7Z:J(a){E.1s(E.4H,a)},4H:{2g:R,U:"4J",2U:0,5R:"49/x-7j-3i-7i",6x:R,3l:R,Q:W,6t:W,3J:W,4n:{3L:"49/3L, 1t/3L",3q:"1t/3q",1o:"1t/4l, 49/4l",2O:"49/2O, 1t/4l",1t:"1t/7e",4o:"*/*"}},4q:{},3Q:J(s){L f,2Y=/=\\?(&|$)/g,1A,Q;s=E.1s(R,s,E.1s(R,{},E.4H,s));7(s.Q&&s.6x&&1v s.Q!="25")s.Q=E.3v(s.Q);7(s.1G=="4u"){7(s.U.2w()=="22"){7(!s.1f.1E(2Y))s.1f+=(s.1f.1E(/\\?/)?"&":"?")+(s.4u||"7d")+"=?"}N 7(!s.Q||!s.Q.1E(2Y))s.Q=(s.Q?s.Q+"&":"")+(s.4u||"7d")+"=?";s.1G="2O"}7(s.1G=="2O"&&(s.Q&&s.Q.1E(2Y)||s.1f.1E(2Y))){f="4u"+B++;7(s.Q)s.Q=(s.Q+"").1p(2Y,"="+f+"$1");s.1f=s.1f.1p(2Y,"="+f+"$1");s.1G="1o";1e[f]=J(a){Q=a;1X();1z();1e[f]=10;1R{2T 1e[f]}1W(e){}7(h)h.2X(g)}}7(s.1G=="1o"&&s.1Q==W)s.1Q=S;7(s.1Q===S&&s.U.2w()=="22"){L i=(1D 3O()).3N();L j=s.1f.1p(/(\\?|&)4s=.*?(&|$)/,"$a2="+i+"$2");s.1f=j+((j==s.1f)?(s.1f.1E(/\\?/)?"&":"?")+"4s="+i:"")}7(s.Q&&s.U.2w()=="22"){s.1f+=(s.1f.1E(/\\?/)?"&":"?")+s.Q;s.Q=W}7(s.2g&&!E.5M++)E.16.1U("5W");7((!s.1f.1g("9Z")||!s.1f.1g("//"))&&(s.1G=="1o"||s.1G=="2O")&&s.U.2w()=="22"){L h=T.3V("6k")[0];L g=T.2R("1o");g.3R=s.1f;7(s.7c)g.9X=s.7c;7(!f){L l=S;g.9V=g.9U=J(){7(!l&&(!6.3c||6.3c=="60"||6.3c=="1z")){l=R;1X();1z();h.2X(g)}}}h.3k(g);K 10}L m=S;L k=1e.7a?1D 7a("9S.9Q"):1D 79();k.9P(s.U,s.1f,s.3l,s.6t,s.3J);1R{7(s.Q)k.4G("9N-9M",s.5R);7(s.5I)k.4G("9L-5H-9J",E.4q[s.1f]||"9H, 9G 9E 9B 5G:5G:5G 9z");k.4G("X-9x-9u","79");k.4G("9t",s.1G&&s.4n[s.1G]?s.4n[s.1G]+", */*":s.4n.4o)}1W(e){}7(s.75)s.75(k);7(s.2g)E.16.1U("5S",[k,s]);L c=J(a){7(!m&&k&&(k.3c==4||a=="2U")){m=R;7(d){74(d);d=W}1A=a=="2U"&&"2U"||!E.73(k)&&"3e"||s.5I&&E.72(k,s.1f)&&"5Y"||"1X";7(1A=="1X"){1R{Q=E.71(k,s.1G)}1W(e){1A="5C"}}7(1A=="1X"){L b;1R{b=k.5B("70-5H")}1W(e){}7(s.5I&&b)E.4q[s.1f]=b;7(!f)1X()}N E.5t(s,k,1A);1z();7(s.3l)k=W}};7(s.3l){L d=54(c,13);7(s.2U>0)3z(J(){7(k){k.9m();7(!m)c("2U")}},s.2U)}1R{k.9l(s.Q)}1W(e){E.5t(s,k,W,e)}7(!s.3l)c();J 1X(){7(s.1X)s.1X(Q,1A);7(s.2g)E.16.1U("5T",[k,s])}J 1z(){7(s.1z)s.1z(k,1A);7(s.2g)E.16.1U("5U",[k,s]);7(s.2g&&!--E.5M)E.16.1U("5V")}K k},5t:J(s,a,b,e){7(s.3e)s.3e(a,b,e);7(s.2g)E.16.1U("69",[a,s,e])},5M:0,73:J(r){1R{K!r.1A&&9k.9j=="5b:"||(r.1A>=6Y&&r.1A<9h)||r.1A==6X||r.1A==9e||E.14.26&&r.1A==10}1W(e){}K S},72:J(a,c){1R{L b=a.5B("70-5H");K a.1A==6X||b==E.4q[c]||E.14.26&&a.1A==10}1W(e){}K S},71:J(r,b){L c=r.5B("9d-U");L d=b=="3L"||!b&&c&&c.1g("3L")>=0;L a=d?r.9c:r.4e;7(d&&a.1I.28=="5C")6Z"5C";7(b=="1o")E.5l(a);7(b=="2O")a=4A("("+a+")");K a},3v:J(a){L s=[];7(a.1n==1N||a.5j)E.V(a,J(){s.1h(3s(6.37)+"="+3s(6.1C))});N P(L j 1r a)7(a[j]&&a[j].1n==1N)E.V(a[j],J(){s.1h(3s(j)+"="+3s(6))});N s.1h(3s(j)+"="+3s(a[j]));K s.6g("&").1p(/%20/g,"+")}});E.1i.1s({1J:J(c,b){K c?6.27({1P:"1J",29:"1J",1y:"1J"},c,b):6.1F(":23").V(J(){6.Y.18=6.5x||"";7(E.1m(6,"18")=="2D"){L a=E("<"+6.28+" />").6B("1k");6.Y.18=a.1m("18");7(6.Y.18=="2D")6.Y.18="3u";a.1Y()}}).3h()},1H:J(b,a){K b?6.27({1P:"1H",29:"1H",1y:"1H"},b,a):6.1F(":4b").V(J(){6.5x=6.5x||E.1m(6,"18");6.Y.18="2D"}).3h()},6U:E.1i.2h,2h:J(a,b){K E.1q(a)&&E.1q(b)?6.6U(a,b):a?6.27({1P:"2h",29:"2h",1y:"2h"},a,b):6.V(J(){E(6)[E(6).3K(":23")?"1J":"1H"]()})},98:J(b,a){K 6.27({1P:"1J"},b,a)},97:J(b,a){K 6.27({1P:"1H"},b,a)},96:J(b,a){K 6.27({1P:"2h"},b,a)},95:J(b,a){K 6.27({1y:"1J"},b,a)},94:J(b,a){K 6.27({1y:"1H"},b,a)},9f:J(c,a,b){K 6.27({1y:a},c,b)},27:J(l,k,j,h){L i=E.6V(k,j,h);K 6[i.2S===S?"V":"2S"](J(){7(6.15!=1)K S;L g=E.1s({},i);L f=E(6).3K(":23"),4y=6;P(L p 1r l){7(l[p]=="1H"&&f||l[p]=="1J"&&!f)K E.1q(g.1z)&&g.1z.1j(6);7(p=="1P"||p=="29"){g.18=E.1m(6,"18");g.36=6.Y.36}}7(g.36!=W)6.Y.36="23";g.40=E.1s({},l);E.V(l,J(c,a){L e=1D E.2v(4y,g,c);7(/2h|1J|1H/.17(a))e[a=="2h"?f?"1J":"1H":a](l);N{L b=a.3D().1E(/^([+-]=)?([\\d+-.]+)(.*)$/),24=e.2o(R)||0;7(b){L d=2M(b[2]),2C=b[3]||"2P";7(2C!="2P"){4y.Y[c]=(d||1)+2C;24=((d||1)/e.2o(R))*24;4y.Y[c]=24+2C}7(b[1])d=((b[1]=="-="?-1:1)*d)+24;e.3Z(24,d,2C)}N e.3Z(24,a,"")}});K R})},2S:J(a,b){7(E.1q(a)||(a&&a.1n==1N)){b=a;a="2v"}7(!a||(1v a=="25"&&!b))K A(6[0],a);K 6.V(J(){7(b.1n==1N)A(6,a,b);N{A(6,a).1h(b);7(A(6,a).M==1)b.1j(6)}})},8Z:J(b,c){L a=E.3I;7(b)6.2S([]);6.V(J(){P(L i=a.M-1;i>=0;i--)7(a[i].O==6){7(c)a[i](R);a.6R(i,1)}});7(!c)6.5z();K 6}});L A=J(b,c,a){7(!b)K 10;c=c||"2v";L q=E.Q(b,c+"2S");7(!q||a)q=E.Q(b,c+"2S",a?E.2H(a):[]);K q};E.1i.5z=J(a){a=a||"2v";K 6.V(J(){L q=A(6,a);q.4k();7(q.M)q[0].1j(6)})};E.1s({6V:J(b,a,c){L d=b&&b.1n==8Y?b:{1z:c||!c&&a||E.1q(b)&&b,2t:b,3Y:c&&a||a&&a.1n!=8W&&a};d.2t=(d.2t&&d.2t.1n==53?d.2t:{9w:8U,8T:6Y}[d.2t])||8S;d.5o=d.1z;d.1z=J(){7(d.2S!==S)E(6).5z();7(E.1q(d.5o))d.5o.1j(6)};K d},3Y:{6O:J(p,n,b,a){K b+a*p},5F:J(p,n,b,a){K((-1Z.9C(p*1Z.9D)/2)+0.5)*a+b}},3I:[],3T:W,2v:J(b,c,a){6.11=c;6.O=b;6.1l=a;7(!c.3U)c.3U={}}});E.2v.2m={4C:J(){7(6.11.33)6.11.33.1j(6.O,[6.2I,6]);(E.2v.33[6.1l]||E.2v.33.4o)(6);7(6.1l=="1P"||6.1l=="29")6.O.Y.18="3u"},2o:J(a){7(6.O[6.1l]!=W&&6.O.Y[6.1l]==W)K 6.O[6.1l];L r=2M(E.1m(6.O,6.1l,a));K r&&r>-8N?r:2M(E.2q(6.O,6.1l))||0},3Z:J(c,b,d){6.5s=(1D 3O()).3N();6.24=c;6.3h=b;6.2C=d||6.2C||"2P";6.2I=6.24;6.4E=6.4F=0;6.4C();L e=6;J t(a){K e.33(a)}t.O=6.O;E.3I.1h(t);7(E.3T==W){E.3T=54(J(){L a=E.3I;P(L i=0;i<a.M;i++)7(!a[i]())a.6R(i--,1);7(!a.M){74(E.3T);E.3T=W}},13)}},1J:J(){6.11.3U[6.1l]=E.1K(6.O.Y,6.1l);6.11.1J=R;6.3Z(0,6.2o());7(6.1l=="29"||6.1l=="1P")6.O.Y[6.1l]="8L";E(6.O).1J()},1H:J(){6.11.3U[6.1l]=E.1K(6.O.Y,6.1l);6.11.1H=R;6.3Z(6.2o(),0)},33:J(a){L t=(1D 3O()).3N();7(a||t>6.11.2t+6.5s){6.2I=6.3h;6.4E=6.4F=1;6.4C();6.11.40[6.1l]=R;L b=R;P(L i 1r 6.11.40)7(6.11.40[i]!==R)b=S;7(b){7(6.11.18!=W){6.O.Y.36=6.11.36;6.O.Y.18=6.11.18;7(E.1m(6.O,"18")=="2D")6.O.Y.18="3u"}7(6.11.1H)6.O.Y.18="2D";7(6.11.1H||6.11.1J)P(L p 1r 6.11.40)E.1K(6.O.Y,p,6.11.3U[p])}7(b&&E.1q(6.11.1z))6.11.1z.1j(6.O);K S}N{L n=t-6.5s;6.4F=n/6.11.2t;6.4E=E.3Y[6.11.3Y||(E.3Y.5F?"5F":"6O")](6.4F,n,0,1,6.11.2t);6.2I=6.24+((6.3h-6.24)*6.4E);6.4C()}K R}};E.2v.33={2i:J(a){a.O.2i=a.2I},2x:J(a){a.O.2x=a.2I},1y:J(a){E.1K(a.O.Y,"1y",a.2I)},4o:J(a){a.O.Y[a.1l]=a.2I+a.2C}};E.1i.5f=J(){L b=0,3b=0,O=6[0],5q;7(O)8K(E.14){L d=O.1b,45=O,1M=O.1M,1L=O.2u,5p=26&&4t(5n)<8H,2Z=E.1m(O,"3C")=="2Z";7(O.7b){L c=O.7b();1c(c.2c+1Z.2b(1L.1I.2i,1L.1k.2i),c.3b+1Z.2b(1L.1I.2x,1L.1k.2x));1c(-1L.1I.68,-1L.1I.67)}N{1c(O.5k,O.5K);2e(1M){1c(1M.5k,1M.5K);7(3X&&!/^t(8F|d|h)$/i.17(1M.28)||26&&!5p)3a(1M);7(!2Z&&E.1m(1M,"3C")=="2Z")2Z=R;45=/^1k$/i.17(1M.28)?45:1M;1M=1M.1M}2e(d&&d.28&&!/^1k|3q$/i.17(d.28)){7(!/^a0|1V.*$/i.17(E.1m(d,"18")))1c(-d.2i,-d.2x);7(3X&&E.1m(d,"36")!="4b")3a(d);d=d.1b}7((5p&&(2Z||E.1m(45,"3C")=="4Z"))||(3X&&E.1m(45,"3C")!="4Z"))1c(-1L.1k.5k,-1L.1k.5K);7(2Z)1c(1Z.2b(1L.1I.2i,1L.1k.2i),1Z.2b(1L.1I.2x,1L.1k.2x))}5q={3b:3b,2c:b}}J 3a(a){1c(E.2q(a,"a1",R),E.2q(a,"8D",R))}J 1c(l,t){b+=4t(l)||0;3b+=4t(t)||0}K 5q}})();',62,624,'||||||this|if||||||||||||||||||||||||||||||||||||||function|return|var|length|else|elem|for|data|true|false|document|type|each|null||style||undefined|options|nodeName||browser|nodeType|event|test|display|jQuery|arguments|parentNode|add|msie|window|url|indexOf|push|fn|apply|body|prop|css|constructor|script|replace|isFunction|in|extend|text|div|typeof|className|handle|opacity|complete|status|firstChild|value|new|match|filter|dataType|hide|documentElement|show|attr|doc|offsetParent|Array|call|height|cache|try|tbody|break|trigger|table|catch|success|remove|Math||ready|get|hidden|start|string|safari|animate|tagName|width|map|max|left|split|while|ret|global|toggle|scrollLeft|done|handler|special|prototype||cur|selected|curCSS|find|id|duration|ownerDocument|fx|toLowerCase|scrollTop|select|bind|guid|opera|unit|none|pushStack|toUpperCase|button|makeArray|now|nextSibling|target|stack|parseFloat|events|json|px|isReady|createElement|queue|delete|timeout|slice|disabled|removeChild|jsre|fixed|one|nth|preventDefault|step|merge|inArray|overflow|name|innerHTML|exec|border|top|readyState|multiFilter|error|trim|rl|end|form|first|appendChild|async|elems|insertBefore|checked|childNodes|html|which|encodeURIComponent|append|block|param|readyList|grep|color|setTimeout|runtimeStyle|args|position|toString|has|addEventListener|callee|removeData|timers|password|is|xml|last|getTime|Date|domManip|ajax|src|props|timerId|orig|getElementsByTagName|isXMLDoc|mozilla|easing|custom|curAnim|stopPropagation|unbind|load|selectedIndex|offsetChild|mouseleave|mouseenter|input|application|defaultView|visible|float|String|responseText|charCode|teardown|on|setup|currentStyle|shift|javascript|child|accepts|_default|nodeIndex|lastModified|RegExp|_|parseInt|jsonp|previousSibling|dir|tr|self|getAttribute|eval|empty|update|object|pos|state|setRequestHeader|ajaxSettings|not|GET|getPropertyValue|getComputedStyle|styleSheets|lastToggle|unload|mouseout|mouseover|andSelf|getWH|container2|unshift|fromElement|relatedTarget|visibility|init|absolute|click|fix|triggered|Number|setInterval|removeAttribute|prevObject|unique|classFilter|submit|after|file|clean|expr|windowData|offset|scroll|client|deep|jquery|offsetLeft|globalEval|sibling|version|old|safari2|results|wrapAll|startTime|handleError|container|createTextNode|radio|oldblock|checkbox|dequeue|bindReady|getResponseHeader|parsererror|lastChild|index|swing|00|Modified|ifModified|clone|offsetTop|values|active|getElementById|link|val|col|contentType|ajaxSend|ajaxSuccess|ajaxComplete|ajaxStop|ajaxStart|serializeArray|notmodified|POST|loaded|DOMContentLoaded|Width|triggerHandler|ctrlKey|metaKey|keyCode|clientTop|clientLeft|ajaxError|clientX|pageX|cloneNode|detachEvent|swap|removeEventListener|join|attachEvent|substr|parse|head|textarea|reset|image|before|odd|zoom|even|prepend|username|quickClass|quickID|quickChild|processData|uuid|continue|textContent|appendTo|contents|evalScript|parent|defaultValue|setArray|CSS1Compat|compatMode|cssFloat|styleFloat|webkit|nodeValue|eq|linear|replaceWith|concat|splice|100|href|_toggle|speed|alpha|304|200|throw|Last|httpData|httpNotModified|httpSuccess|clearInterval|beforeSend|colgroup|fieldset|multiple|XMLHttpRequest|ActiveXObject|getBoundingClientRect|scriptCharset|callback|plain|img|hasClass|br|urlencoded|www|abbr|pixelLeft|post|getJSON|getScript|elements|serialize|keypress|keydown|change|mouseup|mousedown|dblclick|resize|focus|blur|stylesheet|rel|mousemove|doScroll|round|hover|keyup|padding|offsetHeight|offsetWidth|Bottom|Top|Right|clientY|pageY|Left|toElement|srcElement|cancelBubble|returnValue|0n|substring|animated|header|enabled|ajaxSetup|innerText|noConflict|size|contains|only|line|gt|weight|lt|font|uFFFF|u0128|417|inner|Height|Boolean|toggleClass|removeClass|addClass|removeAttr|replaceAll|insertAfter|wrap|prependTo|contentWindow|contentDocument|iframe|children|siblings|wrapInner|prevAll|nextAll|prev|next|parents|maxLength|maxlength|readOnly|readonly|borderTopWidth|class|able|htmlFor|522|reverse|boxModel|with|1px|compatible|10000|ie|ra|it|rv|400|fast|600|userAgent|Function|navigator|Object|stop|option|array|ig|NaN|fadeOut|fadeIn|slideToggle|slideUp|slideDown|setAttribute|changed|be|responseXML|content|1223|fadeTo|can|300|property|protocol|location|send|abort|getAttributeNode|specified|method|action|cssText|attributes|Accept|With|th|slow|Requested|td|GMT|cap|1970|cos|PI|Jan|colg|01|Thu|tfoot|Since|thead|If|Type|Content|leg|open|XMLHTTP|opt|Microsoft|embed|onreadystatechange|onload|area|charset|hr|http|inline|borderLeftWidth|1_|meta'.split('|'),0,{}));


/* FILE: socialtext/jquery.dimensions.js */
/* Copyright (c) 2007 Paul Bakaus (paul.bakaus@googlemail.com) and Brandon Aaron (brandon.aaron@gmail.com || http://brandonaaron.net)
 * Dual licensed under the MIT (http://www.opensource.org/licenses/mit-license.php)
 * and GPL (http://www.opensource.org/licenses/gpl-license.php) licenses.
 *
 * $LastChangedDate: 2008-02-28 10:49:55 +0000 (Thu, 28 Feb 2008) $
 * $Rev: 4841 $
 *
 * Version: @VERSION
 *
 * Requires: jQuery 1.2+
 */

(function($){
	
$.dimensions = {
	version: '@VERSION'
};

// Create innerHeight, innerWidth, outerHeight and outerWidth methods
$.each( [ 'Height', 'Width' ], function(i, name){
	
	// innerHeight and innerWidth
	$.fn[ 'inner' + name ] = function() {
		if (!this[0]) return;
		
		var torl = name == 'Height' ? 'Top'    : 'Left',  // top or left
		    borr = name == 'Height' ? 'Bottom' : 'Right'; // bottom or right
		
		return this.css('display') != 'none' ? this[0]['client' + name] : num( this, name.toLowerCase() ) + num(this, 'padding' + torl) + num(this, 'padding' + borr);
	};
	
	// outerHeight and outerWidth
	$.fn[ 'outer' + name ] = function(options) {
		if (!this[0]) return;
		
		var torl = name == 'Height' ? 'Top'    : 'Left',  // top or left
		    borr = name == 'Height' ? 'Bottom' : 'Right'; // bottom or right
		
		options = $.extend({ margin: false }, options || {});
		
		var val = this.css('display') != 'none' ? 
				this[0]['offset' + name] : 
				num( this, name.toLowerCase() )
					+ num(this, 'border' + torl + 'Width') + num(this, 'border' + borr + 'Width')
					+ num(this, 'padding' + torl) + num(this, 'padding' + borr);
		
		return val + (options.margin ? (num(this, 'margin' + torl) + num(this, 'margin' + borr)) : 0);
	};
});

// Create scrollLeft and scrollTop methods
$.each( ['Left', 'Top'], function(i, name) {
	$.fn[ 'scroll' + name ] = function(val) {
		if (!this[0]) return;
		
		return val != undefined ?
		
			// Set the scroll offset
			this.each(function() {
				this == window || this == document ?
					window.scrollTo( 
						name == 'Left' ? val : $(window)[ 'scrollLeft' ](),
						name == 'Top'  ? val : $(window)[ 'scrollTop'  ]()
					) :
					this[ 'scroll' + name ] = val;
			}) :
			
			// Return the scroll offset
			this[0] == window || this[0] == document ?
				self[ (name == 'Left' ? 'pageXOffset' : 'pageYOffset') ] ||
					$.boxModel && document.documentElement[ 'scroll' + name ] ||
					document.body[ 'scroll' + name ] :
				this[0][ 'scroll' + name ];
	};
});

$.fn.extend({
	position: function() {
		var left = 0, top = 0, elem = this[0], offset, parentOffset, offsetParent, results;
		
		if (elem) {
			// Get *real* offsetParent
			offsetParent = this.offsetParent();
			
			// Get correct offsets
			offset       = this.offset();
			parentOffset = offsetParent.offset();
			
			// Subtract element margins
			offset.top  -= num(elem, 'marginTop');
			offset.left -= num(elem, 'marginLeft');
			
			// Add offsetParent borders
			parentOffset.top  += num(offsetParent, 'borderTopWidth');
			parentOffset.left += num(offsetParent, 'borderLeftWidth');
			
			// Subtract the two offsets
			results = {
				top:  offset.top  - parentOffset.top,
				left: offset.left - parentOffset.left
			};
		}
		
		return results;
	},
	
	offsetParent: function() {
		var offsetParent = this[0].offsetParent;
		while ( offsetParent && (!/^body|html$/i.test(offsetParent.tagName) && $.css(offsetParent, 'position') == 'static') )
			offsetParent = offsetParent.offsetParent;
		return $(offsetParent);
	}
});

function num(el, prop) {
	return parseInt($.curCSS(el.jquery?el[0]:el,prop,true))||0;
};

})(jQuery);

/* FILE: socialtext/ui.mouse.js */
(function($) {
	
	//If the UI scope is not availalable, add it
	$.ui = $.ui || {};
	
	//Add methods that are vital for all mouse interaction stuff (plugin registering)
	$.extend($.ui, {
		plugin: {
			add: function(w, c, o, p) {
				var a = $.ui[w].prototype; if(!a.plugins[c]) a.plugins[c] = [];
				a.plugins[c].push([o,p]);
			},
			call: function(instance, name, arguments) {
				var c = instance.plugins[name]; if(!c) return;
				var o = instance.interaction ? instance.interaction.options : instance.options;
				var e = instance.interaction ? instance.interaction.element : instance.element;
				
				for (var i = 0; i < c.length; i++) {
					if (o[c[i][0]]) c[i][1].apply(e, arguments);
				}	
			}	
		}
	});
	
	$.fn.mouseInteractionDestroy = function() {
		this.each(function() {
			if($.data(this, "ui-mouse")) $.data(this, "ui-mouse").destroy(); 	
		});
	}
	
	$.ui.mouseInteraction = function(el,o) {
	
		if(!o) var o = {};
		this.element = el;
		$.data(this.element, "ui-mouse", this);
		
		this.options = {};
		$.extend(this.options, o);
		$.extend(this.options, {
			handle : o.handle ? ($(o.handle, el)[0] ? $(o.handle, el) : $(el)) : $(el),
			helper: o.helper || 'original',
			preventionDistance: o.preventionDistance || 0,
			dragPrevention: o.dragPrevention ? o.dragPrevention.toLowerCase().split(',') : ['input','textarea','button','select','option'],
			cursorAt: { top: ((o.cursorAt && o.cursorAt.top) ? o.cursorAt.top : 0), left: ((o.cursorAt && o.cursorAt.left) ? o.cursorAt.left : 0), bottom: ((o.cursorAt && o.cursorAt.bottom) ? o.cursorAt.bottom : 0), right: ((o.cursorAt && o.cursorAt.right) ? o.cursorAt.right : 0) },
			cursorAtIgnore: (!o.cursorAt) ? true : false, //Internal property
			appendTo: o.appendTo || 'parent'			
		})
		o = this.options; //Just Lazyness
		
		if(!this.options.nonDestructive && (o.helper == 'clone' || o.helper == 'original')) {

			// Let's save the margins for better reference
			o.margins = {
				top: parseInt($(el).css('marginTop')) || 0,
				left: parseInt($(el).css('marginLeft')) || 0,
				bottom: parseInt($(el).css('marginBottom')) || 0,
				right: parseInt($(el).css('marginRight')) || 0
			};

			// We have to add margins to our cursorAt
			if(o.cursorAt.top != 0) o.cursorAt.top = o.margins.top;
			if(o.cursorAt.left != 0) o.cursorAt.left += o.margins.left;
			if(o.cursorAt.bottom != 0) o.cursorAt.bottom += o.margins.bottom;
			if(o.cursorAt.right != 0) o.cursorAt.right += o.margins.right;
			
			
			if(o.helper == 'original')
				o.wasPositioned = $(el).css('position');
			
		} else {
			o.margins = { top: 0, left: 0, right: 0, bottom: 0 };
		}
		
		var self = this;
		this.mousedownfunc = function(e) { // Bind the mousedown event
			return self.click.apply(self, [e]);	
		}
		o.handle.bind('mousedown', this.mousedownfunc);
		
		//Prevent selection of text when starting the drag in IE
		if($.browser.msie) $(this.element).attr('unselectable', 'on');
		
	}
	
	$.extend($.ui.mouseInteraction.prototype, {
		plugins: {},
		currentTarget: null,
		lastTarget: null,
		timer: null,
		slowMode: false,
		init: false,
		destroy: function() {
			this.options.handle.unbind('mousedown', this.mousedownfunc);
		},
		trigger: function(e) {
			return this.click.apply(this, arguments);
		},
		click: function(e) {

			var o = this.options;
			
			window.focus();
			if(e.which != 1) return true; //only left click starts dragging
		
			// Prevent execution on defined elements
			var targetName = (e.target) ? e.target.nodeName.toLowerCase() : e.srcElement.nodeName.toLowerCase();
			for(var i=0;i<o.dragPrevention.length;i++) {
				if(targetName == o.dragPrevention[i]) return true;
			}

			//Prevent execution on condition
			if(o.startCondition && !o.startCondition.apply(this, [e])) return true;

			var self = this;
			this.mouseup = function(e) { return self.stop.apply(self, [e]); }
			this.mousemove = function(e) { return self.drag.apply(self, [e]); }

			var initFunc = function() { //This function get's called at bottom or after timeout
				$(document).bind('mouseup', self.mouseup);
				$(document).bind('mousemove', self.mousemove);
				self.opos = [e.pageX,e.pageY]; // Get the original mouse position
			}
			
			if(o.preventionTimeout) { //use prevention timeout
				if(this.timer) clearInterval(this.timer);
				this.timer = setTimeout(function() { initFunc(); }, o.preventionTimeout);
				return false;
			}
		
			initFunc();
			return false;
			
		},
		start: function(e) {
			
			var o = this.options; var a = this.element;
			o.co = $(a).offset(); //get the current offset
				
			this.helper = typeof o.helper == 'function' ? $(o.helper.apply(a, [e,this]))[0] : (o.helper == 'clone' ? $(a).clone()[0] : a);

			if(o.appendTo == 'parent') { // Let's see if we have a positioned parent
				var cp = a.parentNode;
				while (cp) {
					if(cp.style && ($(cp).css('position') == 'relative' || $(cp).css('position') == 'absolute')) {
						o.pp = cp;
						o.po = $(cp).offset();
						o.ppOverflow = !!($(o.pp).css('overflow') == 'auto' || $(o.pp).css('overflow') == 'scroll'); //TODO!
						break;	
					}
					cp = cp.parentNode ? cp.parentNode : null;
				};
				
				if(!o.pp) o.po = { top: 0, left: 0 };
			}
			
			this.pos = [this.opos[0],this.opos[1]]; //Use the relative position
			this.rpos = [this.pos[0],this.pos[1]]; //Save the absolute position
			
			if(o.cursorAtIgnore) { // If we want to pick the element where we clicked, we borrow cursorAt and add margins
				o.cursorAt.left = this.pos[0] - o.co.left + o.margins.left;
				o.cursorAt.top = this.pos[1] - o.co.top + o.margins.top;
			}



			if(o.pp) { // If we have a positioned parent, we pick the draggable relative to it
				this.pos[0] -= o.po.left;
				this.pos[1] -= o.po.top;
			}
			
			this.slowMode = (o.cursorAt && (o.cursorAt.top-o.margins.top > 0 || o.cursorAt.bottom-o.margins.bottom > 0) && (o.cursorAt.left-o.margins.left > 0 || o.cursorAt.right-o.margins.right > 0)) ? true : false; //If cursorAt is within the helper, set slowMode to true
			
			if(!o.nonDestructive) $(this.helper).css('position', 'absolute');
			if(o.helper != 'original') $(this.helper).appendTo((o.appendTo == 'parent' ? a.parentNode : o.appendTo)).show();

			// Remap right/bottom properties for cursorAt to left/top
			if(o.cursorAt.right && !o.cursorAt.left) o.cursorAt.left = this.helper.offsetWidth+o.margins.right+o.margins.left - o.cursorAt.right;
			if(o.cursorAt.bottom && !o.cursorAt.top) o.cursorAt.top = this.helper.offsetHeight+o.margins.top+o.margins.bottom - o.cursorAt.bottom;
		
			this.init = true;	

			if(o._start) o._start.apply(a, [this.helper, this.pos, o.cursorAt, this, e]); // Trigger the start callback
			this.helperSize = { width: $(this.helper).outerWidth(), height: $(this.helper).outerHeight() }; //Set helper size property
			return false;
						
		},
		stop: function(e) {			
			
			var o = this.options; var a = this.element; var self = this;

			$(document).unbind('mouseup', self.mouseup);
			$(document).unbind('mousemove', self.mousemove);

			if(this.init == false) return this.opos = this.pos = null;
			if(o._beforeStop) o._beforeStop.apply(a, [this.helper, this.pos, o.cursorAt, this, e]);

			if(this.helper != a && !o.beQuietAtEnd) { // Remove helper, if it's not the original node
				$(this.helper).remove(); this.helper = null;
			}
			
			if(!o.beQuietAtEnd) {
				//if(o.wasPositioned)	$(a).css('position', o.wasPositioned);
				if(o._stop) o._stop.apply(a, [this.helper, this.pos, o.cursorAt, this, e]);
			}

			this.init = false;
			this.opos = this.pos = null;
			return false;
			
		},
		drag: function(e) {

			if (!this.opos || ($.browser.msie && !e.button)) return this.stop.apply(this, [e]); // check for IE mouseup when moving into the document again
			var o = this.options;
			
			this.pos = [e.pageX,e.pageY]; //relative mouse position
			if(this.rpos && this.rpos[0] == this.pos[0] && this.rpos[1] == this.pos[1]) return false;
			this.rpos = [this.pos[0],this.pos[1]]; //absolute mouse position
			
			if(o.pp) { //If we have a positioned parent, use a relative position
				this.pos[0] -= o.po.left;
				this.pos[1] -= o.po.top;	
			}
			
			if( (Math.abs(this.rpos[0]-this.opos[0]) > o.preventionDistance || Math.abs(this.rpos[1]-this.opos[1]) > o.preventionDistance) && this.init == false) //If position is more than x pixels from original position, start dragging
				this.start.apply(this,[e]);			
			else {
				if(this.init == false) return false;
			}
		
			if(o._drag) o._drag.apply(this.element, [this.helper, this.pos, o.cursorAt, this, e]);
			return false;
			
		}
	});

 })(jQuery);


/* FILE: socialtext/ui.draggable.js */
(function($) {

	//Make nodes selectable by expression
	$.extend($.expr[':'], { draggable: "(' '+a.className+' ').indexOf(' ui-draggable ')" });


	//Macros for external methods that support chaining
	var methods = "destroy,enable,disable".split(",");
	for(var i=0;i<methods.length;i++) {
		var cur = methods[i], f;
		eval('f = function() { var a = arguments; return this.each(function() { if(jQuery(this).is(".ui-draggable")) jQuery.data(this, "ui-draggable")["'+cur+'"](a); }); }');
		$.fn["draggable"+cur.substr(0,1).toUpperCase()+cur.substr(1)] = f;
	};
	
	//get instance method
	$.fn.draggableInstance = function() {
		if($(this[0]).is(".ui-draggable")) return $.data(this[0], "ui-draggable");
		return false;
	};

	$.fn.draggable = function(o) {
		return this.each(function() {
			if(!$(this).is(".ui-draggable")) new $.ui.draggable(this, o);
		});
	}
	
	$.ui.ddmanager = {
		current: null,
		droppables: [],
		prepareOffsets: function(t, e) {
			var dropTop = $.ui.ddmanager.dropTop = [];
			var dropLeft = $.ui.ddmanager.dropLeft;
			var m = $.ui.ddmanager.droppables;
			for (var i = 0; i < m.length; i++) {
				if(m[i].item.disabled) continue;
				m[i].offset = $(m[i].item.element).offset();
				if (t && m[i].item.options.accept(t.element)) //Activate the droppable if used directly from draggables
					m[i].item.activate.call(m[i].item, e);
			}
		},
		fire: function(oDrag, e) {
			
			var oDrops = $.ui.ddmanager.droppables;
			var oOvers = $.grep(oDrops, function(oDrop) {
				if (!!oDrop && !oDrop.item.disabled && $.ui.intersect(oDrag, oDrop, oDrop.item.options.tolerance))
					oDrop.item.drop.call(oDrop.item, e);
			});
			$.each(oDrops, function(i, oDrop) {
				if (!oDrop.item.disabled && oDrop.item.options.accept(oDrag.element)) {
					oDrop.out = 1; oDrop.over = 0;
					oDrop.item.deactivate.call(oDrop.item, e);
				}
			});
		},
		update: function(oDrag, e) {
			
			if(oDrag.options.refreshPositions) $.ui.ddmanager.prepareOffsets();
			
			var oDrops = $.ui.ddmanager.droppables;
			var oOvers = $.grep(oDrops, function(oDrop) {
				if(oDrop.item.disabled) return false; 
				var isOver = $.ui.intersect(oDrag, oDrop, oDrop.item.options.tolerance)
				if (!isOver && oDrop.over == 1) {
					oDrop.out = 1; oDrop.over = 0;
					oDrop.item.out.call(oDrop.item, e);
				}
				return isOver;
			});
			$.each(oOvers, function(i, oOver) {
				if (oOver.over == 0) {
					oOver.out = 0; oOver.over = 1;
					oOver.item.over.call(oOver.item, e);
				}
			});
		}
	};
	
	$.ui.draggable = function(el, o) {
		
		var options = {};
		$.extend(options, o);
		var self = this;
		$.extend(options, {
			_start: function(h, p, c, t, e) {
				self.start.apply(t, [self, e]); // Trigger the start callback				
			},
			_beforeStop: function(h, p, c, t, e) {
				self.stop.apply(t, [self, e]); // Trigger the start callback
			},
			_drag: function(h, p, c, t, e) {
				self.drag.apply(t, [self, e]); // Trigger the start callback
			},
			startCondition: function(e) {
				return !(e.target.className.indexOf("ui-resizable-handle") != -1 || self.disabled);	
			}			
		});
		
		$.data(el, "ui-draggable", this);
		
		if (options.ghosting == true) options.helper = 'clone'; //legacy option check
		$(el).addClass("ui-draggable");
		this.interaction = new $.ui.mouseInteraction(el, options);
		
	}
	
	$.extend($.ui.draggable.prototype, {
		plugins: {},
		currentTarget: null,
		lastTarget: null,
		destroy: function() {
			$(this.interaction.element).removeClass("ui-draggable").removeClass("ui-draggable-disabled");
			this.interaction.destroy();
		},
		enable: function() {
			$(this.interaction.element).removeClass("ui-draggable-disabled");
			this.disabled = false;
		},
		disable: function() {
			$(this.interaction.element).addClass("ui-draggable-disabled");
			this.disabled = true;
		},
		prepareCallbackObj: function(self) {
			return {
				helper: self.helper,
				position: { left: self.pos[0], top: self.pos[1] },
				offset: self.options.cursorAt,
				draggable: self,
				options: self.options	
			}			
		},
		start: function(that, e) {
			
			var o = this.options;
			$.ui.ddmanager.current = this;
			
			$.ui.plugin.call(that, 'start', [e, that.prepareCallbackObj(this)]);
			$(this.element).triggerHandler("dragstart", [e, that.prepareCallbackObj(this)], o.start);
			
			if (this.slowMode && $.ui.droppable && !o.dropBehaviour)
				$.ui.ddmanager.prepareOffsets(this, e);
			
			return false;
						
		},
		stop: function(that, e) {			
			
			var o = this.options;
			
			$.ui.plugin.call(that, 'stop', [e, that.prepareCallbackObj(this)]);
			$(this.element).triggerHandler("dragstop", [e, that.prepareCallbackObj(this)], o.stop);

			if (this.slowMode && $.ui.droppable && !o.dropBehaviour) //If cursorAt is within the helper, we must use our drop manager
				$.ui.ddmanager.fire(this, e);

			$.ui.ddmanager.current = null;
			$.ui.ddmanager.last = this;

			return false;
			
		},
		drag: function(that, e) {

			var o = this.options;

			$.ui.ddmanager.update(this, e);

			this.pos = [this.pos[0]-o.cursorAt.left, this.pos[1]-o.cursorAt.top];

			$.ui.plugin.call(that, 'drag', [e, that.prepareCallbackObj(this)]);
			var nv = $(this.element).triggerHandler("drag", [e, that.prepareCallbackObj(this)], o.drag);

			var nl = (nv && nv.left) ? nv.left : this.pos[0];
			var nt = (nv && nv.top) ? nv.top : this.pos[1];
			
			$(this.helper).css('left', nl+'px').css('top', nt+'px'); // Stick the helper to the cursor
			return false;
			
		}
	});

})(jQuery);


/* FILE: socialtext/ui.draggable.ext.js */
/*
 * 'this' -> original element
 * 1. argument: browser event
 * 2.argument: ui object
 */

(function($) {

	$.ui.plugin.add("draggable", "stop", "effect", function(e,ui) {
		var t = ui.helper;
		if(ui.options.effect[1]) {
			if(t != this) {
				ui.options.beQuietAtEnd = true;
				switch(ui.options.effect[1]) {
					case 'fade':
						$(t).fadeOut(300, function() { $(this).remove(); });
						break;
					default:
						$(t).remove();
						break;	
				}
			}
		}
	});
	
	$.ui.plugin.add("draggable", "start", "effect", function(e,ui) {
		if(ui.options.effect[0]) {
			switch(ui.options.effect[0]) {
				case 'fade':
					$(ui.helper).hide().fadeIn(300);
					break;
			}
		}
	});

//----------------------------------------------------------------

	$.ui.plugin.add("draggable", "start", "cursor", function(e,ui) {
		var t = $('body');
		if (t.css("cursor")) ui.options.ocursor = t.css("cursor");
		t.css("cursor", ui.options.cursor);
	});

	$.ui.plugin.add("draggable", "stop", "cursor", function(e,ui) {
		if (ui.options.ocursor) $('body').css("cursor", ui.options.ocursor);
	});

//----------------------------------------------------------------
	
	$.ui.plugin.add("draggable", "start", "zIndex", function(e,ui) {
		var t = $(ui.helper);
		if(t.css("zIndex")) ui.options.ozIndex = t.css("zIndex");
		t.css('zIndex', ui.options.zIndex);
	});
	
	$.ui.plugin.add("draggable", "stop", "zIndex", function(e,ui) {
		if(ui.options.ozIndex) $(ui.helper).css('zIndex', ui.options.ozIndex);
	});


//----------------------------------------------------------------

	$.ui.plugin.add("draggable", "start", "opacity", function(e,ui) {
		var t = $(ui.helper);
		if(t.css("opacity")) ui.options.oopacity = t.css("opacity");
		t.css('opacity', ui.options.opacity);
	});
	
	$.ui.plugin.add("draggable", "stop", "opacity", function(e,ui) {
		if(ui.options.oopacity) $(ui.helper).css('opacity', ui.options.oopacity);
	});

//----------------------------------------------------------------

	$.ui.plugin.add("draggable", "stop", "revert", function(e,ui) {
	
		var o = ui.options;
		var rpos = { left: 0, top: 0 };
		o.beQuietAtEnd = true;

		if(ui.helper != this) {

			rpos = $(ui.draggable.sorthelper || this).offset({ border: false });

			var nl = rpos.left-o.po.left-o.margins.left;
			var nt = rpos.top-o.po.top-o.margins.top;

		} else {
			var nl = o.co.left - (o.po ? o.po.left : 0);
			var nt = o.co.top - (o.po ? o.po.top : 0);
		}
		
		var self = ui.draggable;

		$(ui.helper).animate({
			left: nl,
			top: nt
		}, 500, function() {
			
			if(o.wasPositioned) $(self.element).css('position', o.wasPositioned);
			if(o.stop) o.stop.apply(self.element, [self.helper, self.pos, [o.co.left - o.po.left,o.co.top - o.po.top],self]);
			
			if(self.helper != self.element) window.setTimeout(function() { $(self.helper).remove(); }, 0); //Using setTimeout because of strange flickering in Firefox
			
		});
		
	});

//----------------------------------------------------------------

	$.ui.plugin.add("draggable", "start", "iframeFix", function(e,ui) {

		var o = ui.options;
		if(!ui.draggable.slowMode) { // Make clones on top of iframes (only if we are not in slowMode)
			if(o.iframeFix.constructor == Array) {
				for(var i=0;i<o.iframeFix.length;i++) {
					var co = $(o.iframeFix[i]).offset({ border: false });
					$("<div class='DragDropIframeFix' style='background: #fff;'></div>").css("width", $(o.iframeFix[i])[0].offsetWidth+"px").css("height", $(o.iframeFix[i])[0].offsetHeight+"px").css("position", "absolute").css("opacity", "0.001").css("z-index", "1000").css("top", co.top+"px").css("left", co.left+"px").appendTo("body");
				}		
			} else {
				$("iframe").each(function() {					
					var co = $(this).offset({ border: false });
					$("<div class='DragDropIframeFix' style='background: #fff;'></div>").css("width", this.offsetWidth+"px").css("height", this.offsetHeight+"px").css("position", "absolute").css("opacity", "0.001").css("z-index", "1000").css("top", co.top+"px").css("left", co.left+"px").appendTo("body");
				});							
			}		
		}

	});
	
	$.ui.plugin.add("draggable","stop", "iframeFix", function(e,ui) {
		if(ui.options.iframeFix) $("div.DragDropIframeFix").each(function() { this.parentNode.removeChild(this); }); //Remove frame helpers	
	});
		
//----------------------------------------------------------------

	$.ui.plugin.add("draggable", "start", "containment", function(e,ui) {

		var o = ui.options;

		if(!o.cursorAtIgnore || o.containment.left != undefined || o.containment.constructor == Array) return;
		if(o.containment == 'parent') o.containment = this.parentNode;


		if(o.containment == 'document') {
			o.containment = [
				0-o.margins.left,
				0-o.margins.top,
				$(document).width()-o.margins.right,
				($(document).height() || document.body.parentNode.scrollHeight)-o.margins.bottom
			];
		} else { //I'm a node, so compute top/left/right/bottom
			var ce = $(o.containment)[0];
			var co = $(o.containment).offset({ border: false });

			o.containment = [
				co.left-o.margins.left,
				co.top-o.margins.top,
				co.left+(ce.offsetWidth || ce.scrollWidth)-o.margins.right,
				co.top+(ce.offsetHeight || ce.scrollHeight)-o.margins.bottom
			];
		}

	});
	
	$.ui.plugin.add("draggable", "drag", "containment", function(e,ui) {
		
		var o = ui.options;
		if(!o.cursorAtIgnore) return;
			
		var h = $(ui.helper);
		var c = o.containment;
		if(c.constructor == Array) {
			
			if((ui.draggable.pos[0] < c[0]-o.po.left)) ui.draggable.pos[0] = c[0]-o.po.left;
			if((ui.draggable.pos[1] < c[1]-o.po.top)) ui.draggable.pos[1] = c[1]-o.po.top;
			if(ui.draggable.pos[0]+h[0].offsetWidth > c[2]-o.po.left) ui.draggable.pos[0] = c[2]-o.po.left-h[0].offsetWidth;
			if(ui.draggable.pos[1]+h[0].offsetHeight > c[3]-o.po.top) ui.draggable.pos[1] = c[3]-o.po.top-h[0].offsetHeight;
			
		} else {

			if(c.left && (ui.draggable.pos[0] < c.left)) ui.draggable.pos[0] = c.left;
			if(c.top && (ui.draggable.pos[1] < c.top)) ui.draggable.pos[1] = c.top;

			var p = $(o.pp);
			if(c.right && ui.draggable.pos[0]+h[0].offsetWidth > p[0].offsetWidth-c.right) ui.draggable.pos[0] = (p[0].offsetWidth-c.right)-h[0].offsetWidth;
			if(c.bottom && ui.draggable.pos[1]+h[0].offsetHeight > p[0].offsetHeight-c.bottom) ui.draggable.pos[1] = (p[0].offsetHeight-c.bottom)-h[0].offsetHeight;
			
		}

		
	});

//----------------------------------------------------------------

	$.ui.plugin.add("draggable", "drag", "grid", function(e,ui) {
		var o = ui.options;
		if(!o.cursorAtIgnore) return;
		ui.draggable.pos[0] = o.co.left + o.margins.left - o.po.left + Math.round((ui.draggable.pos[0] - o.co.left - o.margins.left + o.po.left) / o.grid[0]) * o.grid[0];
		ui.draggable.pos[1] = o.co.top + o.margins.top - o.po.top + Math.round((ui.draggable.pos[1] - o.co.top - o.margins.top + o.po.top) / o.grid[1]) * o.grid[1];
	});

//----------------------------------------------------------------

	$.ui.plugin.add("draggable", "drag", "axis", function(e,ui) {
		var o = ui.options;
		if(!o.cursorAtIgnore) return;
		if(o.constraint) o.axis = o.constraint; //Legacy check
		o.axis ? ( o.axis == 'x' ? ui.draggable.pos[1] = o.co.top - o.margins.top - o.po.top : ui.draggable.pos[0] = o.co.left - o.margins.left - o.po.left ) : null;
	});

//----------------------------------------------------------------

	$.ui.plugin.add("draggable", "drag", "scroll", function(e,ui) {

		var o = ui.options;
		o.scrollSensitivity	= o.scrollSensitivity || 20;
		o.scrollSpeed		= o.scrollSpeed || 20;

		if(o.pp && o.ppOverflow) { // If we have a positioned parent, we only scroll in this one
			// TODO: Extremely strange issues are waiting here..handle with care
		} else {
			if((ui.draggable.rpos[1] - $(window).height()) - $(document).scrollTop() > -o.scrollSensitivity) window.scrollBy(0,o.scrollSpeed);
			if(ui.draggable.rpos[1] - $(document).scrollTop() < o.scrollSensitivity) window.scrollBy(0,-o.scrollSpeed);
			if((ui.draggable.rpos[0] - $(window).width()) - $(document).scrollLeft() > -o.scrollSensitivity) window.scrollBy(o.scrollSpeed,0);
			if(ui.draggable.rpos[0] - $(document).scrollLeft() < o.scrollSensitivity) window.scrollBy(-o.scrollSpeed,0);
		}

	});

//----------------------------------------------------------------

	$.ui.plugin.add("draggable", "drag", "wrapHelper", function(e,ui) {

		var o = ui.options;
		if(o.cursorAtIgnore) return;
		var t = ui.helper;

		if(!o.pp || !o.ppOverflow) {
			var wx = $(window).width() - ($.browser.mozilla ? 20 : 0);
			var sx = $(document).scrollLeft();
			
			var wy = $(window).height();
			var sy = $(document).scrollTop();	
		} else {
			var wx = o.pp.offsetWidth + o.po.left - 20;
			var sx = o.pp.scrollLeft;
			
			var wy = o.pp.offsetHeight + o.po.top - 20;
			var sy = o.pp.scrollTop;						
		}

		ui.draggable.pos[0] -= ((ui.draggable.rpos[0]-o.cursorAt.left - wx + t.offsetWidth+o.margins.right) - sx > 0 || (ui.draggable.rpos[0]-o.cursorAt.left+o.margins.left) - sx < 0) ? (t.offsetWidth+o.margins.left+o.margins.right - o.cursorAt.left * 2) : 0;
		
		ui.draggable.pos[1] -= ((ui.draggable.rpos[1]-o.cursorAt.top - wy + t.offsetHeight+o.margins.bottom) - sy > 0 || (ui.draggable.rpos[1]-o.cursorAt.top+o.margins.top) - sy < 0) ? (t.offsetHeight+o.margins.top+o.margins.bottom - o.cursorAt.top * 2) : 0;

	});

})(jQuery);



/* FILE: socialtext/drag-and-drop.js */
function add_placeholder (args) {
    if (args.el.ph) return;
    args.el.ph = document.createElement('div');
    args.el.ph.style.border = '2px dashed rgb(170,170,170)';
    jQuery(args.el.ph).addClass('widgetWrap');
    jQuery(args.el.ph).addClass('placeholder');

    jQuery(args.el.ph).height(
        jQuery(args.el).height()
    );

    if (args.func)
        jQuery(args.el.ph)[args.func](args.where);
    else
        throw new Error("Unspecified placeholder location");
}

function move_placeholder (args) {
    args.el.ph.parentNode.removeChild(args.el.ph);
    args.el.ph = null;
    add_placeholder(args);
}

function is_over (cursor, element) {
    var elpos = [
        [ element.offsetLeft, element.offsetLeft + element.offsetWidth ],
        [ element.offsetTop, element.offsetTop + element.offsetHeight ]
    ];
    if ((cursor[0] > elpos[0][0] && cursor[0] < elpos[0][1]) &&
        (cursor[1] > elpos[1][0] && cursor[1] < elpos[1][1])) {
        return true;
    }
    return false;
}

jQuery(function () {
    jQuery('.widgetWrap').draggable({
        handle: '.widgetHeader',
        opacity: .5,
        zIndex: 10000,
        start: function (e, ui) {
            add_placeholder({func:'insertBefore', where:this, el:this});
            // our placeholder will be the right size for us, lets use it's
            // size to make ourselves a fixed width, remove this when we drop
            jQuery(this).height(jQuery(this.ph).height());
            jQuery(this).width(jQuery(this.ph).width());
        },
        drag: function (e, ui) {
            var drag = this;
            var cursor = ui.draggable.rpos;

            jQuery(this).removeClass('static');

            if (drag.over && is_over(cursor,drag.over)) return;

            var drop;
            jQuery('.widgetWrap, .gadget-col:not(:has(div.static))').each(function () {
                if (this.id != drag.id && is_over(cursor, this)) {
                    drop = this;
                }
            });

            if (drop) {
                if (drag.over && drag.over.id == drop.id) return;
                drag.over = drop;
                if (!jQuery(drop).hasClass('placeholder')) {
                    var args = { el: drag, where: drop };
                    if (!jQuery(drop).hasClass('widgetWrap')) {
                        args.func = 'appendTo';
                    }
                    else {
                        args.func = 'insertBefore';
                        jQuery(drop).prev().each(function () {
                            if (jQuery(this).hasClass('placeholder'))
                                args.func = 'insertAfter';
                        });
                    }
                    move_placeholder(args);
                }
            }
        },
        stop: function (e, ui) {
            jQuery(this.ph).replaceWith(this);
            jQuery(this).addClass('static');
            this.style.position = 'static';
            this.style.height = null; // remove the static height/width we added
            this.style.width = null;
            this.ph = null;
            gadgets.container._update_desktop();
        }
    });
});


/* FILE: socialtext/gadgets.js */
/**
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements. See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership. The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License. You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 */

var gadgets = gadgets || {};

gadgets.Container = function() {
    this.gadgets_ = {};
    this.parentUrl_ = 'http://' + document.location.host;
    this.country_ = 'ALL';
    this.language_ = 'ALL';
    this.view_ = 'default';
    this.nocache_ = 1;

    // signed max int
    this.maxheight_ = 0x7FFFFFFF;

    this.registerServices();

    this.fixGadgetTitles();
}

var proto = gadgets.Container.prototype = {};

proto.fixGadgetTitles = function () {
    /* This function truncates all titles and appends an elipsis until
     * the title fits within its container
     */
    var fn = function () {
        jQuery('.gadget_title').each(function () {
            var el = jQuery(this);
            var parheight = this.parentNode.parentNode.offsetHeight;
            var val = el.attr('full');
            if (!val) {
                el.attr('full', val = el.html() || 'Untitled');
            }
            el.html(val);
            for (var i=val.length - 1; i && this.offsetHeight > parheight; i--) {
                el.html(val.substr(0,i) + '...');
            }
        });
    };
    jQuery(fn);
    jQuery(window).bind('resize', fn);
}

proto.registerServices = function () {
    gadgets.rpc.register('resize_iframe', this.setHeight);
    gadgets.rpc.register('set_pref', this.setUserPref);
    gadgets.rpc.register('set_title', this.setTitle);
    gadgets.rpc.register('requestNavigateTo', this.requestNavigateTo);
};

proto.setHeight = function(height) {
    if (height > gadgets.container.maxheight_) {
        height = gadgets.container.maxheight_;
    }
    var element = document.getElementById(this.f + '-iframe');
    if (element) {
        element.style.height = height + 'px';
    }
};

proto.setTitle = function(title) {
    var element = document.getElementById(this.f + '-title-text');
    if (title.length >= 30 ) {
      title = title.substr(0,27); // same as template
      title = title + ' ...';
    }
    if (element) {
        element.innerHTML =
            title.replace(/&/g, '&amp;').replace(/</g, '&lt;');
    }
};

/**
 * Sets one or more user preferences
 * @param {String} editToken
 * @param {String} name Name of user preference
 * @param {String} value Value of user preference
 * More names and values may follow
 */
proto.setUserPref = function(authToken, name, value) {
    var base = '/data/gadget/instance/' + this.f;

    var args = []
    for (var i = 1, j = arguments.length; i < j; i += 2) {
        args.push('up_' + arguments[i] + '=' + arguments[i + 1]);
    }

    var data = args.join('&');
    jQuery.ajax({
        type: 'POST',
        url:  base + '/prefs',
        data: data
    });
};

/**
 * Navigates the page to a new url based on a gadgets requested view and
 * parameters.
 */
proto.requestNavigateTo = function(view, opt_params) {
    var id = this.getGadgetIdFromModuleId(this.f);
    var url = this.getUrlForView(view);

    if (opt_params) {
        var paramStr = JSON.stringify(opt_params);
        if (paramStr.length > 0) {
            url += '&appParams=' + encodeURIComponent(paramStr);
        }
    }

    if (url && document.location.href.indexOf(url) == -1) {
        document.location.href = url;
    }
};

proto.minimize = function (id) {
    var setup = jQuery('#'+id+'-setup');
    var content = jQuery('#'+id+'-content')

    if (this.minimized) {
        if (this.setup_visible)
            setup.fadeIn('slow');
        else
            content.fadeIn('slow');
        this.minimized = false;
    }
    else {
        this.setup_visible = setup.is(':visible') ? true : false;
        setup.fadeOut('slow');
        content.fadeOut('slow');
        this.minimized = true;
    }
};

proto.save = function (id) {
    var self = this;
    var base = '/data/gadget/instance/' + id;

    var iframe = jQuery('#'+id+'-iframe');

    var args = [];
    jQuery('.input_' + id).each(function () {
        args.push(this.name + '=' + jQuery(this).val());
    });

    self.toggleSetup(id)
    iframe.attr('src', '/nlw/plugin/gadgets/loading.html');

    var data = args.join('&');
    jQuery.ajax({
        type: 'POST',
        url:  base + '/prefs',
        data: data,
        success: function (msg) {
            iframe.bind('load', function () { 
            });
            
            iframe.attr('src', base + '/render?' + data);
        }
    });
}

proto.toggleSetup = function (id) {
    var setup = jQuery('#'+id+'-setup');
    var content = jQuery('#'+id+'-content')
    
    setup.toggle();
    content.toggle();
    return;
}

proto._desktop_layout = function () {
    var cols = {};
    jQuery('.gadget-col').each(function(col) {
        cols[col] = {};
        jQuery('.widgetWrap',this).each(function(row){
            var id = jQuery(this).attr('id');
            cols[col][row] = id;
        });
    });
    return cols;
}

proto._update_desktop = function () {
    var cols = this._desktop_layout();
    jQuery.ajax({
        type: 'POST',
        url:  '/data/gadget/desktop',
        data: 'desktop=' + gadgets.json.stringify(cols)
    });

}

proto._delete_gadget = function (id) {
    var cols = this._desktop_layout();
    jQuery.ajax({
        type: 'POST',
        url:  '/data/gadget/desktop',
        data: 'delete=' + id + '&desktop=' + gadgets.json.stringify(cols)
    });

}


proto.remove = function (id) {
    jQuery('#'+id).fadeOut('slow',function() {
        jQuery('#'+id).remove();
        gadgets.container._delete_gadget(id);
    });
}

gadgets.container = new gadgets.Container();



