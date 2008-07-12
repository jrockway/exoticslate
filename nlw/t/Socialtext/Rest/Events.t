#!perl
# @COPYRIGHT@
use warnings FATAL => 'all';
use strict;
use Test::More;
use mocked 'Socialtext::SQL', 'sql_ok';
use mocked 'Socialtext::Rest';
use Socialtext::CGI::Scrubbed;
use Socialtext::JSON qw/decode_json/;
use Socialtext::Rest::Events;

if ($Socialtext::Rest::Events::VERSION eq '0.1') {
    plan skip_all => 'The Rest interface is not fully implemented';
}
else {
    plan 'no_plan';
}


Empty_JSON_GET: {
    my $params = Socialtext::CGI::Scrubbed->new;
    my $rest = Socialtext::Rest->new(query => $params);
    my $e = Socialtext::Rest::Events->new($rest, $params);

    my $result = $e->GET_json($rest);
    is $rest->{header}{-status}, '200 OK';
    my $events = decode_json($result);
    is_deeply $events, [];
}

JSON_GET_an_item: {
    my %event = ( 
        timestamp => '2008-06-25 11:39:21.509539-07', 
        action => 'view',
        actor => 1,
        object => 'hello_world',
        context => '',
    );
    local @Socialtext::SQL::RETURN_VALUES = ( { return => [ \%event ] } );
    my $params = Socialtext::CGI::Scrubbed->new;
    my $rest = Socialtext::Rest->new(query => $params);
    my $e = Socialtext::Rest::Events->new($rest, $params);

    my $result = $e->GET_json($rest);
    is $rest->{header}{-status}, '200 OK';
    my $events = decode_json($result);
    $event{action} = lc $event{action};
    is_deeply $events, [ \%event ];
}

GET_without_authorized_user: {
    my $params = Socialtext::CGI::Scrubbed->new;
    my $rest = Socialtext::Rest->new(query => $params, user => undef);
    my $e = Socialtext::Rest::Events->new($rest, $params);

    my $result = $e->GET_json($rest);
    is $result, 'not authorized';
}

JSON_GET_with_parameters: {
    # In these tests, we'll just validate that CGI params are
    # making it all the way out to the SQL
    Count_parameter: {
        @Socialtext::SQL::SQL = ();
        my $params = Socialtext::CGI::Scrubbed->new( {
            count => 50,
        });
        my $rest = Socialtext::Rest->new(query => $params);
        my $e = Socialtext::Rest::Events->new($rest, $params);
        $e->GET_json($rest);
        is $rest->{header}{-status}, '200 OK';
        sql_ok( 
            sql => qr/\QLIMIT ?\E/,
            args => [50],
        );
    }
    Limit_parameter: {
        @Socialtext::SQL::SQL = ();
        my $params = Socialtext::CGI::Scrubbed->new( {
            limit => 42,
        });
        my $rest = Socialtext::Rest->new(query => $params);
        my $e = Socialtext::Rest::Events->new($rest, $params);
        $e->GET_json($rest);
        is $rest->{header}{-status}, '200 OK';
        sql_ok( 
            sql => qr/\QLIMIT ?\E/,
            args => [42],
        );
    }
    Offset_parameter: {
        @Socialtext::SQL::SQL = ();
        my $params = Socialtext::CGI::Scrubbed->new( {
            offset => 42,
        });
        my $rest = Socialtext::Rest->new(query => $params);
        my $e = Socialtext::Rest::Events->new($rest, $params);
        $e->GET_json($rest);
        is $rest->{header}{-status}, '200 OK';
        sql_ok( 
            sql => qr/\QLIMIT ? OFFSET ?\E/,
            args => [25, 42],
        );
    }
    Before_parameter: {
        @Socialtext::SQL::SQL = ();
        my $params = Socialtext::CGI::Scrubbed->new( {
            before => 'then',
        });
        my $rest = Socialtext::Rest->new(query => $params);
        my $e = Socialtext::Rest::Events->new($rest, $params);
        $e->GET_json($rest);
        is $rest->{header}{-status}, '200 OK';
        sql_ok( 
            sql => qr/\QWHERE timestamp < '?'::timestamptz\E/,
            args => ['then', 25],
        );
    }
    After_parameter: {
        @Socialtext::SQL::SQL = ();
        my $params = Socialtext::CGI::Scrubbed->new( {
            after => 'then',
        });
        my $rest = Socialtext::Rest->new(query => $params);
        my $e = Socialtext::Rest::Events->new($rest, $params);
        $e->GET_json($rest);
        is $rest->{header}{-status}, '200 OK';
        sql_ok( 
            sql => qr/\QWHERE timestamp > '?'::timestamptz\E/,
            args => ['then', 25],
        );
    }
    Action_parameter: {
        @Socialtext::SQL::SQL = ();
        my $params = Socialtext::CGI::Scrubbed->new( {
            action => 'View',
        });
        my $rest = Socialtext::Rest->new(query => $params);
        my $e = Socialtext::Rest::Events->new($rest, $params);
        $e->GET_json($rest);
        is $rest->{header}{-status}, '200 OK';
        sql_ok( 
            sql => qr/\QWHERE action = ?\E/,
            args => ['View', 25],
        );
    }

    Large_count_parameter: {
        @Socialtext::SQL::SQL = ();
        my $params = Socialtext::CGI::Scrubbed->new( {
            count => 10E6,
        });
        my $rest = Socialtext::Rest->new(query => $params);
        my $e = Socialtext::Rest::Events->new($rest, $params);
        $e->GET_json($rest);
        is $rest->{header}{-status}, '200 OK';
        sql_ok( 
            sql => qr/\QLIMIT ?\E/,
            args => [500],
        );
    }
}

