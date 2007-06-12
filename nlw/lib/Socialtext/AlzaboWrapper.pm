# @COPYRIGHT@
package Socialtext::AlzaboWrapper;

use strict;
use warnings;

our $VERSION = '0.01';

use Class::AlzaboWrapper 0.07;
use base 'Class::AlzaboWrapper';

use Readonly;
use Socialtext::Validate qw( validate SCALAR_TYPE );


my $UseCache;
sub UseCache {
    return if $UseCache;

    $UseCache = 1;
    require Alzabo::Runtime::UniqueRowCache;
}

my %Cache;
sub ClearCache {
    return unless $UseCache;

    %Cache = ();
    Alzabo::Runtime::UniqueRowCache->clear();
}

sub _ClearCacheForClass {
    return unless $UseCache;

    my $self = shift;
    my $class = ref $self || $self;

    delete $Cache{$class};
    Alzabo::Runtime::UniqueRowCache->clear_table( $class->table );
}

sub new {
    my $class = shift;

    return $class->SUPER::new(@_) unless $UseCache;

    my $key = _cache_key(@_);

    return $Cache{$class}{$key} if $Cache{$class}{$key};

    my $object = $class->SUPER::new(@_);
    return unless $object;

    my @pk_key;
    for my $col ( map { $_->name } $class->table->primary_key ) {
        push @pk_key, $col, $object->$col();
    }
    my $pk_key = _cache_key(@pk_key);

    $Cache{$class}{$key} = $object;
    $Cache{$class}{$pk_key} = $object;

    return $object;
}

sub _cache_key {
    return join "\0", sort map { defined $_ ? $_ : "<undef>" } @_;
}

sub create
{
    my $class = shift;
    my %p = @_;

    $class->_validate_and_clean_data(\%p)
        if $class->can('_validate_and_clean_data');

    return $class->SUPER::create(%p);
}

sub update
{
    my $self = shift;
    my %p = @_;

    $self->_validate_and_clean_data(\%p)
        if $self->can('_validate_and_clean_data');

    return $self->SUPER::update(%p);
}

sub delete {
    my $self = shift;

    $self->_ClearCacheForClass();

    $self->SUPER::delete(@_);
}

sub Count { $_[0]->table()->row_count() }

{
    Readonly my $spec => {
        limit  => SCALAR_TYPE( default => 0 ),
        offset => SCALAR_TYPE( default => 0 ),
    };

    sub All {
        my $class = shift;
        my %p = validate( @_, $spec );

        my %limit;
        if ( $p{limit} ) {
            $limit{limit} = [ @p{ 'limit', 'offset' } ];
        }

        my %order_by;
        if ( my $col = $class->DefaultOrderByColumn ) {
            $order_by{order_by} = $col;
        }

        return
            $class->cursor(
                $class->table->all_rows(
                    %order_by,
                    %limit,
                )
            );
    }
}



1;

__END__

=head1 NAME

Socialtext::AlzaboWrapper - Socialtext-specific subclass of Class::AlzaboWrapper

=head1 SYNOPSIS

  package Socialtext::User;

  use Socialtext::AlzaboWrapper
    table => Socialtext::Schema->Load->table('user');

=head1 DESCRIPTION

C<Class::AlzaboWrapper> is a module that helps you write a class which
I<has> a table in your schema as its primary data source (though it
can and will use other tables).  This module provides some additional
sugar on top of Class::AlzaboWrapper.

=head1 USAGE

The way to use this module is to simply C<use> it, at which time it
will make itself a parent class of the using module, I<and> generate
some methods directly in the calling class.

See C<Class::AlzaboWrapper> C<Class::AlzaboWrapper::Cursor> for most
of the details.

=head1 METHODS

This module provides several methods that can be used by subclasses.

=over 4

=item * new()

The constructor provided by this module accepts a hash of
parameters. If the hash keys match the primary key for the class's
table, then it constructs a new object based on that key. Otherwise,
if the subclass provides a C<_new_row()> method, that is called with
the parameters passed to C<new()>. That method is expected to return a
new C<Alzabo::Runtime:Row> object if a matching row exists, otherwise
it should return false.

This method also makes sure objects are cached on creation.

=item * create() and update()

If you do not override the C<create()> and/or C<update()> methods in
your class, this module provides defaults that take a hash of values
to be created/updated.  If your subclass provides a
C<_validate_and_clean_data()> method, it will be called and passed a
hash reference of these parameters.

Your C<_validate_and_clean_data()> method can alter this hash, or
throw an exception if the data is invalid.

After C<_validate_and_clean_data()> is called, the appropriate
superclass method (C<create()> or C<update()>) is called.

=item * delete()

This method makes sure to clear the deleted row from the cache before
doing any actual deletion.

=item * Count()

This is syntactic sugar for C<< $class->table->row_count >>.

=item * All()

This methods returns a cursor for all the objects in the given
subclass.

If the subclass provides a C<DefaultOrderByColumn()> method, then
whatever column(s) is returned from this method will be used for the
query.

=item * UseCache()

Turn on caching. It cannot be turned off once it is on.

=item * ClearCache()

Clear all cached data.

=back

=head1 OBJECT CACHING

This module provides a caching layer for all of its subclasses that
can turned on by calling C<UseCache()>.

The caching layer works by intercepting all calls to C<new()>. When a
new object is created, the parameters with which it was created are
used as the cache key. It also adds a cache entry based on the
object's primary key. Future calls to C<new()> with the same
parameters will hit the cache.

In addition, turning on caching enables the use of
C<Alzabo::Runtime::UniqueRowCache>, which does caching of the
underlying Alzabo row objects. Calling C<ClearCache()> also clears the
Alzabo row cache.

When an object is deleted, this clears the cache for its class, in
order to prevent false positives.

=head2 CACHING DANGERS

If you are running code in a persistent environment (like mod_perl),
then turning on caching can cause all sorts of errors by caching old
data. The caching layer is intentionally dumb, because making it smart
would also make it slower. If the caching adds too much overhead, then
it becomes useless.

Under mod_perl, this is easy to remedy. Simple call C<ClearCache()> at
the very beginning of every request. That way the cache lasts for a
single request. This somewhat isolates a request from changes
happening during other simultaneous requests, but this is not really a
problem in practice.

Another case where the caching can cause problems is if you turn
caching on, access the DBMS, spawn a subprocess that makes changes to
the DBMS, and then continue to use the DBMS in the parent. In that
case, the parent will not see any changes made in the child
process. In this case, you can either clear the cache after the child
process runs, or simply not use caching in the parent.

=head1 AUTHOR

Socialtext, Inc.

=head1 COPYRIGHT & LICENSE

Copyright 2005-2006 Socialtext, Inc.  All Rights Reserved.

=cut
