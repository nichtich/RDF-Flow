use strict;
use warnings;
package RDF::Source;
#ABSTRACT: Aggregate RDF data from diverse sources

use Log::Contextual::WarnLogger;
use Log::Contextual qw(:log), -default_logger
    => Log::Contextual::WarnLogger->new({ env_prefix => __PACKAGE__ });

use RDF::Trine qw(iri statement);
use Scalar::Util qw(blessed);

use RDF::Source::Union;
use RDF::Source::Cascade;
use RDF::Source::Pipeline;

use URI;
use URI::Escape;

use parent 'Exporter';
use Carp;

our @EXPORT = qw(dummy_source);
our @EXPORT_OK = qw(source is_source dummy_source is_empty_source union cascade pipeline source_uri);

# TODO: do we need this?
use overload '&{}' => sub { return shift->retrieve(@_) }, fallback => 1;

our $PREVIOUS = source( sub { shift->{'rdfsource.data'} } );

our $rdf_type      = iri('http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
our $rdfs_Resource = iri('http://www.w3.org/2000/01/rdf-schema#Resource');

sub new {
    my $class = ($_[0] and not ref $_[0]) ? shift : 'RDF::Source';
    my ($src, %args) = @_;

    my $code;

    if (blessed $src and $src->isa('RDF::Source')) {
        return $src; # don't wrap
    } elsif ( blessed $src and $src->isa('RDF::Trine::Model') ) {
        $code = sub {
            my $uri = source_uri( shift );
            $src->bounded_description( iri( $uri ) );
        };
    } elsif ( ref $src and ref $src eq 'CODE' ) {
        $code = $src;
    } elsif (not defined $src) {
        $code = sub { }; # TODO: warn?
    }

    croak 'expected RDF::Source, RDF::Trine::Model, or code reference'
        unless $code;

    my $self = bless { code => $code }, $class;

    $self->{name} = $args{name} if defined $args{name};

    $self;
}

sub source { new(@_) }

sub name {
    my $self = shift;
    $self->{name} ?  $self->{name} : 'anonymous source';
}

sub size {
    my $self = shift;
    return 1 unless $self->{sources};
    return scalar @{ $self->{sources} };
}

sub retrieve {
    my ($self, $env) = @_;

    log_trace { 'retrieve from ' . $self->name };
    my $rdf = $self->{code}->( $env );
    log_trace { $self->name . ' returned ' . (defined $rdf ? $rdf->size : 'no') . ' triples' };

    $rdf;
}

sub union    { RDF::Source::Union->new( @_ ) }
sub cascade  { RDF::Source::Cascade->new( @_ ) }
sub pipeline { RDF::Source::Pipeline->new( @_ ) }

sub is_source {
    my $s = shift;
    (ref $s and ref $s eq 'CODE') or blessed($s) and
        ($s->isa('RDF::Source') or $s->isa('RDF::Trine::Model'));
}

sub has_content { # TODO: document this
    my $rdf = shift;
    return unless blessed $rdf;
    return ($rdf->isa('RDF::Trine::Model') and $rdf->size > 0) ||
           ($rdf->isa('RDF::Trine::Iterator') and $rdf->peek);
}

sub pipe_to { # TODO: document this
    my ($self, $next) = @_;
    return RDF::Source::Pipeline->new( $self, $next );
}

sub dummy_source {
    my $env = shift;
    my $uri = source_uri( $env );

    my $model = RDF::Trine::Model->temporary_model;
    $model->add_statement( statement( iri($uri), $rdf_type, $rdfs_Resource ) );

    return $model;
}

sub previous { $RDF::Source::PREVIOUS; }

sub uri {
    carp 'please use ' . __PACKAGE__ . '::source_uri instead of ::uri';
    return source_uri(@_); #
}

sub source_uri {
    my $env = shift;
    return (defined $env ? $env : "") unless ref $env; # plain scalar or undef

    return $env->{'rdfsource.uri'} if defined $env->{'rdfsource.uri'};

    # a few lines of code from Plack::Request, so we don't require all of Plack
    my $base = ($env->{'psgi.url_scheme'} || "http") .
        "://" . ($env->{HTTP_HOST} || (($env->{SERVER_NAME} || "") .
        ":" . ($env->{SERVER_PORT} || 80))) . ($env->{SCRIPT_NAME} || '/');
    $base = URI->new($base)->canonical;

    my $path_escape_class = '^A-Za-z0-9\-\._~/';

    my $path = URI::Escape::uri_escape( $env->{PATH_INFO} || '', $path_escape_class );

    $path .= '?' . $env->{QUERY_STRING} if !$env->{'rdfsource.ignorepath'} &&
        defined $env->{QUERY_STRING} && $env->{QUERY_STRING} ne '';

    $base =~ s!/$!! if $path =~ m!^/!;

    $env->{'rdfsource.uri'} = URI->new( $base . $path )->canonical;

    $env->{'rdfsource.uri'};
}

1;

__END__

=head1 DESCRIPTION

A source returns RDF data as instance of L<RDF::Trine::Model> or
L<RDF::Trine::Iterator> when queried by a L<PSGI> requests. This is
similar to PSGI applications, which return HTTP responses instead of
RDF data. RDF::Light supports three types of sources: code references,
instances of RDF::Source, and instances of RDF::Trine::Model.

=head1 SYNOPSIS

    # RDF::Source as source
    $src = RDF::Source->new( @other_sources );

    # retrieve RDF data
    $rdf = $src->retrieve( $env );
    $rdf = $src->( $env ); # use source as code reference

    # code reference as source
    $src = sub {
        my $env = shift;
        my $uri = RDF::Source::uri( $env );
        my $model = RDF::Trine::Model->temporary_model;
        add_some_statements( $uri, $model );
        return $model;
    };

    # RDF::Trine::Model as source returns same as the following sub:
    $src = $model;
    $src = sub {
        my $uri = RDF::Source::uri( shift );
        return $model->bounded_description( RDF::Trine::iri( $uri ) );
    }

    # Check whether $src is a valid source
    RDF::Source::is_source( $src );

    # It is recommended to define your source as package
    package MySource;
    use parent 'RDF::Source';

    sub retrieve {
        my ($self, $env) = shift;
        # ..your logic here...
    }

=method new ( [ @sources ] )

=method source ( [ @sources ] )

Returns a new source, possibly by wrapping a set of other sources. Croaks if
any if the passes sources is no RDF::Source, RDF::Trine::Model, or
CODE reference. This constructor can also be exported as function C<source>:

  use RDF::Source qw(source);

  $src = source( @args );               # short form
  $src = RDF::Source->source( @args );  # equivalent
  $src = RDF:Source->new( @args );      # explicit constructor

=method is_source

Checks whether the object is a valid source. C<< $source->is_source >> is
always true, but you can also use and export this method as function:

  use RDF::Source qw(is_source);
  is_source( $src );

=function source_uri ( $env | $uri )

PSGI environment

Reuses some code from L<Plack::Request> by Tatsuhiko Miyagawa, so RDF::Source
does not depend in Plack.

=function dummy_source

This source returns a single triple such as the following, based on the
request URI. The request URI is either taken from the PSGI request variable
'rdflight.uri' or build from the request's base and path:

    <http://example.org/your/request> rdf:type rdfs:Resource .

=head2 LOGGING

RDF::Source uses L<Log::Contextual> for logging.

To simply see what's going on:

  use Log::Contextual::SimpleLogger;
  use Log::Contextual qw( :log ),
     -logger => Log::Contextual::SimpleLogger->new({ levels => [qw(trace)]});

=cut
