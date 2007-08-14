package Socialtext::Workspace;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::MockBase';

sub title { $_[0]->{title} || 'mock_workspace_title' }
sub name { $_[0]->{name} || $_[0]->{title} || 'mock_workspace_name' }
sub workspace_id { $_[0]->{id} || 'mock_workspace_id' }

sub homepage_is_dashboard { $_[0]->{homepage_is_dashboard} }

sub homepage_weblog { $_[0]->{homepage_weblog} }

sub skin_name { $_[0]->{skin_name} || 'default_skin' }

sub logo_uri_or_default { 'logo_uri_or_default' }

sub is_public { $_[0]->{is_public} }

sub uri { $_[0]->{uri} || 'mock_workspace_uri' }

sub email_in_address { 'mock_workspace_email_in_address' }

sub comment_form_window_height { 'mock_workspace_comment_form_window_height' }

sub comment_by_email { 'mock_workspace_comment_by_email' }

sub customjs_uri { '' }

sub read_breadcrumbs { }

1;
