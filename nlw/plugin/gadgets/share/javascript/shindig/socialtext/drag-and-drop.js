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
