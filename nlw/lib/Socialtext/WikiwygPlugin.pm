# @COPYRIGHT@
package Socialtext::WikiwygPlugin;
use strict;
use warnings;

our $VERSION = '0.10'; 

use base 'Socialtext::Plugin';

use Class::Field qw( const );
use Socialtext::Formatter;
use Socialtext::System;
use File::Path ();
use List::Util;
use Socialtext::File;

sub class_id { 'wikiwyg' }
const cgi_class => 'Socialtext::Wikiwyg::CGI';
const class_title => 'Page Editing';

my $out_path = '/tmp/wikiwyg-' . $<;
my $test_list_override = "";
$test_list_override = join "\n", qw(
    blockquote_test_3
    blockquote_test_2
    blockquote_test_1
    formatting_test
);

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(action => 'wikiwyg_get_page_html2');
    $registry->add(action => 'wikiwyg_save_validation_result');
    $registry->add(action => 'wikiwyg_wikitext_to_html');
    $registry->add(action => 'wikiwyg_start_test');
    $registry->add(action => 'wikiwyg_get_page_html');
    $registry->add(action => 'wikiwyg_test_results');
    $registry->add(action => 'wikiwyg_test_runner');
    $registry->add(action => 'wikiwyg_all_page_ids');
    $registry->add(action => 'wikiwyg_start_validation');
    $registry->add(preference => $self->wikiwyg_double);
    $registry->add(wafl => wikiwyg_formatting_test =>
                   'Socialtext::Wikiwyg::FormattingTest');
    $registry->add(wafl => wikiwyg_formatting_test_run_all =>
                   'Socialtext::Wikiwyg::FormattingTestRunAll');
    $registry->add(wafl => wikiwyg_data_validator =>
                   'Socialtext::Wikiwyg::DataValidator');
}

sub wikiwyg_get_page_html2 {
    my $self = shift;
    my $page_id = $self->cgi->page_id;
    my $session_id = $self->cgi->session_id;

    # If the page id is null or empty throw a DataValidation Error
    unless ( defined $page_id && length $page_id ) {
        Socialtext::Exception::DataValidation->throw(
            errors => ['No page ID given'] );
    }

    # Get all the page ids for comparison against the inputted page id
    my @page_ids = sort$self->hub->pages->all_ids;

    # If the page id does not exist throw a DataValidation Error
    unless ( grep (/^$page_id$/,@page_ids)) {
        Socialtext::Exception::DataValidation->throw(
            errors => ["An invalid page ID was given: $page_id"] );
    }

    if (! -d "/tmp/wikiwyg_data_validation/$session_id") {
        Socialtext::Exception::DataValidation->throw(
          errors => ['Validation subroutine called outside of validator'] );
    }

    my $wikitext = $self->hub->pages->new_from_name($page_id)->content;
    my $html = $self->hub->viewer->text_to_html($wikitext);
    Socialtext::File::set_contents(
        "/tmp/wikiwyg_data_validation/$session_id/old/$page_id", $wikitext );

    return $html;
}

sub wikiwyg_save_validation_result {
    my $self = shift;
    my $wikitext = $self->cgi->content;
    my $page_id = $self->cgi->page_id;
    my $session_id = $self->cgi->session_id;
    Socialtext::File::set_contents(
        "/tmp/wikiwyg_data_validation/$session_id/new/$page_id", $wikitext );

    return "finished\n";
}

sub wikiwyg_start_validation {
    my $self = shift;
    my $session_id = time;
    mkdir("/tmp/wikiwyg_data_validation");
    mkdir("/tmp/wikiwyg_data_validation/$session_id");
    mkdir("/tmp/wikiwyg_data_validation/$session_id/old");
    mkdir("/tmp/wikiwyg_data_validation/$session_id/new");
    return $session_id;
}

sub wikiwyg_all_page_ids {
    my $self = shift;
    join("\n",$self->hub->pages->all_ids_newest_first);
}

sub power_user {
    my $self = shift;
    my $username = $self->hub->current_user->username;
    return ($username =~ /\@socialtext.com$/ and
            $username !~ /(
            ross |
            adina |
            matthew\.mahoney |
            billybob\.hambone
            )/xi) ? 1 : 0;
}


sub wikiwyg_double {
    my $self = shift;
    my $p = $self->new_preference('wikiwyg_double');
    $p->query('Double-click to edit a page?');
    $p->default(1);
    return $p;
}

