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
    iframe.attr('src', '/plugin/gadgets/loading.html');

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

proto._update_desktop = function () {
    var cols = {};
    jQuery('.gadget-col').each(function(col) {
        cols[col] = {};
        jQuery('.widgetWrap',this).each(function(row){
            var id = jQuery(this).attr('id');
            cols[col][row] = id;
        });
    });

    jQuery.ajax({
        type: 'POST',
        url:  '/data/gadget/desktop',
        data: 'desktop=' + gadgets.json.stringify(cols)
    });

}

proto._delete_gadget = function (id) {
    jQuery.ajax({
        type: 'POST',
        url:  '/data/gadget/desktop',
        data: 'delete=' + id
    });

}


proto.remove = function (id) {
    jQuery('#'+id).fadeOut('slow',function() {
        jQuery('#'+id).remove();
        gadgets.container._update_desktop();
        gadgets.container._delete_gadget(id);
    });
}

gadgets.container = new gadgets.Container();
