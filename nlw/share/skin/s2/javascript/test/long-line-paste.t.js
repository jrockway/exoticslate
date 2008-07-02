// From https://uj-trac.socialtext.net:447/trac/ticket/232
var t = new Test.Wikiwyg();

var filters = {
    html: ['html_to_wikitext']
};

if (Wikiwyg.is_gecko) {
    t.plan(1);
    t.filters(filters);
    t.run_is('html', 'text');
}
else {
    t.skipAll("On non-gecko browsers.")
}

/* Test
=== bz: 552 description
--- html
aaaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbbb cccccccccccccccc dddddddddddddd eeeeeeeeeeeeeeee ffffffffffff gggggggggggggggg hhhhhhhhhhhhhh iiiiiiiiiiiii kkkkkkkkkkkkkkkkk jjjjjjjjjjjjjjjjjjjjjj<br class="p">aaaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbbb cccccccccccccccc dddddddddddddd
eeeeeeeeeeeeeeee ffffffffffff gggggggggggggggg hhhhhhhhhhhhhh
iiiiiiiiiiiii kkkkkkkkkkkkkkkkk jjjjjjjjjjjjjjjjjjjjjj<br class="p">
<br>
--- text
aaaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbbb cccccccccccccccc dddddddddddddd eeeeeeeeeeeeeeee ffffffffffff gggggggggggggggg hhhhhhhhhhhhhh iiiiiiiiiiiii kkkkkkkkkkkkkkkkk jjjjjjjjjjjjjjjjjjjjjj
aaaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbbb cccccccccccccccc dddddddddddddd eeeeeeeeeeeeeeee ffffffffffff gggggggggggggggg hhhhhhhhhhhhhh iiiiiiiiiiiii kkkkkkkkkkkkkkkkk jjjjjjjjjjjjjjjjjjjjjj

=== long
--- html
<div class="wiki">Elit tation ipsum dolore aliquam enim dolor accumsan? Esse duis nibh commodo at nulla veniam facilisi tation erat nisl exerci duis euismod eros. Aliquip sed suscipit aliquip ut aliquam sit augue duis at consectetuer. Lobortis autem, duis ea et nibh. Dolor; laoreet zzril, iriure euismod veniam. Zzril veniam vero in blandit lorem. Dignissim feugait enim vero autem zzril amet diam. Suscipit aliquam tincidunt magna feugait consequat adipiscing exerci, feugiat nulla iusto tincidunt!<br class="p"><br class="p">
Elit tation ipsum dolore aliquam enim dolor accumsan? Esse duis nibh
commodo at nulla veniam facilisi tation erat nisl exerci duis euismod
eros. Aliquip sed suscipit aliquip ut aliquam sit augue duis at
consectetuer. Lobortis autem, duis ea et nibh. Dolor; laoreet zzril,
iriure euismod veniam. Zzril veniam vero in blandit lorem. Dignissim
feugait enim vero autem zzril amet diam. Suscipit aliquam tincidunt
magna feugait consequat adipiscing exerci, feugiat nulla iusto
tincidunt!<br class="p"><br class="p">
<br></div>
--- text
Elit tation ipsum dolore aliquam enim dolor accumsan? Esse duis nibh commodo at nulla veniam facilisi tation erat nisl exerci duis euismod eros. Aliquip sed suscipit aliquip ut aliquam sit augue duis at consectetuer. Lobortis autem, duis ea et nibh. Dolor; laoreet zzril, iriure euismod veniam. Zzril veniam vero in blandit lorem. Dignissim feugait enim vero autem zzril amet diam. Suscipit aliquam tincidunt magna feugait consequat adipiscing exerci, feugiat nulla iusto tincidunt!

Elit tation ipsum dolore aliquam enim dolor accumsan? Esse duis nibh commodo at nulla veniam facilisi tation erat nisl exerci duis euismod eros. Aliquip sed suscipit aliquip ut aliquam sit augue duis at consectetuer. Lobortis autem, duis ea et nibh. Dolor; laoreet zzril, iriure euismod veniam. Zzril veniam vero in blandit lorem. Dignissim feugait enim vero autem zzril amet diam. Suscipit aliquam tincidunt magna feugait consequat adipiscing exerci, feugiat nulla iusto tincidunt!

*/

