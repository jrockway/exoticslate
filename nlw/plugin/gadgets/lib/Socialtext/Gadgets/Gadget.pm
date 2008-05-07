package Socialtext::Gadgets::Gadget;
# @COPYRIGHT@
use strict;
use warnings;

use URI::Escape qw(uri_escape);
use Carp qw(croak);
use Class::Field qw(field);
use XML::LibXML;
use LWP::UserAgent;
use Socialtext::Gadgets::Features;
use Socialtext::URI;

use Socialtext::URI;
(my $base_uri = Socialtext::URI::uri) =~ s{/$}{};

my $LANG = 'en';
my $COUNTRY = 'us';

field 'name';
field 'id';

field 'ua',           -init => 'LWP::UserAgent->new';
field 'prefs_def',    -init => '$self->get_prefs_def';
field 'module_prefs', -init => '$self->get_module_prefs';
field 'arg_string',   -init => '$self->get_arg_string';
field 'href',         -init => '$self->get_href';
field 'content',      -init => '$self->get_content';
field 'messages',     -init => '$self->get_messages';
field 'storage',      -init => '$self->_get_storage';
field 'code_base',    -init => '$self->api->code_base';
field 'error_gadget_uri', -init => '$self->error_gadget_uri';
field 'api';

sub user_prefs {
  my $self = shift;
  return $self->get_user_prefs(@_);
}

sub error_gadget_uri {
    my $self = shift;
    my $code_base = $self->code_base;
    return "file://$code_base/../plugin/gadgets/share/gadgets/error.xml";
}

sub _get_storage {
    my $self = shift;
    return $self->api->storage($self->id);
}

sub _create_id { return time . int(rand 1000)  }

sub restore {
    my ($class, $api, $id) = @_;
    croak 'id required' unless $id;
    my $self = {};
    bless $self, $class;
    $self->id($id);
    $self->api($api);

    unless ($self->{url} = $self->storage->get('url')) {
        $self->{url} = $self->error_gadget_uri;
        warn "No url defined for gadget: $id\n";
        $self->messages({error => "No url defined for gadget: $id"});
    }
    $self->{module} = $self->storage->get('module');
    return $self;
}

