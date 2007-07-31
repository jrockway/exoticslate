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
            alert(loc("You must check at least one page in order to create a PDF."));
        }
        else {
            $(this.element.submitAction).value = 'pdf_export';
            $(this.element.submitFilename).value = Socialtext.wiki_id + ".pdf";
            $(this.element.form).submit();
        }
    },

    _getRtf: function () {
        if (!this._atLeastOnePageSelected()) {
            alert(loc("You must check at least one page in order to create a Word document."));
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
