package Socialtext::Workspace;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::MockBase';

use unmocked 'Class::Field';

Class::Field::field 'skin_name';
Class::Field::field 'uploaded_skin';
Class::Field::field 'name';
Class::Field::field 'title';

our @BREADCRUMBS = ();

sub new {
    my $class = shift;
    return if @_ == 2 and ! defined $_[1];
    my $self = { @_ };
    bless $self, $class;
    return if $self->{name} and $self->{name} =~ m{^bad};

    $self->name($self->{name} || 'mock_workspace_name');
    $self->title($self->{title} || 'mock_workspace_title');

    return $self;
}

sub update {
    my ($self, $key, $val) = @_;
    $self->$key($val);
}

sub is_plugin_enabled { $_[0]->{is_plugin_enabled}{$_[1]} }
sub workspace_id { $_[0]->{workspace_id} || 'mock_workspace_id' }

sub homepage_is_dashboard { $_[0]->{homepage_is_dashboard} }

sub homepage_weblog { $_[0]->{homepage_weblog} }

sub logo_uri_or_default { 'logo_uri_or_default' }

sub is_public { $_[0]->{is_public} }

sub uri { $_[0]->{uri} ||
            '/workspace_' 
            . ($_[0]->{workspace_id} || $_[0]->{name} || $_[0]->title) 
            . '/' }

sub cascade_css { $_[0]->{cascade_css} || 1 }

sub email_in_address { 'mock_workspace_email_in_address' }

sub comment_form_window_height { 'mock_workspace_comment_form_window_height' }

sub comment_by_email { 'mock_workspace_comment_by_email' }

sub customjs_uri { '' }

sub customjs_name { '' }

sub read_breadcrumbs { @BREADCRUMBS }

sub permissions { shift } # hack - just return ourselves

sub user_can { $_[0]->{user_can} || 1 }

sub enable_spreadsheet { $_[0]->{enabled_spreadsheet}++ }

sub real { 1 }

package Socialtext::NoWorkspace;
use base 'Socialtext::Workspace';

sub workspace_id { 0 }
sub name { '' }
sub title { '' }
sub real { 0 }

1;
