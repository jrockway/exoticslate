var t = new Test.Wikiwyg();

t.plan(5);

t.run_roundtrip('wikitext');

/* Test
=== Simple Indented stuff
--- ONLY
--- wikitext
> one
> two
> three
> four

=== Indented list
--- XXX
This works for the wrong reason. This is not an indented list but an
indented paragraph whose lines begin with '*'. The server side formatter
needs to be fixed.
--- wikitext
> * one
> * two

=== Nested Indented stuff
--- wikitext
> one
>> two
> three

=== More nested Indented stuff
--- wikitext
> one
>>>>> two
>>>> three
>>>>>>> four

=== Bug from corp dff-test
--- wikitext
Hi all:

> one -- [link]
>> two

*/
