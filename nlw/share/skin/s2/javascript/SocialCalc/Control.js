;(function () {

if (! window.SocialCalc) return;

if (!SocialCalc.TableEditor) {
    throw("SocialCalc TableEditor code module needed");
}

// *************************************
//
// SpreadsheetControl class:
//
// *************************************

// Global constants:

SocialCalc.CurrentSpreadsheetControlObject = null; // right now there can only be one active at a time


// Constructor:

SocialCalc.SpreadsheetControl = function() {

    // Properties:

    this.parentNode = null;
    this.spreadsheetDiv = null;
    this.requestedHeight = 0;
    this.requestedWidth = 0;
    this.height = 0;
    this.width = 0;

    // Tab definitions: An array where each tab is an object of the form:
    //
    //    name: "name",
    //    text: "text-on-tab",
    //    html: "html-to-create div",
    //       replacements:
    //         "%s.": "SocialCalc", "%id.": spreadsheet.idPrefix, "%tbt.": spreadsheet.toolbartext
    //    view: "viewname", // view to show when selected; "sheet" or missing/null is spreadsheet
    //    onclick: function(spreadsheet, tab-name), missing/null is sheet default
    //    onclickFocus: text, // spreadsheet.idPrefix+text is given the focus if present instead of normal KeyboardFocus
    //       or if text isn't a string, that value (e.g., true) is used for SocialCalc.CmdGotFocus
    //    onunclick: function(spreadsheet, tab-name), missing/null is sheet default

    this.tabs = [];
    this.tabnums = {}; // when adding tabs, add tab-name: array-index to this object
    this.currentTab = -1; // currently selected tab index in this.tabs or -1 (maintained by SocialCalc.SetTab)

    // View definitions: An object where each view is an object of the form:
    //
    //    name: "name",
    //    element: node-in-the-dom, // filled in when initialized
    //    html: "html-to-create div",
    //       replacements:
    //         "%s.": "SocialCalc", "%id.": spreadsheet.idPrefix, "%tbt.": spreadsheet.toolbartext
    //
    // There is always a "sheet" view.

    this.views = {}; // {viewname: view-object, ...}

    // Dynamic properties:

    this.sheet = null;
    this.context = null;
    this.editor = null;

    this.spreadsheetDiv = null;
    this.editorDiv = null;

    this.sortrange = ""; // remembered range for sort tab

    // Constants:

    this.idPrefix = "SocialCalc-"; // prefix added to element ids used here
    this.multipartBoundary = "SocialCalcSpreadsheetControlSave"; // boundary used by SpreadsheetControlCreateSpreadsheetSave

    this.tabbackground = "background-color:#CCC;";
    this.toolbartext = "font-size:x-small;font-weight:bold;color:#FFF;padding-bottom:4px;";

    // Callbacks:

    this.ExportCallback = null; // a function called for Clipboard Export button: this.ExportCallback(spreadsheet_control_object)

    // Initialization Code:

    this.sheet = new SocialCalc.Sheet();
    this.context = new SocialCalc.RenderContext(this.sheet);
    this.context.showGrid=true;
    this.context.showRCHeaders=true;
    this.editor = new SocialCalc.TableEditor(this.context);
    this.inputbox = new SocialCalc.InputBox(
        jQuery("#st-spreadsheet-formular-input").get(0),
        this.editor
    );

    // remember this for rendezvousing on events
    SocialCalc.CurrentSpreadsheetControlObject = this;

    return;
}

// Methods:

SocialCalc.SpreadsheetControl.prototype.InitializeSpreadsheetControl =
   function(node, height, width) {return SocialCalc.InitializeSpreadsheetControl(this, node, height, width);};
SocialCalc.SpreadsheetControl.prototype.SizeSSDiv = function() {return SocialCalc.SizeSSDiv(this);};
SocialCalc.SpreadsheetControl.prototype.FullRefreshAndRender = function() {return SocialCalc.FullRefreshAndRender(this);};
SocialCalc.SpreadsheetControl.prototype.ExecuteCommand = 
   function(combostr, sstr) {return SocialCalc.SpreadsheetControlExecuteCommand(this, combostr, sstr);};
SocialCalc.SpreadsheetControl.prototype.CreateSheetHTML = 
   function() {return SocialCalc.SpreadsheetControlCreateSheetHTML(this);};
SocialCalc.SpreadsheetControl.prototype.CreateSpreadsheetSave = 
   function() {return SocialCalc.SpreadsheetControlCreateSpreadsheetSave(this);};
SocialCalc.SpreadsheetControl.prototype.DecodeSpreadsheetSave = 
   function(str) {return SocialCalc.SpreadsheetControlDecodeSpreadsheetSave(this, str);};
SocialCalc.SpreadsheetControl.prototype.CreateCellHTML = 
   function(coord) {return SocialCalc.SpreadsheetControlCreateCellHTML(this, coord);};
SocialCalc.SpreadsheetControl.prototype.CreateCellHTMLSave = 
   function(range) {return SocialCalc.SpreadsheetControlCreateCellHTMLSave(this, range);};


// Sheet Methods to make things a little easier:

SocialCalc.SpreadsheetControl.prototype.ParseSheetSave = function(str) {return this.sheet.ParseSheetSave(str);};
SocialCalc.SpreadsheetControl.prototype.CreateSheetSave = function() {return this.sheet.CreateSheetSave();};

// Functions:

//
// InitializeSpreadsheetControl(spreadsheet, node, height, width)
//
// Creates the control elements and makes them the child of node (string or element).
// If present, height and width specify size.
// If either is 0 or null (missing), the maximum that fits on the screen is used.
//
// Displays the tabs and creates the views (other than "sheet").
// The first tab is set as selected, but onclick is not invoked.
//

SocialCalc.InitializeSpreadsheetControl = function(spreadsheet, node, height, width) {

   var html, child, i, vname, v;
   var tabs = spreadsheet.tabs;
   var views = spreadsheet.views;

   spreadsheet.requestedHeight = height;
   spreadsheet.requestedWidth = width;

   if (typeof node == "string") node = document.getElementById(node);

   if (node == null) {
      alert("SocialCalc.SpreadsheetControl not given parent node.");
      }

   spreadsheet.parentNode = node;

   // create node to hold spreadsheet control

   spreadsheet.spreadsheetDiv = document.createElement("div");

   spreadsheet.SizeSSDiv();

   for (child=node.firstChild; child!=null; child=node.firstChild) {
       node.removeChild(child);
   }

   spreadsheet.spreadsheetDiv.innerHTML = "<div></div>";

   node.appendChild(spreadsheet.spreadsheetDiv);

   spreadsheet.editorDiv=spreadsheet.editor.CreateTableEditor(spreadsheet.width, spreadsheet.height-spreadsheet.spreadsheetDiv.firstChild.offsetHeight);
   spreadsheet.editorDiv.className = "socialcalc-spreadsheet-editor";
   spreadsheet.spreadsheetDiv.appendChild(spreadsheet.editorDiv);

   for (vname in views) {
      html = views[vname].html;
      html = html.replace(/\%s\./g, "SocialCalc.");
      html = html.replace(/\%id\./g, spreadsheet.idPrefix);
      html = html.replace(/\%tbt\./g, spreadsheet.toolbartext);
      v = document.createElement("div");
      v.style.display = "none";
      v.style.width = spreadsheet.width + "px";
      v.style.height = spreadsheet.height-spreadsheet.spreadsheetDiv.firstChild.offsetHeight + "px";

      v.innerHTML = html;
      spreadsheet.spreadsheetDiv.appendChild(v);
      views[vname].element = v;
      }

   views.sheet = {name: "sheet", element: spreadsheet.editorDiv};

   spreadsheet.editor.SchedulePositionCalculations();

   return;

}

SocialCalc.GetSpreadsheetControlObject = function() {

   var csco = SocialCalc.CurrentSpreadsheetControlObject;
   if (csco) return csco;

   throw ("No current SpreadsheetControl object.");

}

SocialCalc.SizeSSDiv = function(spreadsheet) {

   var sizes, pos, resized, nodestyle, newval;

   resized = false;

   sizes = SocialCalc.GetViewportInfo();
   pos = SocialCalc.GetElementPosition(spreadsheet.parentNode);
   pos.bottom = 0;

   nodestyle = spreadsheet.parentNode.style;

   if (nodestyle.marginTop) {
      pos.top += nodestyle.marginTop.slice(0,-2)-0;
      }
   if (nodestyle.marginBottom) {
      pos.bottom += nodestyle.marginBottom.slice(0,-2)-0;
      }

   newval = spreadsheet.requestedHeight || sizes.height - pos.top - pos.bottom - 10;
   if (spreadsheet.height != newval) {
      spreadsheet.height = newval;
      spreadsheet.spreadsheetDiv.style.height = newval + "px";
      resized = true;
      }
   newval = spreadsheet.requestedWidth || spreadsheet.parentNode.offsetWidth || 700;
   if (spreadsheet.width != newval) {
      spreadsheet.width = newval;
      spreadsheet.spreadsheetDiv.style.width = newval + "px";
      resized = true;
      }

   return resized;

}

SocialCalc.FullRefreshAndRender = function(spreadsheet) {

   spreadsheet.context.CalculateCellSkipData();
   spreadsheet.editor.FitToEditTable();
   spreadsheet.context.PrecomputeSheetFontsAndLayouts();
   spreadsheet.context.CalculateColWidthData();
   spreadsheet.editor.EditorRenderSheet();
   spreadsheet.editor.SchedulePositionCalculations();
   if (spreadsheet.sheet.attribs.needsrecalc && spreadsheet.editor.recalcFunction) {
      spreadsheet.editor.recalcFunction(spreadsheet.editor);
   }

}

SocialCalc.SetTab = function(obj) {

   var newtab, tname, newtabnum, i, vname, ele;
   var menutabs = {};
   var tools = {};
   var spreadsheet = SocialCalc.GetSpreadsheetControlObject();
   var tabs = spreadsheet.tabs;
   var views = spreadsheet.views;

   if (typeof obj == "string") {
      newtab = obj;
      }
   else {
      newtab = obj.id.slice(spreadsheet.idPrefix.length,-3);
      }

   if (spreadsheet.currentTab != -1 && spreadsheet.tabs[spreadsheet.currentTab].onunclick) {
      spreadsheet.tabs[spreadsheet.currentTab].onunclick(spreadsheet, spreadsheet.tabs[spreadsheet.currentTab].name);
      }

   for (i=0; i<tabs.length; i++) {
      tname = tabs[i].name;
      menutabs[tname] = document.getElementById(spreadsheet.idPrefix+tname+"tab");
      tools[tname] = document.getElementById(spreadsheet.idPrefix+tname+"tools");
      if (tname==newtab) {
         newtabnum = i;
         tools[tname].style.display = "block";
         menutabs[tname].className = "socialcalc-spreadsheet-tabselected";
         }
      else {
         tools[tname].style.display = "none";
         menutabs[tname].className = "socialcalc-spreadsheet-tabplain";
         }
      }

   spreadsheet.currentTab = newtabnum;

   if (tabs[newtabnum].onclick) {
      tabs[newtabnum].onclick(spreadsheet, newtab);
      }

   for (vname in views) {
      if ((!tabs[newtabnum].view && vname == "sheet") || tabs[newtabnum].view == vname) {
         views[vname].element.style.display = "block";
         }
      else {
         views[vname].element.style.display = "none";
         }
      }

   if (tabs[newtabnum].onclickFocus) {
      ele = tabs[newtabnum].onclickFocus;
      if (typeof ele == "string") {
         ele = document.getElementById(spreadsheet.idPrefix+ele);
         ele.focus();
         }
      SocialCalc.CmdGotFocus(ele);
      }
   else {
      SocialCalc.KeyboardFocus();
      }

   return;

}

//
// SocialCalc.UpdateSortRangeProposal(editor)
//
// Updates sort range proposed in the UI in element idPrefix+sortlist
//

SocialCalc.UpdateSortRangeProposal = function(editor) {

   var ele = document.getElementById(SocialCalc.GetSpreadsheetControlObject().idPrefix+"sortlist");
   if (editor.range.hasrange) {
      ele.options[0].text = SocialCalc.crToCoord(editor.range.left, editor.range.top) + ":" +
                            SocialCalc.crToCoord(editor.range.right, editor.range.bottom);
      }
   else {
      ele.options[0].text = "[select range]";
      }

   }

//
// SocialCalc.LoadColumnChoosers(spreadsheet)
//
// Updates list of columns for choosing which to sort for Major, Minor, and Last sort
//

SocialCalc.LoadColumnChoosers = function(spreadsheet) {

   var sortrange, nrange, rparts, col, colname, sele;

   if (spreadsheet.sortrange && spreadsheet.sortrange.indexOf(":")==-1) { // sortrange is a named range
      nrange = SocialCalc.Formula.LookupName(spreadsheet.sheet, spreadsheet.sortrange || "");
      if (nrange.type == "range") {
         rparts = nrange.value.match(/^(.*)\|(.*)\|$/);
         sortrange = rparts[1] + ":" + rparts[2];
         }
      else {
         sortrange = "A1:A1";
         }
      }
   else {
      sortrange = spreadsheet.sortrange;
      }
   var range = SocialCalc.ParseRange(sortrange);
   sele = document.getElementById(spreadsheet.idPrefix+"majorsort");
   sele.options.length = 0;
   sele.options[sele.options.length] = new Option("[none]", "");
   for (var col=range.cr1.col; col<=range.cr2.col; col++) {
      colname = SocialCalc.rcColname(col);
      sele.options[sele.options.length] = new Option("Column "+colname, colname);
      }
   sele.selectedIndex = 1;
   sele = document.getElementById(spreadsheet.idPrefix+"minorsort");
   sele.options.length = 0;
   sele.options[sele.options.length] = new Option("[none]", "");
   for (var col=range.cr1.col; col<=range.cr2.col; col++) {
      colname = SocialCalc.rcColname(col);
      sele.options[sele.options.length] = new Option(colname, colname);
      }
   sele.selectedIndex = 0;
   sele = document.getElementById(spreadsheet.idPrefix+"lastsort");
   sele.options.length = 0;
   sele.options[sele.options.length] = new Option("[none]", "");
   for (var col=range.cr1.col; col<=range.cr2.col; col++) {
      colname = SocialCalc.rcColname(col);
      sele.options[sele.options.length] = new Option(colname, colname);
      }
   sele.selectedIndex = 0;

   }

//
// SocialCalc.CmdGotFocus(obj)
//
// Sets SocialCalc.Keyboard.passThru: obj should be element with focus or "true"
//

SocialCalc.CmdGotFocus = function(obj) {

   SocialCalc.Keyboard.passThru = obj;

   }


//
// SocialCalc.DoCmd(obj, which)
//
// xxx
//

SocialCalc.DoCmd = function(obj, which) {

   var combostr, sstr, cl, i, clele, slist, slistele, str, sele, rele, lele, ele, sortrange, nrange, rparts;

   var spreadsheet = SocialCalc.GetSpreadsheetControlObject();
   var editor = spreadsheet.editor;

   which = which.substring(spreadsheet.idPrefix); // remove prefix

   switch (which) {
      case "undo":
         spreadsheet.sheet.SheetUndo();
         break;

      case "redo":
         spreadsheet.sheet.SheetRedo();
         break;

      case "fill-rowcolstuff":
      case "fill-text":
         cl = which.substring(5);
         clele = document.getElementById(spreadsheet.idPrefix+cl+"list");
         clele.length = 0;
         for (i=0; i<SocialCalc.SpreadsheetCmdTable[cl].length; i++) {
            clele.options[i] = new Option(SocialCalc.SpreadsheetCmdTable[cl][i].t);
            }
         which = "changed-"+cl; // fall through to changed code

      case "changed-rowcolstuff":
      case "changed-text":
         cl = which.substring(8);
         clele = document.getElementById(spreadsheet.idPrefix+cl+"list");
         slist = SocialCalc.SpreadsheetCmdTable.slists[SocialCalc.SpreadsheetCmdTable[cl][clele.selectedIndex].s]; // get sList for this command
         slistele = document.getElementById(spreadsheet.idPrefix+cl+"slist");
         slistele.length = 0; // reset
         for (i=0; i<(slist.length||0); i++) {
            slistele.options[i] = new Option(slist[i].t, slist[i].s);
            }
         return; // nothing else to do

      case "ok-rowcolstuff":
      case "ok-text":
         cl = which.substring(3);
         clele = document.getElementById(spreadsheet.idPrefix+cl+"list");
         slistele = document.getElementById(spreadsheet.idPrefix+cl+"slist");
         combostr = SocialCalc.SpreadsheetCmdTable[cl][clele.selectedIndex].c;
         sstr = slistele[slistele.selectedIndex].value;
         SocialCalc.SpreadsheetControlExecuteCommand(obj, combostr, sstr);
         break;

      case "ok-setsort":
         lele = document.getElementById(spreadsheet.idPrefix+"sortlist");
         if (lele.selectedIndex==0) {
            if (editor.range.hasrange) {
               spreadsheet.sortrange = SocialCalc.crToCoord(editor.range.left, editor.range.top) + ":" +
                          SocialCalc.crToCoord(editor.range.right, editor.range.bottom);
               }
            else {
               spreadsheet.sortrange = editor.ecell.coord+":"+editor.ecell.coord;
               }
            }
         else {
            spreadsheet.sortrange = lele.options[lele.selectedIndex].value;
            }
         ele = document.getElementById(spreadsheet.idPrefix+"sortbutton");
         ele.value = "Sort "+spreadsheet.sortrange;
         ele.style.visibility = "visible";
         SocialCalc.LoadColumnChoosers(spreadsheet);
         if (obj && obj.blur) obj.blur();
         SocialCalc.KeyboardFocus();   
         return;

      case "dosort":
         if (spreadsheet.sortrange && spreadsheet.sortrange.indexOf(":")==-1) { // sortrange is a named range
            nrange = SocialCalc.Formula.LookupName(spreadsheet.sheet, spreadsheet.sortrange || "");
            if (nrange.type != "range") return;
            rparts = nrange.value.match(/^(.*)\|(.*)\|$/);
            sortrange = rparts[1] + ":" + rparts[2];
            }
         else {
            sortrange = spreadsheet.sortrange;
            }
         if (sortrange == "A1:A1") return;
         str = "sort "+sortrange+" ";
         sele = document.getElementById(spreadsheet.idPrefix+"majorsort");
         rele = document.getElementById(spreadsheet.idPrefix+"majorsortup");
         str += sele.options[sele.selectedIndex].value + (rele.checked ? " up" : " down");
         sele = document.getElementById(spreadsheet.idPrefix+"minorsort");
         if (sele.selectedIndex>0) {
           rele = document.getElementById(spreadsheet.idPrefix+"minorsortup");
           str += " "+sele.options[sele.selectedIndex].value + (rele.checked ? " up" : " down");
           }
         sele = document.getElementById(spreadsheet.idPrefix+"lastsort");
         if (sele.selectedIndex>0) {
           rele = document.getElementById(spreadsheet.idPrefix+"lastsortup");
           str += " "+sele.options[sele.selectedIndex].value + (rele.checked ? " up" : " down");
           }
         spreadsheet.ExecuteCommand(str, "");
         break;

      case "merge":
         combostr = SocialCalc.SpreadsheetCmdLookup[which] || "";
         sstr = SocialCalc.SpreadsheetCmdSLookup[which] || "";
         spreadsheet.ExecuteCommand(combostr, sstr);
         if (editor.range.hasrange) { // set ecell to upper left
            editor.MoveECell(SocialCalc.crToCoord(editor.range.left, editor.range.top));
            editor.RangeRemove();
            }
         break;

      default:
         combostr = SocialCalc.SpreadsheetCmdLookup[which] || "";
         sstr = SocialCalc.SpreadsheetCmdSLookup[which] || "";
         spreadsheet.ExecuteCommand(combostr, sstr);
         break;
      }

   spreadsheet.FullRefreshAndRender();

   if (obj && obj.blur) obj.blur();
   SocialCalc.KeyboardFocus();   

   }

SocialCalc.SpreadsheetCmdLookup = {
 'copy': 'copy %C all',
 'paste': 'paste %C all',
 'filldown': 'filldown %C all',
 'fillright': 'fillright %C all',
 'erase': 'erase %C all',
 'borderon': 'set %C bt %S%Nset %C br %S%Nset %C bb %S%Nset %C bl %S',
 'borderoff': 'set %C bt %S%Nset %C br %S%Nset %C bb %S%Nset %C bl %S',
 'merge': 'merge %C',
 'unmerge': 'unmerge %C',
 'rev-on': 'set %C font normal bold * *%Nset %C color rgb(255,255,255)%Nset %C bgcolor rgb(0,0,0)',
 'rev-off': 'set %C font%Nset %C color%Nset %C bgcolor',
 'wiki-on': 'set %C textvalueformat text-wiki',
 'wiki-off': 'set %C textvalueformat',
 'align-left': 'set %C cellformat left',
 'align-center': 'set %C cellformat center',
 'align-right': 'set %C cellformat right',
 'align-default': 'set %C cellformat'
 }

SocialCalc.SpreadsheetCmdSLookup = {
 'borderon': '1px solid rgb(0,0,0)',
 'borderoff': ''
 }

SocialCalc.SpreadsheetCmdTable = {
 cmd: [
  {t:"Fill Right", s:"ffal", c:"fillright %C %S"},
  {t:"Fill Down", s:"ffal", c:"filldown %C %S"},
  {t:"Copy", s:"all", c:"copy %C %S"},
  {t:"Cut", s:"all", c:"cut %C %S"},
  {t:"Paste", s:"ffal", c:"paste %C %S"},
  {t:"Erase", s:"ffal", c:"erase %C %S"},
  {t:"Insert", s:"rowcol", c:"insert%S %C"},
  {t:"Delete", s:"rowcol", c:"delete%S %C"},
  {t:"Merge Cells", s:"none", c:"merge %C"},
  {t:"Unmerge", s:"none", c:"unmerge %C"},
  {t:"Sort", s:"sortcol", c:"sort %R %S"},
  {t:"Cell Color", s:"colors", c:"set %C color %S"},
  {t:"Cell Background", s:"colors", c:"set %C bgcolor %S"},
  {t:"Cell Number Format", s:"ntvf", c:"set %C nontextvalueformat %S"},
  {t:"Cell Font", s:"fonts", c:"set %C font %S"},
  {t:"Cell Align", s:"cellformat", c:"set %C cellformat %S"},
  {t:"Cell Borders", s:"borderOnOff", c:"set %C bt %S%Nset %C br %S%Nset %C bb %S%Nset %C bl %S"},
  {t:"Column Width", s:"colWidths", c:"set %W width %S"},
  {t:"Default Color", s:"colors", c:"set sheet defaultcolor %S"},
  {t:"Default Background", s:"colors", c:"set sheet defaultbgcolor %S"},
  {t:"Default Number Format", s:"ntvf", c:"set sheet defaultnontextvalueformat %S"},
  {t:"Default Font", s:"fonts", c:"set sheet defaultfont %S"},
  {t:"Default Text Align", s:"cellformat", c:"set sheet defaulttextformat %S"},
  {t:"Default Number Align", s:"cellformat", c:"set sheet defaultnontextformat %S"},
  {t:"Default Column Width", s:"colWidths", c:"set sheet defaultcolwidth %S"}
  ],
 rowcolstuff: [
  {t:"Insert", s:"rowcol", c:"insert%S %C"},
  {t:"Delete", s:"rowcol", c:"delete%S %C"},
  {t:"Column Width", s:"colWidths", c:"set %W width %S"},
  {t:"Default Col Width", s:"colWidths", c:"set sheet defaultcolwidth %S"},
  {t:"Paste", s:"ffal", c:"paste %C %S"},
  {t:"Erase", s:"ffal", c:"erase %C %S"},
  {t:"Fill Right", s:"ffal", c:"fillright %C %S"},
  {t:"Fill Down", s:"ffal", c:"filldown %C %S"}
  ],
 text: [
  {t:"Cell Color", s:"colors", c:"set %C color %S"},
  {t:"Cell Background", s:"colors", c:"set %C bgcolor %S"},
  {t:"Cell Number Format", s:"ntvf", c:"set %C nontextvalueformat %S"},
  {t:"Cell Text Format", s:"tvf", c:"set %C textvalueformat %S"},
  {t:"Cell Font", s:"fonts", c:"set %C font %S"},
  {t:"Cell Align", s:"cellformat", c:"set %C cellformat %S"},
  {t:"Default Color", s:"colors", c:"set sheet defaultcolor %S"},
  {t:"Default Background", s:"colors", c:"set sheet defaultbgcolor %S"},
  {t:"Default Number Format", s:"ntvf", c:"set sheet defaultnontextvalueformat %S"},
  {t:"Default Text Format", s:"tvf", c:"set sheet defaulttextvalueformat %S"},
  {t:"Default Font", s:"fonts", c:"set sheet defaultfont %S"},
  {t:"Default Text Align", s:"cellformat", c:"set sheet defaulttextformat %S"},
  {t:"Default Number Align", s:"cellformat", c:"set sheet defaultnontextformat %S"}
  ],
 slists: {
  "colors": [
   {t:"Default", s:""},
   {t:"Black", s:"rgb(0,0,0)"},
   {t:"Dark Gray", s:"rgb(102,102,102)"}, // #666
   {t:"Gray", s:"rgb(204,204,204)"}, // #CCC
   {t:"White", s:"rgb(255,255,255)"},
   {t:"Red", s:"rgb(255,0,0)"},
   {t:"Dark Red", s:"rgb(153,0,0)"},
   {t:"Orange", s:"rgb(255,153,0)"},
   {t:"Yellow", s:"rgb(255,255,0)"},
   {t:"Light Yellow", s:"rgb(255,255,204)"},
   {t:"Green", s:"rgb(0,255,0)"},
   {t:"Dark Green", s:"rgb(0,153,0)"},
   {t:"Blue", s:"rgb(0,0,255)"},
   {t:"Dark Blue", s:"rgb(0,0,153)"},
   {t:"Light Blue", s:"rgb(204,204,255)"}
   ],
  "fonts": [ // style weight size family
   {t:"Default", s:""},
   {t:"Bold", s:"normal bold * *"},
   {t:"Italic", s:"italic normal * *"},
   {t:"Small", s:"* small *"},
   {t:"Medium", s:"* medium *"},
   {t:"Large", s:"* large *"},
   {t:"Bold Small", s:"normal bold small *"},
   {t:"Bold Medium", s:"normal bold medium *"},
   {t:"Bold Large", s:"normal bold large *"}
   ],
  "cellformat": [
   {t:"Default", s:""},
   {t:"Left", s:"left"},
   {t:"Right", s:"right"},
   {t:"Center", s:"center"}
   ],
  "borderOnOff": [
   {t:"On", s:"1px solid rgb(0,0,0)"},
   {t:"Off", s:""}
   ],
  "colWidths": [
   {t:"Default", s:""},
   {t:"20", s:"20"},
   {t:"40", s:"40"},
   {t:"60", s:"60"},
   {t:"80", s:"80"},
   {t:"100", s:"100"},
   {t:"120", s:"120"},
   {t:"140", s:"140"},
   {t:"160", s:"160"},
   {t:"180", s:"180"},
   {t:"200", s:"200"},
   {t:"220", s:"220"},
   {t:"240", s:"240"},
   {t:"260", s:"260"},
   {t:"280", s:"280"},
   {t:"300", s:"300"}
   ],
  "ntvf": [
   {t:"Default", s:""},
   {t:"1234", s:"0"},
   {t:"1,234", s:"#,##0"},
   {t:"1,234.5", s:"#,##0.0"},
   {t:"1,234.56", s:"#,##0.00"},
   {t:"1,234.567", s:"#,##0.000"},
   {t:"1,234%", s:"#,##0%"},
   {t:"1,234.5%", s:"#,##0.0%"},
   {t:"(1,234)", s:"#,##0_);(#,##0)"},
   {t:"(1,234.5)", s:"#,##0.0_);(#,##0.0)"},
   {t:"(1,234.56)", s:"#,##0.00_);(#,##0.00)"},
   {t:"00", s:"00"},
   {t:"000", s:"000"},
   {t:"0000", s:"0000"},
   {t:"$1,234.56", s:"$#,##0.00"},
   {t:"2006-01-04", s:"yyyy-mm-dd"},
   {t:"01:23:45", s:"hh:mm:ss"},
   {t:"2006-01-04 01:23:45", s:"yyyy-mm-dd hh:mm:ss"},
   {t:"Hidden", s:"hidden"}
   ],
  "tvf": [
   {t:"Default", s:""},
   {t:"Automatic", s:"general"},
   {t:"Plain Text", s:"text-plain"},
   {t:"HTML", s:"text-html"},
   {t:"Wiki", s:"text-wiki"},
   {t:"Hidden", s:"hidden"}
   ],
  "ffal": [ // Formulas, Formats, All
   {t:"All", s:"all"},
   {t:"Contents", s:"formulas"},
   {t:"Formats", s:"formats"}
   ],
  "all": [ // All
   {t:"All", s:"all"}
   ],
  "rowcol": [
   {t:"Row", s:"row"},
   {t:"Column", s:"col"}
   ],
  "sortcol": [
   {t:"A up", s:"A up"},
   {t:"B up", s:"B up"},
   {t:"C up", s:"C up"},
   {t:"A down", s:"A down"},
   {t:"B down", s:"B down"},
   {t:"C down", s:"C down"},
   {t:"A, B, C up", s:"A up B up C up"}
   ],
  "none": [ // nothing
   {t:" ", s:" "}
   ]
  }
 }


//
// SocialCalc.SpreadsheetControlExecuteCommand(obj, combostr, sstr)
//
// xxx
//

SocialCalc.SpreadsheetControlExecuteCommand = function(obj, combostr, sstr) {

   var i, commands;
   var spreadsheet = SocialCalc.GetSpreadsheetControlObject();
   var eobj = spreadsheet.editor;

   var str = {};
   str.P = "%";
   str.N = "\n"
   if (eobj.range.hasrange) {
      str.R = SocialCalc.crToCoord(eobj.range.left, eobj.range.top)+
             ":"+SocialCalc.crToCoord(eobj.range.right, eobj.range.bottom);
      str.C = str.R;
      str.W = SocialCalc.rcColname(eobj.range.left) + ":" + SocialCalc.rcColname(eobj.range.right);
      }
   else {
      str.C = eobj.ecell.coord;
      str.R = eobj.ecell.coord+":"+eobj.ecell.coord;
      str.W = SocialCalc.rcColname(SocialCalc.coordToCr(eobj.ecell.coord).col);
      }
   str.S = sstr;
   combostr = combostr.replace(/%C/g, str.C);
   combostr = combostr.replace(/%R/g, str.R);
   combostr = combostr.replace(/%N/g, str.N);
   combostr = combostr.replace(/%S/g, str.S);
   combostr = combostr.replace(/%W/g, str.W);
   combostr = combostr.replace(/%P/g, str.P);

   spreadsheet.sheet.ExecuteSheetCommand(combostr, true);

   }

//
// result = SocialCalc.SpreadsheetControlCreateSheetHTML(spreadsheet)
//
// Returns the HTML representation of the whole spreadsheet
//

SocialCalc.SpreadsheetControlCreateSheetHTML = function(spreadsheet) {

   var context, div, ele;

   var result = "";

   context = new SocialCalc.RenderContext(spreadsheet.sheet);
   context.CalculateCellSkipData();
   context.CalculateColWidthData();
   div = document.createElement("div");
   ele = context.RenderSheet(null, "html");
   div.appendChild(ele);
   delete context;
   result = div.innerHTML;
   delete ele;
   delete div;
   return result;

   }

//
// result = SocialCalc.SpreadsheetControlCreateCellHTML(spreadsheet, coord)
//
// Returns the HTML representation of a cell. Blank is "", not "&nbsp;".
//

SocialCalc.SpreadsheetControlCreateCellHTML = function(spreadsheet, coord) {

   var result = "";
   var cell = spreadsheet.sheet.cells[coord];

   if (!cell) return "";

   if (cell.displaystring == undefined) {
      result = SocialCalc.FormatValueForDisplay(spreadsheet.sheet, cell.datavalue, coord, "html");
      }
   else {
      result = cell.displaystring;
      }

   if (result == "&nbsp;") result = "";

   return result;

   }

//
// result = SocialCalc.SpreadsheetControlCreateCellHTMLSave(spreadsheet, range)
//
// Returns the HTML representation of a range of cells, or the whole sheet if range is null.
// The form is:
//    version:1.0
//    coord:cell-HTML
//    coord:cell-HTML
//    ...
//
// Empty cells are skipped. The cell-HTML is encoded with ":"=>"\c", newline=>"\n", and "\"=>"\".
//

SocialCalc.SpreadsheetControlCreateCellHTMLSave = function(spreadsheet, range) {

   var cr1, cr2, row, col, coord, cell, cellHTML;
   var result = [];
   var prange;

   if (range) {
      prange = SocialCalc.ParseRange(range);
      }
   else {
      prange = {cr1: {row: 1, col:1},
                cr2: {row: spreadsheet.sheet.attribs.lastrow, col: spreadsheet.sheet.attribs.lastcol}};
      }
   cr1 = prange.cr1;
   cr2 = prange.cr2;

   result.push("version:1.0");

   for (row=cr1.row; row <= cr2.row; row++) {
      for (col=cr1.col; col <= cr2.col; col++) {
         coord = SocialCalc.crToCoord(col, row);
         cell=spreadsheet.sheet.cells[coord];
         if (!cell) continue;
         if (cell.displaystring == undefined) {
            cellHTML = SocialCalc.FormatValueForDisplay(spreadsheet.sheet, cell.datavalue, coord, "html");
            }
         else {
            cellHTML = cell.displaystring;
            }
         if (cellHTML == "&nbsp;") continue;
         result.push(coord+":"+SocialCalc.encodeForSave(cellHTML));
         }
      }

   result.push(""); // one extra to get extra \n
   return result.join("\n");
   }

//
// TAB Routines
//

// Sort

SocialCalc.SpreadsheetControlSortOnclick = function(s, t) {

   var name, i;
   var namelist = [];
   var nl = document.getElementById(s.idPrefix+"sortlist");
   SocialCalc.LoadColumnChoosers(s);
   s.editor.RangeChangeCallback.sort = SocialCalc.UpdateSortRangeProposal;

   for (name in s.sheet.names) {
      namelist.push(name);
      }
   namelist.sort();
   nl.length = 0;
   nl.options[0] = new Option("[select range]");
   for (i=0; i<namelist.length; i++) {
      name = namelist[i];
      nl.options[i+1] = new Option(name, name);
      if (name == s.sortrange) {
         nl.options[i+1].selected = true;
         }
      }
   if (s.sortrange == "") {
      nl.options[0].selected = true;
      }

   SocialCalc.UpdateSortRangeProposal(s.editor);
   SocialCalc.KeyboardFocus();
   return;

   }

SocialCalc.SpreadsheetControlSortSave = function(s, setting) {
   // Format is:
   //    sort:sortrange:major-
//   return "sort:nothing to save at this time\n";
   return "";
   }

SocialCalc.SpreadsheetControlSortLoad = function(s, setting, line, flags) {
//   var parts;
//   parts = line.split(":");
//   alert(parts[1]);
   return true;
   }

// Comment

SocialCalc.SpreadsheetControlCommentOnclick = function(s, t) {
   s.editor.MoveECellCallback.comment = SocialCalc.SpreadsheetControlCommentMoveECell;
   SocialCalc.SpreadsheetControlCommentDisplay(s, t);
   SocialCalc.KeyboardFocus();
   return;
   }

SocialCalc.SpreadsheetControlCommentDisplay = function(s, t) {
   var c = "";
   if (s.editor.ecell && s.editor.ecell.coord && s.sheet.cells[s.editor.ecell.coord]) {
      c = s.sheet.cells[s.editor.ecell.coord].comment || "";
      }
   document.getElementById(s.idPrefix+"commenttext").value = c;
   }

SocialCalc.SpreadsheetControlCommentMoveECell = function(editor) {
   SocialCalc.SpreadsheetControlCommentDisplay(SocialCalc.GetSpreadsheetControlObject(), "comment");
   }

SocialCalc.SpreadsheetControlCommentSet = function() {
   var s=SocialCalc.GetSpreadsheetControlObject();
   s.ExecuteCommand("set %C comment "+SocialCalc.encodeForSave(document.getElementById(s.idPrefix+"commenttext").value));
   var cell=SocialCalc.GetEditorCellElement(s.editor, s.editor.ecell.row, s.editor.ecell.col);
   s.editor.UpdateCellCSS(cell, s.editor.ecell.row, s.editor.ecell.col);
   SocialCalc.KeyboardFocus();
   }

SocialCalc.SpreadsheetControlCommentOnunclick = function(s, t) {
   delete s.editor.MoveECellCallback.comment;
   }

// Names

SocialCalc.SpreadsheetControlNamesOnclick = function(s, t) {
   document.getElementById(s.idPrefix+"namesname").value = "";
   document.getElementById(s.idPrefix+"namesdesc").value = "";
   document.getElementById(s.idPrefix+"namesvalue").value = "";
   s.editor.RangeChangeCallback.names = SocialCalc.SpreadsheetControlNamesRangeChange;
   s.editor.MoveECellCallback.names = SocialCalc.SpreadsheetControlNamesRangeChange;
   SocialCalc.SpreadsheetControlNamesRangeChange(s.editor);
   SocialCalc.SpreadsheetControlNamesFillNameList();
   SocialCalc.SpreadsheetControlNamesChangedName();
   }

SocialCalc.SpreadsheetControlNamesFillNameList = function() {
   var name, i;
   var namelist = [];
   var s=SocialCalc.GetSpreadsheetControlObject();
   var nl = document.getElementById(s.idPrefix+"nameslist");
   var currentname = document.getElementById(s.idPrefix+"namesname").value.toUpperCase().replace(/[^A-Z0-9_\.]/g, "");
   for (name in s.sheet.names) {
      namelist.push(name);
      }
   namelist.sort();
   nl.length = 0;
   if (namelist.length > 0) {
      nl.options[0] = new Option("[New]");
      }
   else {
      nl.options[0] = new Option("[None]");
      }
   for (i=0; i<namelist.length; i++) {
      name = namelist[i];
      nl.options[i+1] = new Option(name, name);
      if (name == currentname) {
         nl.options[i+1].selected = true;
         }
      }
   if (currentname == "") {
      nl.options[0].selected = true;
      }
   }

SocialCalc.SpreadsheetControlNamesChangedName = function() {
   var s=SocialCalc.GetSpreadsheetControlObject();
   var nl = document.getElementById(s.idPrefix+"nameslist");
   var name = nl.options[nl.selectedIndex].value;
   if (s.sheet.names[name]) {
      document.getElementById(s.idPrefix+"namesname").value = name;
      document.getElementById(s.idPrefix+"namesdesc").value = s.sheet.names[name].desc || "";
      document.getElementById(s.idPrefix+"namesvalue").value = s.sheet.names[name].definition || "";
      }
   else {
      document.getElementById(s.idPrefix+"namesname").value = "";
      document.getElementById(s.idPrefix+"namesdesc").value = "";
      document.getElementById(s.idPrefix+"namesvalue").value = "";
      }
   }

SocialCalc.SpreadsheetControlNamesRangeChange = function(editor) {
   var s = SocialCalc.GetSpreadsheetControlObject();
   var ele = document.getElementById(s.idPrefix+"namesrangeproposal");
   if (editor.range.hasrange) {
      ele.value = SocialCalc.crToCoord(editor.range.left, editor.range.top) + ":" +
                            SocialCalc.crToCoord(editor.range.right, editor.range.bottom);
      }
   else {
      ele.value = editor.ecell.coord;
      }
   }

SocialCalc.SpreadsheetControlNamesOnunclick = function(s, t) {
   delete s.editor.RangeChangeCallback.names;
   delete s.editor.MoveECellCallback.names;
   }

SocialCalc.SpreadsheetControlNamesSetValue = function() {
   var s = SocialCalc.GetSpreadsheetControlObject();
   document.getElementById(s.idPrefix+"namesvalue").value = document.getElementById(s.idPrefix+"namesrangeproposal").value;
   SocialCalc.KeyboardFocus();
   }

SocialCalc.SpreadsheetControlNamesSave = function() {
   var s = SocialCalc.GetSpreadsheetControlObject();
   var name = document.getElementById(s.idPrefix+"namesname").value;
   if (name != "") {
      s.ExecuteCommand("name define "+name+" "+document.getElementById(s.idPrefix+"namesvalue").value+"\n"+
         "name desc "+name+" "+document.getElementById(s.idPrefix+"namesdesc").value);
      SocialCalc.SpreadsheetControlNamesFillNameList();
      }
   s.sheet.RecalcSheet();
   s.FullRefreshAndRender();
   SocialCalc.SetTab(s.tabs[0].name); // return to first tab
   SocialCalc.KeyboardFocus();
   }

SocialCalc.SpreadsheetControlNamesDelete = function() {
   var s = SocialCalc.GetSpreadsheetControlObject();
   var name = document.getElementById(s.idPrefix+"namesname").value;
   if (name != "") {
      s.ExecuteCommand("name delete "+name);
      document.getElementById(s.idPrefix+"namesname").value = "";
      document.getElementById(s.idPrefix+"namesvalue").value = "";
      document.getElementById(s.idPrefix+"namesdesc").value = "";
      SocialCalc.SpreadsheetControlNamesFillNameList();
      }
   s.sheet.RecalcSheet();
   s.FullRefreshAndRender();
   SocialCalc.KeyboardFocus();
   }

// Clipboard

SocialCalc.SpreadsheetControlClipboardOnclick = function(s, t) {
   var s = SocialCalc.GetSpreadsheetControlObject();
   clipele = document.getElementById(s.idPrefix+"clipboardtext");
   clipele.value = SocialCalc.ConvertSaveToOtherFormat(SocialCalc.Clipboard.clipboard, "tab");
   return;
   }

SocialCalc.SpreadsheetControlClipboardLoad = function() {
   var s = SocialCalc.GetSpreadsheetControlObject();
   s.sheet.ExecuteSheetCommand("loadclipboard "+
      SocialCalc.encodeForSave(
         SocialCalc.ConvertOtherFormatToSave(document.getElementById(s.idPrefix+"clipboardtext").value, "tab")), true);
   SocialCalc.SetTab(s.tabs[0].name); // return to first tab
   SocialCalc.KeyboardFocus();
   }

SocialCalc.SpreadsheetControlClipboardClear = function() {
   var s = SocialCalc.GetSpreadsheetControlObject();
   var clipele = document.getElementById(s.idPrefix+"clipboardtext");
   clipele.value = "";
   s.sheet.ExecuteSheetCommand("clearclipboard", true);
   clipele.focus();
   }

SocialCalc.SpreadsheetControlClipboardExport = function() {
   var s = SocialCalc.GetSpreadsheetControlObject();
   if (s.ExportCallback) {
      s.ExportCallback(s);
      }
   SocialCalc.SetTab(s.tabs[0].name); // return to first tab
   SocialCalc.KeyboardFocus();
   }

SocialCalc.SpreadsheetControlCreateSpreadsheetSave = function(spreadsheet) {

   var result;

   result = "socialcalc:version:1.0\n" +
      "MIME-Version: 1.0\nContent-Type: multipart/mixed; boundary="+
      spreadsheet.multipartBoundary + "\n" +
      "--" + spreadsheet.multipartBoundary + "\nContent-type: text/plain; charset=UTF-8\n\n" +
      "# SocialCalc Spreadsheet Control Save\nversion:1.0\npart:sheet\npart:edit\npart:audit\n" +
      "--" + spreadsheet.multipartBoundary + "\nContent-type: text/plain; charset=UTF-8\n\n" +
      spreadsheet.CreateSheetSave() +
      "--" + spreadsheet.multipartBoundary + "\nContent-type: text/plain; charset=UTF-8\n\n" +
      spreadsheet.editor.SaveEditorSettings() +
      "--" + spreadsheet.multipartBoundary + "\nContent-type: text/plain; charset=UTF-8\n\n" +
      spreadsheet.sheet.CreateAuditString() +
      "--" + spreadsheet.multipartBoundary + "--\n";

   return result;

   }


SocialCalc.SpreadsheetControlDecodeSpreadsheetSave = function(spreadsheet, str) {

   var pos1, mpregex, searchinfo, boundary, boundaryregex, blanklineregex, start, ending, lines, i, lines, p, pnun;
   var parts = {};
   var partlist = [];

   pos1 = str.search(/^MIME-Version:\s1\.0/mi);
   if (pos1 < 0) return parts;

   mpregex = /^Content-Type:\s*multipart\/mixed;\s*boundary=(\S+)/mig;
   mpregex.lastIndex = pos1;

   searchinfo = mpregex.exec(str);
   if (mpregex.lastIndex <= 0) return parts;
   boundary = searchinfo[1];

   boundaryregex = new RegExp("^--"+boundary+"$", "mg");
   boundaryregex.lastIndex = mpregex.lastIndex;

   searchinfo = boundaryregex.exec(str); // find header top boundary
   blanklineregex = /^$/gm;
   blanklineregex.lastIndex = boundaryregex.lastIndex;
   searchinfo = blanklineregex.exec(str); // skip to after blank line
   if (!searchinfo) return parts;
   start = blanklineregex.lastIndex;
   boundaryregex.lastIndex = start;
   searchinfo = boundaryregex.exec(str); // find end of header
   if (!searchinfo) return parts;
   ending = searchinfo.index;

   lines = str.substring(start, ending).split(/\r\n|\n/); // get header as lines
   for (i=0;i<lines.length;i++) {
      line=lines[i];
      p = line.split(":");
      switch (p[0]) {
         case "version":
            break;
         case "part":
            partlist.push(p[1]);
            break;
         }
      }

   for (pnum=0; pnum<partlist.length; pnum++) { // get each part
      blanklineregex.lastIndex = ending;
      searchinfo = blanklineregex.exec(str); // find blank line ending mime-part header
      if (!searchinfo) return parts;
      start = blanklineregex.lastIndex;
      if (pnum==partlist.length-1) { // last one has different boundary
         boundaryregex = new RegExp("^--"+boundary+"--$", "mg");
         }
      boundaryregex.lastIndex = start;
      searchinfo = boundaryregex.exec(str); // find ending boundary
      if (!searchinfo) return parts;
      ending = searchinfo.index;
      parts[partlist[pnum]] = {start: start, end: ending}; // return position within full string
      }

   return parts;

}

})();





