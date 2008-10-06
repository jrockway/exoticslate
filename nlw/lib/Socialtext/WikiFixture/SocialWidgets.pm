# @COPYRIGHT@
package Socialtext::WikiFixture::SocialWidgets;
use strict;
use warnings;
use base 'Socialtext::WikiFixture::Socialtext';
use Test::More;
use URI;
use URI::QueryParam;

=head1 NAME

Socialtext::WikiFixture::SocialWidgets - Test the Widgets using Selenium

=cut

our $VERSION = '0.01';

=head1 DESCRIPTION

This module is a subclass of Socialtext::WikiFixture::Socialtext and includes
extra commands specifically for testing the Socialtext Widgets (gadgets) containers.

=head1 FUNCTIONS

=head2 new( %opts )

Create a new fixture object. The same options as 
Socialtext::WikiFixture::Socialtext are required except that no workspace is required:

=over 4

=item username

Mandatory - the username to login to the wiki with.

=item password 

Mandatory - the password to login to the wiki with.

=back

=head2 init()

Initializes the object, and logs into the Socialtext server.

=cut

sub init {
    my ($self) = @_;
    $self->{mandatory_args} = [qw(username password)];
    $self->{workspace} ||= "test-data";
    $self->{_widgets}={};
    $self->SUPER::init;
}

=head2 st_empty_container ( )

Empties the current container using the action=clear_widgets parameter. 
You should navigate to the container URL using normal Selenese test command like "open"

=cut
sub st_empty_container { 
    my ($self) = @_;
    my $location = $self->_adjust_location(action => "clear_widgets");
    eval {
        $self->{selenium}->open($location);
        $self->{selenium}->wait_for_page_to_load(10000);
        my $widgetlist = $self->{selenium}->get_value("id=widgetList");
        diag "Widgets after empty: $widgetlist\n"; 
    };
    ok( !$@, 'st_empty_container' );
}

=head2 st_reset_container ( )

Resets the current container to default contehnts using the action=reset_container parameter. 
You should navigate to the container URL using normal Selenese test command like "open"

=cut
sub st_reset_container {
    my ($self) = @_;
    my $location = $self->_adjust_location(action => "reset_container");
    eval {
        $self->{selenium}->open($location);
        $self->{selenium}->wait_for_page_to_load(10000);
    };
    ok( !$@, 'st_reset_container' );
     
}

=head2 st_add_widget ( widgetpath, logical_name )

Adds a widget to the container. The widget is identified with the widgetpath parameter
and is the same value that is used by the file parameter in the add_widget action.

The logical_name parameter is the logical name that is assigned to this instance of the
widget. All future references to this widget will be made using this logical name. In
addition, the logical name can be used as a wikitest substitution var (%%logical_name%%)
whose value is the id of the widget (ie the value of __MODULE_ID__)

3rd Party Hosted widgets are not yet supported.

=cut

sub st_add_widget {
    my ($self, $widgetpath, $logical) = @_;
    my $location = $self->_adjust_location(action => "add_widget", 
                                           location => $widgetpath);
    eval {
        my @widgetsbefore = $self->_getWidgetList;
        $self->{selenium}->open($location);
        $self->{selenium}->wait_for_page_to_load(10000);
        my @widgetsafter = $self->_getWidgetList;
        my @newwidgets = $self->_listDiff(\@widgetsafter, \@widgetsbefore);
        $self->{_widgets}{$logical} = $newwidgets[0];
        $self->set($logical, $newwidgets[0]); # Set a varname for %%substitution%% 
        diag "Named this widget '$logical': ".$self->{_widgets}{$logical}."\n";
    };
    ok( !$@, "st-add-widget" );
}

=head2 st_name_widget ( position, logical_name )

Assigns a name to the widget in the container which is at the given position. This
is useful for precooked containers where specific widgets are always placed in a specific
order. The position parameter is used to match against the insertion order in the 
yaml file describing this container or the order in which the widget was installed.

The position is 1-based (1st widget matches position, etc). 

The logical_name parameter is the logical name that is assigned to this instance of the
widget. All future references to this widget will be made using this logical name. In
addition, the logical name can be used as a wikitest substitution var (%%logical_name%%)
whose value is the id of the widget (ie the value of __MODULE_ID__)
 

=cut

sub st_name_widget {
    my ($self, $position, $logical) = @_;
    eval {
        my @widgetlist = $self->_getWidgetList;
        $self->{_widgets}{$logical} = $widgetlist[$position-1];
        $self->set($logical, $widgetlist[$position-1]); # Set a varname for %%substitution%% 
        diag "Named this widget '$logical': ".$self->{_widgets}{$logical}."\n";
    };
    ok( !$@, "st-name-widget");
}

=head2 st_minimize_widget ( logical_name )

This clicks on the minimize button for the widget with the logical name given. This
also "restores" the widget to original size if the widget is already minimized.

This assumes that the currently selected frame is the "parent" container frame.

=cut

sub st_minimize_widget {
    my ($self, $logical) = @_;
    eval {
        my $widget = $self->{_widgets}{$logical};
        $self->{selenium}->click("xpath=//div[\@id='$widget']//img[\@id='st-dashboard-minimize']");
    };
    ok( !$@, "st-minimize-widget" );
}

=head2 st_remove_widget ( logical_name )

This clicks on the remove button for the widget with the logical name given. 

This assumes that the currently selected frame is the "parent" container frame.

=cut

sub st_remove_widget {
    my ($self, $logical) = @_;
    eval {
        my $widget = $self->{_widgets}{$logical};
        # This removes from the javascript container - but not from the 
        # widgetList element in the page
        $self->{selenium}->click("xpath=//div[\@id='$widget']//img[\@id='st-dashboard-close']");
        $self->{selenium}->pause(2000);
        delete($self->{_widgets}{$logical});
    };
    ok ( !$@, "st-remove-widget" );
}