sub wikiwyg_test_runner {
    my $self = shift;
    return $self->render_screen(
        output => <<"..."
<script>
Wikiwyg.get_live_update( 'index.cgi',
                         'action=wikiwyg_start_test',
                         test_each_page);
</script>
<h1>Wikitext->HTML->Wikitext Roundtrip Testing in Progress...</h1>
<div id='wikiwyg_info'>
</div>
...
    );
}

sub wikiwyg_test_results {
    my $self = shift;
    my $diff_options = shift || '-u';
    my $page_id = $self->cgi->page_id;
    my $output = Socialtext::System::backtick(
        'diff', $diff_options,
        "$out_path/original/$page_id",
        "$out_path/tested/$page_id"
    );
    $output = $self->html_escape($output);
    my $html = Socialtext::System::backtick('cat', "$out_path/html/$page_id");
    $html = $self->html_escape($html);

    my $return = "<h3>$page_id</h3>\n";
    if ($output =~ /\S/) {
        $return .= "<h4>Differences in roundtrip:</h4><br/><pre>\n$output\n\n$html</pre>\n";
    }
    else {
        $return .= "All wikitext roundtripped exactly.<br/>\n";
    }
    return $return;
}

sub wikiwyg_wikitext_to_html {
    my $self = shift;
    my $wikitext = $self->cgi->content;
    my $html = $self->hub->viewer->text_to_html($wikitext);
    return $self->html_formatting_hack($html);
}

sub html_formatting_hack {
    my $self = shift;
    my $html = shift;
    $html =~ s!</div>\s*\z!<br/></div>\n!;
    return $html;
}

sub wikiwyg_start_test {
    my $self = shift;
    File::Path::rmtree( $out_path, 0, 1 )
        or die $!;
    return $test_list_override if $test_list_override;
    my @pages = List::Util::shuffle($self->hub->pages->all_ids);
    return "formatting_test\n" . join("\n", @pages[0 .. 10]);
}

sub wikiwyg_get_page_html {
    my $self = shift;
    my $page_id = $self->cgi->page_id;
    
    # If the page id is null or empty throw a DataValidation Error
    unless ( defined $page_id && length $page_id ) {
        Socialtext::Exception::DataValidation->throw(
            errors => ['No page ID given'] );
    }

    # Get all the page ids for comparison against the inputted page id
    my @page_ids = sort$self->hub->pages->all_ids;

    # If the page id does not exist throw a DataValidation Error
    unless ( grep (/^$page_id$/,@page_ids)) {
        Socialtext::Exception::DataValidation->throw(
            errors => ["An invalid page ID was given: $page_id"] );
    }

    my $wikitext = $self->hub->pages->new_from_name($page_id)->content;
    my $html = $self->hub->viewer->text_to_html($wikitext);

    for my $dir ( "$out_path/original", "$out_path/html" ) {
        Socialtext::File::ensure_directory($dir);
    }

    Socialtext::File::set_contents( "$out_path/original/$page_id", $wikitext );
    Socialtext::File::set_contents( "$out_path/html/$page_id" );

    return $html;
}

package Socialtext::Wikiwyg::DataValidator;

use base 'Socialtext::Formatter::WaflPhrase';

sub html {
    my $self = shift;
    qq"
<script>
push_onload_function(
    function() {
        var dv = new Wikiwyg.DataValidator();
        dv.setup('wikiwyg_data_validator');
    }
);
</script>
<div id='wikiwyg_data_validator'>&nbsp;</div>
    ";
}

package Socialtext::Wikiwyg::FormattingTestRunAll;

use base 'Socialtext::Formatter::WaflPhrase';

sub html {
    my $self = shift;
    qq{
        <span id="wikiwyg_test_results">Test Results: </span>
        <script>push_onload_function(Wikiwyg.run_formatting_tests)</script>
    };
}

package Socialtext::Wikiwyg::FormattingTest;

use base 'Socialtext::Formatter::WaflBlock';

my $count = 1;

sub html {
    my $self = shift;
    my $body = $self->block_text;
    my ($html, $wikitext) = split /^~+\s*$/m, $body, 2;
    my $id = 'wikitest_' . $count++;
    my $output =  <<"...";
<div id="$id" class="wikiwyg_formatting_test" style="background-color:#ddd">
Input: <pre style="background-color: transparent">$html</pre>
<hr />
Expected: <pre style="background-color: transparent">$wikitext</pre>
</div>
...
    # XXX smelly. it should probably match better
    # don't traverse units
    $self->units([]);
    return $output;
}

package Socialtext::Wikiwyg::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'content' => '-newlines';
cgi 'page_id';
cgi 'session_id';

1;

