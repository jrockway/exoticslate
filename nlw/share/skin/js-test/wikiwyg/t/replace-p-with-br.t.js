var t = new Test.Wikiwyg();

t.filters({
    p: ['replace_p_with_br']
});

t.plan(1);

// XXX: The result matches /bc/ when run under editor, but not under js-test!
t.run_is('p', 'br');

/* Test
=== {bz: 911}: Conver P to BR when inline div is present
--- p
<div class="wiki"><p>a</p><p><div/>b</p><p>c</p></div>
--- br
<div class="wiki">a<br class="p"><br class="p"><div/>b<br class="p"><br class="p">c<br class="p"><br class="p"></div>

*/
