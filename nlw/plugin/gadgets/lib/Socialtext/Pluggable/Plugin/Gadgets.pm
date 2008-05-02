package Socialtext::Pluggable::Plugin::Gadgets;

use strict;
use warnings;

use JSON::Syck;
use Socialtext::Helpers;
use Socialtext::AppConfig;
use Socialtext::Gadgets::Container;
use XML::LibXML;
use LWP;
use HTTP::Request;

use base 'Socialtext::Pluggable::Plugin';

my $UNPARSEABLE_CRUFT = "throw 1; < don't be evil' >";

sub name { 'gadgets' }

sub register {
    my $class = shift;
    $class->add_hook('action.gadgets' => 'html');
    $class->add_hook('action.add_gadget' => 'add_gadget');
    $class->add_hook('action.test_gadgets' => 'test_gadgets');
    $class->add_hook('action.gadget_gallery' => 'gallery');

    $class->add_rest('/data/gadget/instance/:id/render' => 'render_gadget');
    $class->add_rest('/data/gadget/instance/:id/prefs' => 'set_prefs');
    $class->add_rest('/data/gadget/proxy' => 'proxy');
    $class->add_rest('/data/gadget/json_proxy' => 'json_proxy');
    $class->add_rest('/data/gadget/json_feed_proxy' => 'json_feed_proxy');
    $class->add_rest('/data/gadget/desktop' => 'desktop');
}

sub add_gadget {
    my $self = shift;

    my %vars = $self->cgi_vars;

    die "either name or url required" unless $vars{url} or $vars{name};

                    # pass in the "api" object
    my $container = Socialtext::Gadgets::Container->new($self, $self->username);

    $container->install_gadget($vars{url});

    $self->redirect('?action=gadgets');
}

sub gallery {
    my $self = shift;
    my $plugin_dir = $self->plugin_dir;
    use File::Basename qw(basename);
    my @gadgets = sort map { basename($_,'.xml') } glob("$plugin_dir/share/gadgets/*.xml"); 
    my @gadgets3rd =  sort map { basename($_,'.xml') } glob("$plugin_dir/share/gadgets/3rdparty/*.xml"); 
   
    my @gadgets3rdh = (
        { name => "calc", uri => "http://www.labpixies.com/campaigns/calc/calc.xml"},
        { name => "todo", uri => "http://www.labpixies.com/campaigns/todo/todo.xml"},
        { name => "wikipedia", uri => "http://googlewidgets.net/search/wikipedia/wikipedia.xml"},
        { name => "delicious", uri => "http://www.labpixies.com/campaigns/delicious/delicious.xml"},
        { name => "facebook *NOT WORKING* :(", uri => "http://www.brianngo.net/ig/facebook.xml"},
        { name => "mapquest", uri => "http://www.yourminis.com/embed/google.aspx%3Fgallery%3D1%26uri%3Dyourminis/AOL/mini:mapquest%26uniqueID%3Db12a5a53-c6bf-4b5a-b96f-0b5a5a81b8ca"},
        { name => "time", uri => "http://www.canbuffi.de/gadgets/clock/clock.xml"},
        { name => "BeTwittered", uri => "http://hosting.gmodules.com/ig/gadgets/file/106092714974714025177/TwitterGadget.xml" },
    );

    return $self->template_render('gallery',
        gadgetsST => \@gadgets, 
        gadgets3rd => \@gadgets3rd,
        gadgets3rdh => \@gadgets3rdh,
        current_uri => $self->uri,
    );

}

sub test_gadgets {
    my $self = shift;
    
    my $container = Socialtext::Gadgets::Container->test($self);

    return $self->template_render('dashboard',
        features => $container->feature_scripts,
        gadgets => $container->template_vars,
    );

}

sub html {
    my $self = shift;

    my $container = Socialtext::Gadgets::Container->new($self, $self->username);

    return $self->template_render('dashboard',
        features => $container->feature_scripts,
        gadgets => $container->template_vars,
        gallery_uri => $self->make_uri( path=>'/admin/index.cgi') . "?action=gadget_gallery",
        #gallery_uri => $self->uri . "?action=gadget_gallery",
    );
}

sub render_gadget {
    my ($self,$rest,$args) = @_;
    my $gadget = Socialtext::Gadgets::Gadget->restore($self, $args->{id});
    return $self->template_render('gadget_rendered',
        id => $gadget->id,
        content => $gadget->content,
        features => $gadget->features,
        messages => $gadget->messages,
    );
}

