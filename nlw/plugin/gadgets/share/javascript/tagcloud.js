/* TagCloud version 1.0.0
 *
 * (c) 2006 Lyo Kato <lyo.kato@gmail.com>
 * TagCloud is freely distributable under the terms of MIT-style license.
 * 
 * This library requires the JavaScript Framework "Protoype" (version 1.4 or later ).
 * For details, see http://prototype.conio.net/
/*---------------------------------------------------------------------------------*/
if (typeof Prototype == 'undefined') {
  throw "TagCloud needs Prototype.";
}


var TagCloud = {
  Version: '1.0.0',
  create: function() {
    return new TagCloud.Container();
  },
  styles: {
    tag: {
      fontSize: "24px",
      margin: "2px"
    },
    tagAnchor: {
      //textDecoration: 'none'
    },
    tagList: {
      fontFamily: "Arial,sans-serif",
      fontSize: '100%',
      margin: "0px"
    }
  },
  setBasicTagStyle: function(style) {
    this.styles.tag = style;
  },
  extendBasicTagStyle: function(style) {
    Object.extend(this.styles.tag, style);
  },
  setBasicTagAnchorStyle: function(style) {
    this.styles.tagAnchor = style;
  },
  extendBasicTagAnchorStyle: function(style) {
    Object.extend(this.styles.tagAnchor, style);
  },
  setBasicTagListStyle: function(style) {
    this.styles.tagList = style;
  },
  extendBasicTagListStyle: function(style) {
    Object.extend(this.styles.tagList, style);
  }
}

TagCloud.Tag = Class.create();
TagCloud.Tag.prototype = {
  initialize: function(name, count, url, epoch) {
    this.name  = name;
    this.count = count;
    this.url   = url;
    this.epoch = epoch;
    this.style = new Object();
    Object.extend(this.style, TagCloud.styles.tag);
    this.anchorStyle = new Object(); 
    Object.extend(this.anchorStyle, TagCloud.styles.tagAnchor);
  },
  toElement: function() {
    var element = document.createElement('span');
    // var element = document.createElement('li');
    var linkElement = document.createElement('a');
    linkElement.setAttribute('href', this.url);
    linkElement.setAttribute('target', 'parent');
    var text = document.createTextNode(this.name);
    linkElement.appendChild(text);
    this.anchorStyle['color'] = this.style.color;
   // alert('extend is broken here: ' + this.anchorStyle);
    Object.extend(linkElement.style, {});
    // 400M install to debug this, it better be a good bug!
    Object.extend(linkElement.style, this.anchorStyle);
    element.appendChild(linkElement);
    
    // Object.extend(element.style, this.style);
    // alert('style: ' + linkElement.style);
    return element;
  }
}

TagCloud.Container = Class.create();
TagCloud.Container.prototype = {
  initialize: function() {
    this.reset();
  },
  reset: function() {
    this.tags      = new Array();
    this.effectors = new Array();
  },
  clear: function() {
    this.tags = new Array();
  },
  add: function(name, count, url, epoch) {
    this.tags.push(this.createTag(name, count, url, epoch));
  },
  createTag: function(name, count, url, epoch) {
    return new TagCloud.Tag(name, count, url, epoch);
  },
  toElement: function() {
    var list = document.createElement('div');
    // var list = document.createElement('ul');
    this.tags.each( function(tag) {
      list.appendChild(tag.toElement());
    } );
    Object.extend(list.style, TagCloud.styles.tagList);
    return list;
  },
  setElementsTo: function(element) {
    $(element).appendChild(this.toElement());
  },
  toHTML: function() {
    var temp = document.createElement('div');
    temp.appendChild(this.toElement());
    return temp.innerHTML;
  },
  generateHTML: function() {
    this.runEffectors();
    return this.toHTML();
  },
  setup: function(element) {
    this.generateInto(element);
  },
  generateInto: function(element) {
    this.runEffectors();
    this.setElementsTo(element);
  },
  runEffectors: function() {
    this.effectors.invoke('affect', this.tags);
  },
  loadEffector: function(effectorName) {
    var effectorClass = TagCloud.Effector[effectorName];
    if (!effectorClass)
      throw "Unknown Effector, " + effectorName;
    var effector = new effectorClass();
    this.effectors.push(effector);
    return effector;
  }
}

TagCloud.Effector = new Object();
TagCloud.Effector.Base = Class.create();
TagCloud.Effector.Base.prototype = {
  initialize: function()     { },
  affect:     function(tags) { }
}

