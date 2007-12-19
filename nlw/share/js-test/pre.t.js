var t = new Test.Wikiwyg();

t.plan(2);

t.run_roundtrip('wikitext');

/* Test
=== Big formatting pre blocks
--- wikitext
.pre
once
   there
       was
         something true
           note
          that
        you
    can       edit
 this  in    wy si wyg
        mode.
     ----- __@       __@       __@        __@       _~@
    ---- _`\<,_    _`\<,_    _`\<,_     _`\<,_    _`\<,_
   ---- (*)/ (*)  (*)/ (*)  (*)/ (*)  (*)/ (*)  (*)/ (*)
!@#$%^&*()_+-={}[]||;':",./<>?~`!@#$%^&*()_+-={}[]||;':",./<>?~`
.pre

.pre
&lt;some text between carets&gt;
.pre

&lt;some text between carets&gt;

=== Blank line before pre after two paragraphs
--- wikitext
Now

Lets

.pre
^^ open workspace
.pre

Our

*/