POSTing_an_event: {
    my $params = Socialtext::CGI::Scrubbed->new( {
        actor => 'user@test.com',
        action => 'VIew',
        object => 'hello_world',
    } );
    my $rest = Socialtext::Rest->new(query => $params);
    my $e = Socialtext::Rest::Events->new($rest, $params);

    my $result = $e->POST_text($rest);
    is_deeply $rest->{header}, {
        -type => 'application/json',
        -status => '201 Created',
    };
    sql_ok(
        sql => qr/INSERT INTO/,
        args => [ 'now', 'VIew', '1', 'hello_world', '' ],
    );
}

POSTing_an_event_with_context: {
    my $params = Socialtext::CGI::Scrubbed->new( {
        actor => 'user@test.com',
        action => 'view',
        object => 'hello_world',
        context => '{"foo":"bar"}',
    } );
    my $rest = Socialtext::Rest->new(query => $params);
    my $e = Socialtext::Rest::Events->new($rest, $params);

    my $result = $e->POST_text($rest);
    is_deeply $rest->{header}, {
        -type => 'application/json',
        -status => '201 Created',
    };
    sql_ok(
        sql => qr/INSERT INTO/,
        args => [ 'now', 'view', '1', 'hello_world', '{"foo":"bar"}' ],
    );
}

POSTing_an_event_with_invalid_actor: {
    my $params = Socialtext::CGI::Scrubbed->new( {
        # In mocked Socialtext::User, users that m/^bad/ don't exist.
        actor => 'bad@test.com',
        action => 'View',
        object => 'hello_world',
    } );
    my $rest = Socialtext::Rest->new(query => $params);
    my $e = Socialtext::Rest::Events->new($rest, $params);

    my $result = $e->POST_text($rest);
    is $result, 'Invalid actor';
    is_deeply $rest->{header}, {
        -type => 'text/plain',
        -status => '400 Bad Request',
    };
    sql_ok( sql => undef, args => undef );
}

POSTing_without_authorization: {
    my $params = Socialtext::CGI::Scrubbed->new( {
        actor => 'bad@test.com',
        action => 'View',
        object => 'hello_world',
    } );
    my $rest = Socialtext::Rest->new(undef, $params, user => undef );
    my $e = Socialtext::Rest::Events->new($rest, $params);
    my $result = $e->POST_text($rest);
    is $result, 'not authorized';
}

POSTing_an_event_with_bad_context: {
    my $params = Socialtext::CGI::Scrubbed->new( {
        actor => 'user@test.com',
        action => 'view',
        object => 'hello_world',
        context => '{"foo:',
    } );
    my $rest = Socialtext::Rest->new(query => $params);
    my $e = Socialtext::Rest::Events->new($rest, $params);

    my $result = $e->POST_text($rest);
    like $result, qr/Invalid event context/;
    is_deeply $rest->{header}, {
        -type => 'text/plain',
        -status => '400 Bad Request',
    };
    sql_ok( sql => undef, args => undef );
}
