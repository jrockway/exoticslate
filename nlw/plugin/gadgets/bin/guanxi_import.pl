#!/usr/bin/perl
use JSON::Syck qw(Dump Load);
use LWP::Simple;
use strict;
use warnings;

my $people_json = get('http://demo.socialtext.net:6200/people/json');


die "No people.\n" unless $people_json;

my $people = Load($people_json);

use Data::Dumper;


foreach my  $person (@$people) {
    #print Dumper($person);
    next unless $person->{email};
    print "adding user " . $person->{email} . "\n";
    print `st-admin create-user --email '$person->{email}' --password password`;
    print "adding user to workspace open " . $person->{email} . "\n";
    print `st-admin add-member --email '$person->{email}' --workspace open`;
    print "adding user to workspace conversations " . $person->{email} . "\n";
    print `st-admin add-member --email '$person->{email}' --workspace conversations`;
    print "promoting user to workspace admin in open\n";
    print `st-admin add-workspace-admin --workspace open --email '$person->{email}'`;
    print "promoting user to workspace admin in conversations\n";
    print `st-admin add-workspace-admin --workspace conversations --email '$person->{email}'`;
}

# st-admin add-member --workspace FOO --email USER
# st-admin create-user --email EMAIL 
# st-admin add-workspace-admin --workspace FOO --email USER
