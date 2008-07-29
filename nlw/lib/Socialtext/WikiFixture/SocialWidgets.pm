# @COPYRIGHT@
package Socialtext::WikiFixture::SocialWidgets;
use strict;
use warnings;
use base 'Socialtext::WikiFixture::Socialtext';
use Test::More;

our $VERSION = '0.01';

sub init {
    my ($self) = @_;
    $self->{mandatory_args} = [qw(username password)];
    $self->{workspace}="";
    $self->{selenium_timeout} = 30000 ;
    $self->{_widgets}={};
    # Also $self->{_curwidget}
    $self->SUPER::init;
}

sub st_empty_container { 
    my ($self) = @_;
    $self->{selenium}->open_ok("?action=clear_widgets");
    $self->{selenium}->wait_for_page_to_load_ok(10000);
    my $widgetlist = $self->{selenium}->get_text("id=widgetList");
    diag "Widgets: $widgetlist\n"; 
}

sub st_reset_container {
    my ($self) = @_;
    $self->{selenium}->open_ok("?action=reset_container");
    $self->{selenium}->wait_for_page_to_load_ok(10000);
}

sub st_add_widget {
    my ($self, $widgetpath, $logical) = @_;
    my @widgetsbefore = $self->_getWidgetList;
    $self->{selenium}->open_ok("?action=add_widget;file=$widgetpath");
    $self->{selenium}->wait_for_page_to_load_ok(10000);
    my @widgetsafter = $self->_getWidgetList;
    my @newwidgets = $self->_listDiff(\@widgetsafter, \@widgetsbefore);
    diag "New Widgets: ".join(",", @newwidgets). "\n"; 
    $self->{_widgets}{$logical} = $newwidgets[0];
    diag "Named this widget '$logical': ".$self->{_widgets}{$logical}."\n";
}

sub st_name_widget {
    my ($self, $position, $logical) = @_;
    my @widgetlist = $self->_getWidgetList;
    $self->{_widgets}{$logical} = (grep {/^[^_]+_$position$/} @widgetlist)[0];
    diag "Named this widget '$logical': ".$self->{_widgets}{$logical}."\n";
}

sub st_minimize_widget {
    my ($self, $logical) = @_;
    my $widget = $self->{_widgets}{$logical};
    $self->{selenium}->click("xpath=//div[\@id='$widget']//img[\@id='st-dashboard-minimize']");
}

sub st_remove_widget {
    my ($self, $logical) = @_;
    my $widget = $self->{_widgets}{$logical};
    # This removes from the javascript container - but not from the 
    # widgetList element in the page
    $self->{selenium}->click("xpath=//div[\@id='$widget']//img[\@id='st-dashboard-close']");
    $self->{selenium}->pause(2000);
    delete($self->{_widgets}{$logical});
}

sub st_widget_settings {
    my ($self, $logical) = @_;
    my $widget = $self->{_widgets}{$logical};
    $self->{selenium}->click("xpath=//div[\@id='$widget']//img[\@id='st-dashboard-settings']");
}

sub st_set_current_widget {
    my ($self, $logical) = @_;
    $self->{_curwidget}=$logical;
}
    
sub st_widget_title_like {
    my ($self, $opt1) = @_;
    $self->{selenium}->text_like("//span[\@class='gadget_title' and \@id='".$self->{_widgets}{$self->{_curwidget}}."-title-text']", $opt1);
}

sub st_widget_body_like {
    my ($self, $opt1) = @_;
    $self->{selenium}->select_frame('xpath=//iframe[@id="'.$self->{_widgets}{$self->{_curwidget}}.'-iframe"]');
    $self->{selenium}->text_like('//body', $opt1);
    $self->{selenium}->select_frame("relative=parent");
}

sub st_select_widget_frame {
    my ($self, $logical) = @_;
    $self->{selenium}->select_frame('xpath=//iframe[@id="'.$self->{_widgets}{$logical}.'-iframe"]');
}

sub _getWidgetList {
    my ($self) = @_;
    my $widgetlist = $self->{selenium}->get_text("id=widgetList");
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
