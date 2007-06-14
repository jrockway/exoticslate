// Lightbox

if (typeof ST == 'undefined') {
    ST = {};
}

ST.Lightbox = function() {};

ST.Lightbox.prototype = {
    create: function(contentElement) {
        var wrapper = document.createElement("div");
        var overlay = document.createElement("div");
        var content = document.createElement("div");

        wrapper.appendChild(overlay);
        wrapper.appendChild(content);

        overlay.className = "popup-overlay";

        content.className = "st-lightbox-content";
        content.appendChild(contentElement);

        this.wrapper = wrapper;
        this.overlay = overlay;
        this.content = content;

        return this;
    },
    show: function() {
        document.body.appendChild(this.wrapper);
        this.center(this.overlay, this.content, this.wrapper);
        with(this.wrapper.style) {
            position = Wikiwyg.is_ie ? "absolute" :"fixed";
            top = 0;
            left = 0;
            width = "100%";
            height = "100%";
        }
        with(this.overlay.style) {
            zIndex = 90;
            position = Wikiwyg.is_ie ? "absolute" :"fixed";
        }
        with(this.content.style) {
            zIndex = 2000;
            position = Wikiwyg.is_ie ? "absolute" :"fixed";
        }
    },
    close: function() {
        document.body.removeChild(this.wrapper);
    },
    center: function (overlayElement, element, parentElement) {
        try{
            element = $(element);
        } catch(e) {
            return;
        }

        var my_width  = 0;
        var my_height = 0;

        if ( typeof( window.innerWidth ) == 'number' ) {
            my_width  = window.innerWidth;
            my_height = window.innerHeight;
        }
        else if (document.documentElement &&
                 (document.documentElement.clientWidth || document.documentElement.clientHeight)) {
            my_width  = document.documentElement.clientWidth;
            my_height = document.documentElement.clientHeight;
        }
        else if (document.body &&
                (document.body.clientWidth || document.body.clientHeight)) {
            my_width  = document.body.clientWidth;
            my_height = document.body.clientHeight;
        }

        $(parentElement).style.height = my_height + 'px';
        $(overlayElement).style.height = my_height + 'px';

        var scrollY = 0;
        if ( document.documentElement && document.documentElement.scrollTop ){
            scrollY = document.documentElement.scrollTop;
        } else if ( document.body && document.body.scrollTop ){
            scrollY = document.body.scrollTop;
        } else if ( window.pageYOffset ){
            scrollY = window.pageYOffset;
        } else if ( window.scrollY ){
            scrollY = window.scrollY;
        }

        var elementDimensions = Element.getDimensions(element);

        var setX = ( my_width  - elementDimensions.width  ) / 2;
        var setY = ( my_height - elementDimensions.height ) / 2 + scrollY;

        setX = ( setX < 0 ) ? 0 : setX;
        setY = ( setY < 0 ) ? 0 : setY;
        element.style.left = setX + "px";
//        element.style.top  = setY + "px";

        return false;
    }

};

