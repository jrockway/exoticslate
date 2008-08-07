package Socialtext::Rest::Events::Activities;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Rest::Events';
use Socialtext::SQL qw/sql_execute/;

use Socialtext::Events;
use Socialtext::Events::Reporter;

our $VERSION = '1.0';

sub allowed_methods {'GET'}
sub collection_name { "Activity Events" }

sub get_resource {
    my ($self, $rest) = @_;

    # First we need to get the user id in case this was email or username used
    my $userid=$self->_fetch_id($self->user);

    my @args;
    my $requester = $self->rest->user;
    my $where = <<ENDWHERE;
(event_class = 'person' AND action = 'edit_save' AND person_id = ?) OR
(event_class = 'page' AND action IN ('edit_save', 'tag_add', 'comment', 'rename', 'duplicate', 'delete') AND actor_id = ?)
ENDWHERE
    my $whereargs = [$userid, $userid];
    push @args, where=>$where;
    push @args, where_args => $whereargs;
    push @args, limit => 20;
    my $events = Socialtext::Events->Get(@args);
    $events ||= [];
    return $events;
}

sub _fetch_id {                                                                                  
    my $self   = shift;                                                                              
    my $user_id = shift;                                                                              
                                                                                                      
    my $sql = 'SELECT * FROM "User" WHERE user_id = ?';                                                    
    my $proto;                                                                                        
    if ($user_id =~ /^\d+$/) {                                                                        
        my $sth = sql_execute($sql, $user_id);                                                        
        $proto = $sth->fetchrow_hashref();                                                            
    }                                                                                                 
    return $user_id if $proto;                                                                          
                                                                                                      
    my $user = Socialtext::User->new(username => $user_id);                                           
    $user ||= Socialtext::User->new(email_address => $user_id);                                       
                                                                                                      
    die "no such user for id '$user_id'" unless $user;                                                
                                                                                                      
    return $user->user_id;
}
1;
