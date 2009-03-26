package Socialtext::Jobs;
use strict;
use warnings;
use Socialtext::SQL qw/sql_execute/;
use Socialtext::Schema;
use Socialtext::SQL qw/get_dbh/;
use Moose;
use Data::ObjectDriver::Driver::DBI ();
use TheSchwartz;

use namespace::clean -except => 'meta';

sub work_asynchronously {
    my $self = shift;
    my $job_class = 'Socialtext::Job::' . (shift || die "Class is mandatory");
    $self->schwartz_run( insert => $job_class => @_ );
}

sub list_jobs {
    my $self = shift;
    my %args = @_;
    $args{funcname} = "Socialtext::Job::$args{funcname}";
    $self->schwartz_run(list_jobs => \%args);
}

sub clear_jobs {
    my $self = shift;
    sql_execute('DELETE FROM job');
}

sub schwartz_run {
    my $self = shift;
    my $func = shift;

    my $dbh  = get_dbh();
    Use_the_force: {
        no warnings 'redefine';
        local *Data::ObjectDriver::Driver::DBI::init_db = sub {$dbh};
        local *DBI::disconnect                          = sub {0e0};

        my %params = Socialtext::Schema->connect_params();
        $self->{client} ||= TheSchwartz->new( 
            databases => [ { dsn => "dbi:Pg:database=$params{db_name}" } ],
            verbose => 1,
        );
        return $self->{client}->$func(@_);
    }
}

__PACKAGE__->meta->make_immutable;
1;