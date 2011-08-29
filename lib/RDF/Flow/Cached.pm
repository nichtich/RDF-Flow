use strict;
use warnings;
package RDF::Flow::Cached;
#ABSTRACT: Caches a source

use Log::Contextual::WarnLogger;
use Log::Contextual qw(:log), -default_logger
    => Log::Contextual::WarnLogger->new({ env_prefix => __PACKAGE__ });

use parent 'RDF::Flow::Source';
use RDF::Flow::Source qw(:util);

use Scalar::Util qw(blessed);
use Carp;

sub new {
    my $class  = shift;
    my $source = shift;
    my $cache  = shift;
    my (%args) = @_;

    # TODO: check $source and $cache
    croak "missing source" unless $source;

    $source = RDF::Flow::rdflow($source);

    my $self = bless {
        name   => "cached " . $source->name,
        source => $source,
        cache  => $cache,
    }, $class;

    $self->match( $args{match} );

    $self;
}

sub retrieve_rdf {
    my $self = shift;
    my $env  = shift;

    my $key = $env->{'rdflow.uri'};

    # get from the cache
    my $object = $self->{cache}->get( $key );
    if (defined $object) {
        log_trace { 'got from cache' };
        my ($rdf, $vars) = @{$object};
        while ( my ($key, $value) = each %$vars ) {
            $env->{$key} = $value;
        }
        $env->{'rdflow.cached'} = 1;
        my $model = RDF::Trine::Model->new;
        $model->add_hashref($rdf);
        $rdf = $model;
        return $rdf;
    }

    # this sets timestamp and logs
    my $rdf = $self->{source}->retrieve( $env );
    my $vars = {
        map { $_ => $env->{$_} }
        grep { $_ =~ /^rdflow\./ } keys %$env
    };
    log_trace { 'store in cache' };

    $object = [$rdf,$vars];
    if (blessed($rdf) and $rdf->isa('RDF::Trine::Model')) {
        $object->[0] = $rdf->as_hashref;
    } elsif (blessed($rdf) and $rdf->isa('RDF::Trine::Iterator')) {
        my @stms;

        # FIXME: RDF::Trine::Iterator should also have as_hashref
        # so we can avoid one serialization
        my $model = RDF::Trine::Model->new;
        $model->begin_bulk_ops;
        while (my $s = $rdf->next) {
            $model->add_statement( $s );
            push @stms, $s;
        }
        $model->end_bulk_ops;
        $object->[0] = $model->as_hashref;

        $rdf = RDF::Trine::Iterator::Graph->new( \@stms );
    } else {
        $object->[0] = { };
    }

    $self->{cache}->set( $key, $object );

    return $rdf;
}

sub inputs {
    return (shift->{source});
}

1;

=head1 DESCRIPTION

Plugs a cache in front of a L<RDF::Flow::Source>. Actually, this module does
not implement a cache. Instead you must provide an object that provides at
least two methods to get and set an object based on a key. See L<CHI>,
L<Cache>, and L<Cache::Cache> for existing cache modules.

The request URI in C<rdflow.uri> is used as caching key. C<rdflow.cached> is
set if the response has been retrieved from the cache.  C<rdflow.timestamp>
reflects the timestamp of the original source, so you get the timestamp of the
cached response when it was first retrieved and stored in the cache.

=head1 SYNOPSIS

  use CHI;                          # create a cache, for instance with CHI
  my $cache = CHI->new( ... );

  use RDF::Flow::Cached;        # plug cache in front of an existing source
  my $cached_source = RDF::Flow::Cached->new( $source, $cache );

  my $cached_source = $source->cached( $cache );       # alternative syntax

  use RDF::Flow qw(cached);
  my $cached_source = cached( $source, $cache );       # alternative syntax

=head1 SEE ALSO

L<Plack::Middleware::Cached> implements almost the same mechanism for caching
general PSGI applications.

=cut
