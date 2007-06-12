#!perl
# @COPYRIGHT@

use warnings;
use strict;
use Test::Selenium fixtures => ['admin', 'help'];
use Test::More import => [qw(ok is isnt)];

BEGIN {
    eval 'use HTML::TableExtract';
    plan skip_all => 'This test requires HTML::TableExtract' if $@;
}

my $tester = Test::Selenium->new( page_load_wait => 30000, login => 0 );

my %selenium_command_map;
foreach my $line (<DATA>) {
    my ( $k, $v ) = split ' ', $line;
    $selenium_command_map{$k} = $v;
}

my @selenese_files = glob "t/selenium/*.html";

foreach my $selenese_file (@selenese_files) {
    open SELENESE, $selenese_file;

    my $test = join '', <SELENESE>;

    my $te = HTML::TableExtract->new;
    $te->parse($test);
    my @rows      = $te->rows;
    my $title_row = shift @rows;
    my ( $title, undef, undef ) = @$title_row;
    my $count = 0;

    foreach my $row (@rows) {
        $count += 1;
        my ( $command, $target, $value ) = @$row;
        my @args = ($target);
        push @args, $value if $value;

        my $computed_command = $command;
        $computed_command =~ s/^verify/is/;
        $computed_command =~ s/^assert/is/;
        $computed_command =~ s/^waitFor/is/;
        $computed_command =~ s/AndWait//;
        $computed_command =~ s/Not//;
        $computed_command =~ s/([A-Z])/_$1/g;
        $computed_command = lc $computed_command;
        $computed_command .= "_ok" unless $command =~ /Not/;

        my $translated_command = $selenium_command_map{$command}
            || $computed_command;

        # some commands want us to wait before...
        if ( $command =~ m/^waitFor/ ) {
            $tester->selenium->wait_for_page_to_load(
                $tester->page_load_wait );
        }
        # we handle our own negation
        if ( $command =~ m/Not/ ) {
            my $tested_value = $tester->selenium->$translated_command(@args);
            isnt( $tested_value, 1, "$title - $selenese_file - $count" );
        }
        else {
            $tester->selenium->$translated_command( @args,
                "$title - $selenese_file - $count" );
        }
        # some commands want us to wait after...
        if ( $command =~ m/AndWait$/ ) {
            $tester->selenium->wait_for_page_to_load(
                $tester->page_load_wait );
        }
    }
}

$tester->stop_all;

# a mapping of selenese command => selenium rc command below
__DATA__
storeAlert noop
storeAllButtons noop
storeAllFields noop
storeAllLinks noop
storeAllWindowIds noop
storeAllWindowNames noop
storeAllWindowTitles noop
storeAttribute noop
storeAttributeFromAllWindows noop
storeBodyText noop
storeConfirmation noop
storeCursorPosition noop
storeElementHeight noop
storeElementPositionLeft noop
storeElementPositionTop noop
storeElementWidth noop
storeEval noop
storeExpression noop
storeHtmlSource noop
storeLocation noop
storeLogMessages noop
storePrompt noop
storeSelectedId noop
storeSelectedIds noop
storeSelectedIndex noop
storeSelectedIndexes noop
storeSelectedLabel noop
storeSelectedLabels noop
storeSelectedValue noop
storeSelectedValues noop
storeSelectOptions noop
storeTable noop
storeText noop
storeTitle noop
storeValue noop
storeWhetherThisFrameMatchFrameExpression noop
storeAlertPresent noop
storeChecked noop
storeConfirmationPresent noop
storeEditable noop
storeElementPresent noop
storePromptPresent noop
storeSomethingSelected noop
storeTextPresent noop
storeVisible noop
