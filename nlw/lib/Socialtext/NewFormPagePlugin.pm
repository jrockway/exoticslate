# @COPYRIGHT@
package Socialtext::NewFormPagePlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use Class::Field qw( const );
use Socialtext::AppConfig;
use Socialtext::BrowserDetect ();
use Socialtext::l10n qw(loc);

sub class_id { 'new_form_page' }
const class_title => 'New Form Page';

const template_base_path => 'new_form_page';
const cgi_class => 'Socialtext::NewFormPage::CGI';

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(wafl => new_form_page => 'Socialtext::NewFormPagePhrase::Wafl');
    $registry->add(action => 'new_form_page');
    $registry->add(action => 'new_form_page_process');
}

sub new_form_page {
    my $self = shift;
    $self->_render(
        template_base_path() . '/new_form_page_input.html',
#        $self->screen_template,
        display_title => loc('Create Your Profile'),
        self => $self,
        $self->cgi->all,
    );
}

sub new_form_page_process {
    my $self = shift;
    return $self->new_form_page
        unless $self->hub->checker->check_permission('edit');

    my $first_name = $self->cgi->first_name;
    my $last_name = $self->cgi->last_name;
    my $page_title = join ' ', grep $_, $first_name, $last_name
      or die "Can't determine page name";
    my $page = $self->hub->pages->new_from_name($page_title);

    my $content = $self->_render(
        'new_form_page_output.wiki',
        $self->cgi->vars,
    );

    $page->content($content);
    $page->metadata->Subject($page_title);
    if ($self->cgi->category) {
        $page->metadata->Category([$self->cgi->category]);
    } else {
        $page->metadata->Category(['People']);
    }

    my $user = $self->hub->current_user;

    $page->metadata->update( user => $user );
    $page->store( user => $user );

    $self->_set_user_info( $user, $first_name, $last_name )
        unless $user->is_guest();

    $self->redirect($page->uri);
}

sub _render {
    my $self = shift;
    my $template = shift;

    # We use this rather than Socialtext::Template since we need to look in
    # additional paths for our templates.
    return $self->template_render(
        template => $template,
        vars => {
            $self->hub->helpers->global_template_vars,
            detected_ie => Socialtext::BrowserDetect::ie,
            hub         => $self->hub,
            static_path => Socialtext::Helpers->static_path,
            appconfig   => Socialtext::AppConfig->instance(),
            script_name => Socialtext::AppConfig->script_name,
            @_,
        },
        paths => [
            $self->template_base_path . '/' . $self->cgi->form_id,
            $self->template_base_path,
        ],
    );
}

sub _set_user_info {
    my $self = shift;
    my $user = shift;
    my $first_name = shift;
    my $last_name = shift;

    my %update;
    $update{first_name} = $first_name if $first_name;
    $update{last_name} = $last_name if $last_name;

    $user->update_store(%update);
}

##########################################################################
package Socialtext::NewFormPagePhrase::Wafl;

use Socialtext::AppConfig;

use base 'Socialtext::Formatter::WaflPhrase';

sub html {
    my $self = shift;
    my ($form_id, $link_title) = split /\s+/, $self->arguments, 2;
    return $self->syntax_error
        unless $link_title and $self->form_exists($form_id);
    my $script = Socialtext::AppConfig->script_name;
    return
        qq{<a class="new_form_page_link" href="$script?} .
        qq{action=new_form_page;form_id=$form_id">$link_title</a>};
}

sub form_exists {
    my $self = shift;
    -d (
        $self->hub->skin->skin_path('s2') . '/template/' .
        $self->hub->new_form_page->template_base_path . '/'
        . shift
    );
}

package Socialtext::NewFormPage::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'form_id';
cgi 'first_name';
cgi 'last_name';
cgi 'category';

1;