=head2 st_widget_settings ( logical_name )

This clicks on the settings button for the widget with the logical name given. 

This assumes that the currently selected frame is the "parent" container frame.

=cut
sub st_widget_settings {
    my ($self, $logical) = @_;
    eval {
        my $widget = $self->{_widgets}{$logical};
        $self->{selenium}->click("xpath=//div[\@id='$widget']//img[\@id='st-dashboard-settings']");
    };
    ok( !$@, "st-widget-settings" );
}

=head2 st_widget_title_like ( logical_name, regex )

This performs a regex text match on the title of the widget (outside the iframe) with the 
given logical name.

This assumes that the currently selected frame is the "parent" container frame.

=cut

sub st_widget_title_like {
    my ($self, $logical, $opt1) = @_;
    $self->{selenium}->text_like_ok("//span[\@class='gadget_title' and \@id='".$self->{_widgets}{$logical}."-title-text']", $opt1);
}

=head2 st_widget_body_like ( logical_name, regex )

This performs a regex text match on the body (body element inside the iframe) of the widget 
with the given logical name.

This assumes that the currently selected frame is the "parent" container frame.

=cut
sub st_widget_body_like {
    my ($self, $logical, $opt1) = @_;
    eval {
        $self->{selenium}->select_frame('xpath=//iframe[@id="'.$self->{_widgets}{$logical}.'-iframe"]');
        $self->{selenium}->text_like('//body', $opt1);
        $self->{selenium}->select_frame("relative=top");
    };
    ok( !$@, "st-widget-body-like" );
}

=head2 st_select_widget_frame ( logical_name )

This sets the current frame to the one containing the widget with the logical name given.

It operates like select_frame, and will allow the full set of selenium commands to operate 
within the context of the widget iframe content, rather than the container. 

Note that for other commands in Socialtext::WikiFixture::SocialWidgets to work, a test 
script should call select-frame("reletive=parent") after invoking this to select the
parent (default) container frame.

=cut

sub st_select_widget_frame {
    my ($self, $logical) = @_;
    eval {
        $self->{selenium}->select_frame('xpath=//iframe[@id="'.$self->{_widgets}{$logical}.'-iframe"]');
    };
    ok( !$@, "st-select-widget-frame");
}

=head2 st_wait_for_widget_load (logical_name, timeout )

Waits for a widget's contents to finish loading, waiting for up to timeout milliseconds. Timeout 
defaults to 10000 (10 seconds).

Note that this command only waits until a widgets' html and javascript are loaded completely - 
it does not wait for the widget to complete any behavior it is programmed to perform after loading.

=cut

sub st_wait_for_widget_load {
    my ($self, $logical, $timeout) = @_;
    $timeout = $timeout || 10000;
    eval {
        my $widget=$self->{_widgets}{$logical};
        my $js = <<ENDJS;
        var curwin=selenium.browserbot.getCurrentWindow();
        var myframe=curwin.document.getElementById("$widget-iframe");
        myframe.contentWindow.gadgets.loaded;
ENDJS
        $self->{selenium}->wait_for_condition($js, $timeout);
    };
    warn $@ if $@;
    ok( !$@, "st-wait-for-widget-load");
}

=head2 st_wait_for_all_widgets_load ( timeout )

Waits for all widgets in the container to finish loading, waiting for up to timeout milliseconds. 
Timeout defaults to 10000 (10 seconds).

Note that this command only waits until a widgets' html and javascript are loaded completely - 
it does not wait for the widget to complete any behavior it is programmed to perform after loading.

=cut

sub st_wait_for_all_widgets_load {
    my ($self, $timeout) = @_;
    $timeout = $timeout || 10000;
    eval {
        my $js = <<ENDJS2;
        var curwin=selenium.browserbot.getCurrentWindow();
        var iframeIterator=curwin.document.evaluate('//iframe', curwin.document, null, XPathResult.ORDERED_NODE_ITERATOR_TYPE, null);
        var thisNode = iframeIterator.iterateNext();
        var allLoaded=true;
        while (thisNode) {
            allLoaded = allLoaded && thisNode.contentDocument.loaded;
            thisNode = iframeIterator.iterateNext();
        }    
        allLoaded;
ENDJS2
        $self->{selenium}->wait_for_condition($js, $timeout);
    };
    ok( !$@, "st-wait-for-all-widgets-load");
}


sub _adjust_location {
    my ($self, %params) = @_;

    (my $uriraw = $self->{selenium}->get_location()) =~ s/;/&/g;
    my $uri = URI->new($uriraw);
    while (my ($k,$v) = each %params) {
        $uri->query_param($k, $v);
    }
    (my $adjusted_uri = $uri->as_string) =~ s/&/;/g;
    return $adjusted_uri;
}

sub _getWidgetList {
    my ($self) = @_;
    my $widgetlist = $self->{selenium}->get_value("id=widgetList");
    return split(/,/, $widgetlist);
}

sub _listDiff {
    my ($self, $a, $b) = @_;
    my @result=();
    print join(",", @$a). "\n";
    foreach my $val (@$a) {
        push(@result, $val) unless (grep { $_ eq $val } @$b);
    }
    return @result;
}

=head1 AUTHOR

Gabe Wachob, C<< <gabe.wachob at socialtext.com> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-socialtext-editpage at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Socialtext-WikiTest>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Socialtext::WikiFixture::SocialWidgets

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Socialtext-WikiTest>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Socialtext-WikiTest>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Socialtext-WikiTest>

=item * Search CPAN

L<http://search.cpan.org/dist/Socialtext-WikiTest>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2008 Socialtext, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