# set the position and location of gadgets on the desktop to the passed json
# payload
sub desktop {
    my ($self,$rest) = @_;
    my $api = Socialtext::Pluggable::Plugin->new();
    my $container = Socialtext::Gadgets::Container->new($api,$rest->user->username);

    my $desktop = $rest->query->{desktop};
    $desktop = $desktop->[0] if ref $desktop eq 'ARRAY';

    my $delete = $rest->query->{delete};
    $delete = $delete->[0] if ref $delete eq 'ARRAY';

    if ($delete) {
        $container->delete_gadget($delete);
    }

    if ($desktop) {
        my $positions = JSON::Syck::Load($desktop);

        my %gadgets;
        foreach my $col ( sort keys %$positions ) {
            foreach my $row ( sort keys %{ $positions->{$col} } ) {
                my $id = $positions->{$col}{$row};
                $gadgets{$id} = { id => $id, pos => [ $col, $row ] };
            }
        }
        $container->storage->set('gadgets',\%gadgets);
        $container->storage->save();
    }
    
    return '1'; #JSON::Syck::Dump(\%gadgets);
}

sub set_prefs {
    my ($self,$rest,$args) = @_;
    my $api = Socialtext::Pluggable::Plugin->new();
    my $gadget = Socialtext::Gadgets::Gadget->restore($api,$args->{id});
    # XXX Ugly
    my $set;
    my %prefs;
    for my $key ($rest->query->param) {
        if ($key =~ /^up_(.*)/) {
            my $val = $rest->query->param($key);
            $prefs{$1} = $val;
        }
    }
    if (%prefs) {
        $gadget->storage->set('user_prefs', \%prefs);
        $gadget->storage->save;
    }
}

sub json_feed_proxy {
    my ( $self, $rest, $args ) = @_;

    my $url = $rest->query->{url};
    $url = $url->[0] if ref $url eq 'ARRAY';

    my $content = $rest->getContent();

    my $agent = LWP::UserAgent->new; 
    $agent->agent('Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.1.2) ' .
                  'Gecko/20060601 Firefox/2.0.0.2 (Ubu ntu-edgy)');
    my $request = HTTP::Request->new(GET => $url);
    $agent->default_headers->push_header(
        'Accept' => join(',',$rest->getContentPrefs)
    );

    my $result = $agent->request($request);
    $rest->header(-type => $result->header('Content-type'));  
    my $data = $result->decoded_content;
    # undefined value in here somewhere, status_line? body? XXX TODO:
   
    my %response = ( rc => $result->status_line );

   
    if (my $feed = XML::Feed->parse(\$data) ) {
        $response{title} = $feed->title();
        $response{items} = [];
        foreach my $e ($feed->entries) {
            my %item;
            $item{title} = $e->title;
            $item{summary} = $e->summary->body;
            $item{link} = $e->link;
            $item{content} = $e->content->body;
            $item{author} = $e->author;
            $item{id} = $e->id;
            $item{issued} = $e->issued->datetime;
            push(@{$response{items}},\%item);
        }

    } else {
        $response{error} =  XML::Feed->errstr . "\n";
    }

    return JSON::Syck::Dump(\%response);
}

sub json_proxy  {
    my ( $self, $rest, $args ) = @_;

    my %args;
    foreach my $key ( qw( authz headers httpMethod postData st url ) ) {
      $args{$key} = $rest->query->{$key};
      $args{$key} = $args{$key}->[0] if ref($args{$key}) eq 'ARRAY';
    }

    $args{httpMethod} = 'GET' unless grep { $_ eq $args{httpMethod} } qw( POST GET);

    my $agent = LWP::UserAgent->new; 
    $agent->agent('Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.1.2) ' .
                  'Gecko/20060601 Firefox/2.0.0.2 (Ubuntu-edgy)');
    my $request = HTTP::Request->new($args{httpMethod} => $args{url});

    $request->content($args{postData}) if $args{httpMethod} eq 'POST';

    if ($args{headers}) {
       my ($key,$value) = split('=',$args{headers});
       $value = uri_unescape($value);
       $agent->default_headers->push_header($key,$value);
    }

    my $result = $agent->request($request);
    $rest->header(-type => $result->header('Content-type'));  
    my $data = $result->decoded_content;

    # undefined value in here somewhere, status_line? body? XXX TODO:
    my $json = JSON::Syck::Dump({
        $args{url} => {
            body => $data,
            rc => $result->status_line,
        }
    });

    return $UNPARSEABLE_CRUFT . $json;
}

sub proxy  {
    my ( $self, $rest, $args ) = @_;

    my $url = $rest->query->{url};
    $url = $url->[0] if ref $url eq 'ARRAY';

    my $agent = LWP::UserAgent->new; 
    $agent->agent('Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.1.2) ' .
                  'Gecko/20060601 Firefox/2.0.0.2 (Ubu ntu-edgy)');
    my $request = HTTP::Request->new(GET => $url);
    $agent->default_headers->push_header(
        'Accept' => join(',',$rest->getContentPrefs)
    );

    my $result = $agent->request($request);
    $rest->header(-type => $result->header('Content-type'));  
    return $result->decoded_content;
}

1;
