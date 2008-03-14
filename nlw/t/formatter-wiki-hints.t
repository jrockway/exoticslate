#!perl
# @COPYRIGHT@
use warnings;
use strict;
use Test::Socialtext tests => 15;
fixtures( 'admin' );

no_diff;

my $hub = new_hub('admin');

my $page = $hub->pages->new_from_name('quick start');
my $attachment = $hub->attachments->new_attachment(
    page_id => $page->id,
    filename => 'socialtext-logo.gif',
);
$attachment->save('t/attachments/socialtext-logo-30.gif');
$attachment->store( user => $hub->current_user );

run {
    my $case = shift;

    is( $hub->viewer->text_to_html($case->wafl),
        $case->match,
        $case->name,
      );

    if ($case->disallow_html_wafl_match) {
        $hub->current_workspace->update( allows_html_wafl => 0 );
        is( $hub->viewer->text_to_html($case->wafl),
            $case->disallow_html_wafl_match,
            $case->name,
          );
        $hub->current_workspace->update( allows_html_wafl => 1 );
    }
}

__DATA__
=== rt wafl phrase
--- wafl
{rt 1166}
--- match
<div class="wiki">
<span class="nlw_phrase"><a href="http://rt.socialtext.net/Ticket/Display.html?id=1166">1166</a><!-- wiki: {rt: 1166} --></span><br /></div>

=== section wafl phrase
--- wafl
{section nasty boy}
--- match
<div class="wiki">
<span class="nlw_phrase"><a name="nasty_boy"><span class="ugly-ie-css-hack" style="display:none;">&nbsp;</span></a><!-- wiki: {section: nasty boy} --></span><br /></div>

=== image wafl phrase
--- SKIP attachment id changes with time
--- wafl
I like this image {image: [quick start] socialtext-logo.gif}. Do you?
--- match
<div class="wiki">
<p>
I like this image <span class="nlw_phrase"><img src="/data/workspaces/admin/attachments/quick_start:20050915000807-1/socialtext-logo.gif"><!-- wiki: {image: [quick start] socialtext-logo.gif} --></span>. Do you?<br />
</p>
</div>

=== link wafl phrase 
--- wafl
see admin: {link: admin [quick start]}
--- match
<div class="wiki">
<p>
see admin: <span class="nlw_phrase"><a title="inter-workspace link: admin" href="/admin/index.cgi?quick_start">quick start</a><!-- wiki: {link: admin [quick start]} --></span></p>
</div>

=== link wafl phrase no-exist
--- wafl
see admin: {link: admin [wiki 505]}
--- match
<div class="wiki">
<p>
see admin: <span class="nlw_phrase"><a title="inter-workspace link: admin" href="/admin/index.cgi?wiki%20505">wiki 505</a><!-- wiki: {link: admin [wiki 505]} --></span></p>
</div>

=== link wafl phrase no-perm
--- wafl
see dev-tasks: {link dev-tasks [theface guide]}
--- match
<div class="wiki">
<p>
see dev-tasks: <span class="nlw_phrase"><span class="wafl_permission_error">theface guide</span><!-- wiki: {link: dev-=tasks [theface guide]} --></span></p>
</div>

=== trademark wafl
--- wafl
Awesome {tm}
--- match
<div class="wiki">
<p>
Awesome <span class="nlw_phrase">&trade;<!-- wiki: {tm} --></span></p>
</div>

=== asis phrase
--- wafl
This is {{[not a link]}} you see?
--- match
<div class="wiki">
<p>
This is <span class="nlw_phrase">[not a link]<!-- wiki: {{[not a link]}} --></span> you see?</p>
</div>

=== pre wafl block
--- wafl
.pre
hello
    again
.pre
--- match
<div class="wiki">
<pre>
hello
    again
</pre>
</div>

=== html wafl block
--- wafl
.html
<h1>Your boot is best</h1>

<p>But mine is <span style="color: yellow">yellow</span></p>
.html
--- match
<div class="wiki">
<div class="wafl_block"><div>
  <h1>Your boot is best</h1>
  <p>But mine is <span style="color: yellow">yellow</span></p>
</div>
<!-- wiki:
.html
<h1>Your boot is best</h1>

<p>But mine is <span style=="color: yellow">yellow</span></p>
.html
--></div>
</div>
--- disallow_html_wafl_match
<div class="wiki">
<div class="wafl_block">&lt;h1&gt;Your boot is best&lt;/h1&gt;

&lt;p&gt;But mine is &lt;span style=&quot;color: yellow&quot;&gt;yellow&lt;/span&gt;&lt;/p&gt;
<!-- wiki:
.html
<h1>Your boot is best</h1>

<p>But mine is <span style=="color: yellow">yellow</span></p>
.html
--></div>
</div>

=== html wafl block with comments
--- wafl
.html
<!-- it's all lies -->
<h1>Your boot is best</h1>
.html
--- match
<div class="wiki">
<div class="wafl_block"><h1>Your boot is best</h1>
<!-- wiki:
.html
<!-=-= it's all lies -=-=>
<h1>Your boot is best</h1>
.html
--></div>
</div>

=== relative urls
--- wafl
http:index.cgi
--- match
<div class="wiki">
<p>
<span class="nlw_phrase"><a target="_blank" title="(external link)" href="index.cgi">index.cgi</a><!-- wiki: http:index.cgi --></span></p>
</div>

=== bracketed relative urls
--- wafl
"home"<http:index.cgi>
--- match
<div class="wiki">
<p>
<span class="nlw_phrase"><a target="_blank" title="(external link)" href="index.cgi">home</a><!-- wiki: "home"<http:index.cgi> --></span></p>
</div>

=== wiki links (unhinted)
--- wafl
[People]
--- match
<div class="wiki">
<p>
<a href="index.cgi?people" >People</a></p>
</div>

=== renamed wiki links
--- wafl
"my todo list for today"[People]
--- match
<div class="wiki">
<p>
<a href="index.cgi?people" >my todo list for today<!-- wiki-renamed-link People --></a></p>
</div>