sub install {
    my ($class, $api, $url, $id) = @_;
    croak 'url required' unless $url;
    my $self = {};
    bless $self, $class;
    $self->id($id || _create_id);
    $self->api($api);

    # XXX Probably don't just remove the existing gadget
    $self->storage->purge;

    my @url_parts = $url =~ m{^(\w+://[^/]*)?/?(.*)/([^/]+)$};
    $url_parts[0] ||= $base_uri;
    $url = join '/', grep { $_ } @url_parts;

    $self->storage->set('url_parts', \@url_parts);
    $self->storage->set('url', $url);

    $self->_parse_gadget($url);
    return $self;
}

sub _parse_gadget {
    my ($self,$url) = @_;
    
    my $doc;
    my $error;
    eval {
        $self->{url} = $url;
        die $error = "url required" unless $url;
        my $content = $self->get_www($self->{url});
        die $error = "Error fetching $self->{url}" unless $content;
        eval { $doc = XML::LibXML->new->parse_string($content) };
        die $error = "Error parsing gadget XML: $@" if $@;
    };
    if ($error) {
        my $content = $self->get_www($self->error_gadget_uri);
        $self->messages({error => $error});
        $doc = XML::LibXML->new->parse_string($content);
        warn "error parsing gadget: $error\n";
    } else {
        $self->_get_gadget_data($doc);
    }

    #$doc;

}

sub _get_gadget_data {
    my ($self,$doc) = @_;

    my %module;
    $module{prefs_def} = [];
  
     
    # find all the locale nodes in the gadget payload, download them from off
    # the net, parse them and add them into our msgs hash.
    my @locale_nodes = $doc->getElementsByTagName('Locale');

    foreach my $node (@locale_nodes) {
        my $lang = $node->getAttribute('lang') || 'en';
        my $url = $self->absolute_url($node->getAttribute('messages'));

        my $messages = $self->get_www($url) || '';
        
        if ($messages) {
            my $xml = XML::LibXML->new->parse_string($messages);

            for my $msg ($xml->getElementsByTagName('msg')) {
                my $name = $msg->getAttribute('name');
                ($module{messages}->{$lang}{$name} = $msg->textContent)
                    =~ s{(?:^\s*\n\s*|\s*\n\s*$)}{}g; # XXX assumed this is correct
            }
        }
    }
    

    # get the content of the gadget now
    my ($content) = $doc->getElementsByTagName('Content');
    $module{content} = $content->textContent;

    # get the type of gadget and set the URL appropriately
    my $type = $content->getAttribute('type');

    if ($type eq 'url') {
        $module{href} = $content->getAttribute('href');
    } elsif ($type eq 'html') {
        $module{href} = "/data/gadget/instance/" . $self->id . "/render";
    } elsif ($type eq 'dev') {
        # secret type to make dev easier.  HTML/Javascript payload is kept
        # at the referenced url and merged at install time.  Makes it much
        # easier to dev
        my $url = $content->getAttribute('href');
        die "Type dev requires a href attribute" unless $url;
        $module{content} = $self->get_www($url) || "Error fetching url: $url";
        $module{dev_src} = $url;
        $module{href} = "/data/gadget/instance/" . $self->id . "/render";
    } else {
        # XXX: Return an error gadget
        die "Unsupported content type: $type";
    }


    for my $pref ($doc->getElementsByTagName('UserPref')) {
        my %def = map { lc($_->name) => $_->value } $pref->attributes;
        my $datatype = $def{datatype} || '';
        if ($datatype eq 'enum') {
            my @options;
            for my $opt ($pref->getElementsByTagName('EnumValue')) {
                push @options, {
                    map { lc($_->name) => $_->value }
                    $opt->attributes
                };
            }
            $def{options} = \@options;
        }
        push @{$module{prefs_def}}, \%def;
    }

    my ($modprefs) = $doc->getElementsByTagName('ModulePrefs');
    
    foreach my $modpref ($modprefs->attributes) {
        $module{module_prefs}->{$modpref->name} = $modpref->value;
    }

    my $js = Socialtext::Gadgets::Features->new($self->api, type => 'gadget');

    $self->{module} = \%module;
    $self->storage->set('module',\%module);

    my @features;
    foreach my $require ($doc->getElementsByTagName('Require')) {
        my $feature = $require->getAttribute('feature');
        push @features, $feature;
    }

    $self->storage->set('features', \@features);
}

sub javascript {
    my $self = shift;
    my $js = Socialtext::Gadgets::Features->new($self->api, type => 'gadget');
    my $features = $self->storage->get('features');
    for my $feature (@$features) {
        $js->load($feature);
    }
    return $js->as_minified;
}

sub error {
    my ($self, $error) = @_;
    $self->messages({error => $error});
    my $content = $self->get_www($self->error_gadget_uri);
    $self->{error} = 1;
    $self->{inline} = 1;
    die 'NO';
}

# Below here doesn't require XML::LibXML

sub get_www {
    my ($self, $url) = @_;
    $self->ua->agent("Mozilla/8.0");
    my $res = $self->ua->get($url);
    unless ($res->is_success) {
        warn "fetching $url had an error: " . $res->status_line;
        return;
    }
    return $res->content;
}

sub get_messages {
  my $self = shift;

  # XXX TODO: DPL below cut from the parsing of local data, we need to return
  # just the appropriate data from messages based on the below logic
  #my @locale = $doc->getElementsByTagName('Locale');
  #my ($locale) = grep {
  #                      my $lang = $_->getAttribute('lang') || 'en';
  #                      $lang eq $LANG or $lang eq '*';
  #                 } $doc->getElementsByTagName('Locale');

  # if we can't find a more exact lang use the '*' lang 
  my $lang = exists($self->{module}{messages}->{$LANG}) ? $LANG : '*';
  return $self->{module}{messages}->{$lang};
}

sub expand_messages {
  my ($self,$text) = @_;
  my $messages = $self->get_messages;
  my $id = $self->id;
  return '' unless defined($text);
  $text =~ s{__MODULE_ID__}{$id}g;
  foreach my $key (keys %$messages) {
      $text =~ s{__MSG_${key}__}{$messages->{$key}}g;
  }
  # while (my ($key,$val) = each %$messages) {
  return $text;
}

sub expand_hangman {
    my ($self, $text) = @_;
    return '' unless $text;
    my $userprefs = $self->user_prefs;
    for my $pref (@$userprefs) {
        $text =~ s{__UP_$pref->{name}__}{$pref->{val}}g;
    }
    $text = $self->expand_messages($text);
    $text =~ s{/ig/modules}{http://www.google.com/ig/modules};
    return $text;
}

sub absolute_url {
    my ($self, $url) = @_;

    my $parts = $self->storage->get('url_parts');

    if ($url =~ m{^\w+://}) {
        return $url;
    }
    elsif ($url =~ m{^/}) {
        return "$parts->[0]/$url";
    }
    else {
        return "$parts->[0]/$parts->[1]/$url";
    }
}

sub inline {
    my $self = shift;
    return 0; #$self->{inline};
}

sub template_hash {
    my $self = shift;
    my $prefs = $self->user_prefs;
    my $hash =  {
        has_prefs => grep({ ($_->{datatype}||'') ne 'hidden' } @$prefs) ? 1 : 0,
        inline => $self->inline,
        content => $self->inline ? $self->get_content : '',
        href => $self->href,
        module_prefs => $self->get_module_prefs,
        user_prefs => $self->user_prefs,
        messages => $self->messages,
        id => $self->id,
    };
    return $hash;
}

sub get_arg_string {
    my $self = shift;
    my $id = $self->id;
    
    my $uri = Socialtext::URI::uri;
    $uri =~ s{/+$}{};
    
    my %args = (
        url => $self->storage->get('url'),
        nocache => 0,
        lang => $LANG,
        country => $COUNTRY,
        synd => 'ig',
        mid => 89,
        time => scalar time,
        ifpctok => $id,
        rpctoken => $id,
        parent => $uri,
    );
    my $userprefs = $self->user_prefs;
    for my $pref (@$userprefs) {
        $args{"up_$pref->{name}"} = uri_escape($pref->{val});
    }
    return join('&', map { "$_=$args{$_}" } keys %args);
}


sub get_href {
  my $self = shift;
  return $self->{module}{href} . '?' . $self->get_arg_string;
}

sub get_content {
  my $self = shift;
  return $self->expand_hangman($self->{module}{content});
}

sub get_prefs_def {
   my $self = shift;
   return $self->{module}{prefs_def};
}

sub get_user_prefs {
    my $self = shift;
    my $stored = $self->storage->get('user_prefs') || {};
    my $def = $self->prefs_def;
    my @prefs;
    for my $def (@$def) {
        my %pref = %$def;
        my $name = $def->{name};
        $pref{val} = $stored->{$name} || $def->{default_value};
        $pref{display_name} = $self->expand_messages($pref{display_name});
        push @prefs, \%pref;
    }
    return \@prefs;
}

sub get_module_prefs {
    my $self = shift;
    my $m = $self->{module}{module_prefs};
    my %prefs =  map { $_ => $self->expand_hangman($m->{$_}) } keys %{$m};
    return \%prefs;
}

1;