TagCloud.Effector.CountSize = Class.create();
Object.extend( Object.extend(
  TagCloud.Effector.CountSize.prototype,
  TagCloud.Effector.Base.prototype), {
  initialize: function() {
    this.baseFontSize  = 12;
    this.fontSizeRange = 12;
    this.suffix        = "px";
    this.suffixTypes   = ['px', 'pt', 'pc', 'in', 'mm', 'cm'];
  },
  base: function(size) {
    this.baseFontSize = size;
    return this;
  },
  range: function(range) {
    this.fontSizeRange = range;
    return this;
  },
  suffix: function(suffix) {
    if( this.suffixTypes.include(suffix) )
      this.suffix = suffix;
    return this;
  },

  dec2hex: function( dec ) {
     var hexDigits = '0123456789ABCDEF';
     return( hexDigits[ dec >> 4 ] + hexDigits[ dec & 15 ] );
   },


  affect: function(tags) {
    var maxFontSize = this.baseFontSize + this.fontSizeRange;
    var minFontSize = this.baseFontSize - this.fontSizeRange;
    if (minFontSize < 0) minFontSize = 0;
    var range = maxFontSize - minFontSize;
    var countList = tags.map( function(tag){ return tag.count; } );
    var min = countList.min();
    var max = countList.max();
    var suffix = this.suffix;
    var base   = this.baseFontSize;
    var Color = new Array();
    for (var ix = 0; ix <= 10; ix ++ ) {
      Color.push('#' + this.dec2hex((10 - ix) * 10 ) + this.dec2hex((10 - ix) * 10 )+ this.dec2hex(ix * 25));
    }
    var calculator = new TagCloud.Calculator(min, max, range);
    tags.each( function(tag) {
      var size = calculator.calculate(tag.count);
      tag.style.fontSize = String(size + base) + suffix;
      var colorix = Math.round((tag.count / max ) * 10);
      tag.style.color = Color[colorix];
    });
  }
});

TagCloud.Effector.DateTimeColor = Class.create();
Object.extend( Object.extend(
  TagCloud.Effector.DateTimeColor.prototype,
  TagCloud.Effector.Base.prototype), {
  initialize: function() {
    this.types = ['earliest', 'earlier', 'later', 'latest'];
    this.styles = {
      earliest: { color: '#ccc' },
      earlier:  { color: '#99c' },
      later:    { color: '#99f' },
      latest:   { color: '#00f' }
    };
  },
  earlier: function(color) {
    this.styles.earlier.color = color;
    return this;
  },
  earliest: function(color) {
    this.styles.earliest.color = color;
    return this;
  },
  later: function(color) {
    this.styles.later.color = color;
    return this;
  },
  latest: function(color) {
    this.styles.latest.color = color;
    return this;
  },
  affect: function(tags) {
    var epochList = tags.map( function(tag){ return tag.epoch; } );
    var min = epochList.min();
    var max = epochList.max();
    var calculator = new TagCloud.Calculator(min, max, 3);
    var styles = this.styles;
    var types  = this.types;
    tags.each( function(tag) {
      var level = calculator.calculate(tag.epoch);
      Object.extend(tag.anchorStyle, styles[types[level]]);
    });
  }
});

TagCloud.Effector.HotWord = Class.create();
Object.extend( Object.extend(
  TagCloud.Effector.HotWord.prototype,
  TagCloud.Effector.Base.prototype), {
  initialize: function() {
    this.hotWords = new Array();
    this.style = {
      color: '#f00'
    };
  },
  allWords: function(wordsArray) {
     this.hotWords = wordsArray;
     return this;
  },
  words: function() {
    this.hotWords = $A(arguments);
    return this;
  },
  color: function(color) {
    this.style.color = color;
    return this;
  },
  affect: function(tags) {
    var effector = this;
    tags.each( function(tag) {
      if (effector.hotWords.include(tag.name)) {
        Object.extend(tag.anchorStyle, effector.style);
      }
    });
  }
});

TagCloud.Calculator = Class.create();
TagCloud.Calculator.prototype = {
  initialize: function(min, max, range) {
    this.min    = Math.log(min);
    this.max    = Math.log(max);
    this.range  = range;
    this.factor = null;
    this.initializeFactor();
  },
  initializeFactor: function() {
    if (this.min == this.max) {
      this.min -= this.range;
      this.factor = 1;
    } else {
      this.factor = this.range / (this.max - this.min);
    }
  },
  calculate: function(number) {
    return parseInt((Math.log(number) - this.min) * this.factor);
  }
}

