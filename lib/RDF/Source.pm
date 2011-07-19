use strict;
use warnings;
package RDF::Source;
#ABSTRACT: Aggregate RDF data from diverse sources

use Log::Contextual::WarnLogger;
use Log::Contextual qw(:log), -default_logger
    => Log::Contextual::WarnLogger->new({ env_prefix => __PACKAGE__ });

use RDF::Trine qw(iri statement);
use Scalar::Util qw(blessed reftype);

use RDF::Source::Union;
use RDF::Source::Cascade;
use RDF::Source::Pipeline;

use URI;
use URI::Escape;

use parent 'Exporter';
use Carp;

our @EXPORT_OK = qw(source is_source dummy_source is_empty_source union cascade pipeline 
    source_uri sourceref sourcename has_retrieved cached);

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
        carp 'Missing source in plain RDF::Source'
            if $class eq 'RDF::Source';
        $code = sub { }; # TODO: warn?
    } else {
        croak 'expected RDF::Source, RDF::Trine::Model, or code reference'
    }

    my $self = bless { }, $class;
    $self->{name} = $args{name} if defined $args{name};
    $self->{code} = $code;

    $self;
}

sub source { new(@_) }

sub sourcename {
    my $self = shift;
    return ((reftype($self) || '') eq 'HASH' and $self->{name}) 
        ?  $self->{name} : 'anonymous source';
}

*name  = *sourcename;
*about = *name;

sub size {
    my $self = shift;
    return 1 unless $self->{sources};
    return scalar @{ $self->{sources} };
}

sub retrieve {
    my ($self, $env) = @_;
    log_trace { 
        sprintf "retrieve from %s with %s", about($self), source_uri($env);
    };
    $self->has_retrieved( $self->_retrieve_rdf( $env ) );
}

sub _retrieve_rdf {
    my ($self, $env) = @_;
    return $self->{code}->( $env );
}

sub union    { RDF::Source::Union->new( @_ ) }
sub cascade  { RDF::Source::Cascade->new( @_ ) }
sub pipeline { RDF::Source::Pipeline->new( @_ ) }

sub is_source {
    my $s = shift;
    (ref $s and ref $s eq 'CODE') or blessed($s) and
        ($s->isa('RDF::Source') or $s->isa('RDF::Trine::Model'));
}

sub sourceref {
    my $source = shift;
    return $source if ref $source and ref $source eq 'CODE';
    return unless blessed $source;
    $source = RDF::Source::new( $source ) if $source->isa('RDF::Trine::Model'); 
    return unless $source->isa('RDF::Source');
    return sub { $source->retrieve( @_ ) };
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

# TODO: this requires Plack::Middleware::Cached
sub cached {
    my $source = shift;
    my $cache  = shift;

    eval { require Plack::Middleware::Cached; };
    croak 'Caching requires Plack::Middleware::Cached' if $@;

    my $name = RDF::Source::sourcename( $source );
    my $cached = Plack::Middleware::Cached->wrap(
        RDF::Source::sourceref( $source ),
        key   => 'rdfsource.uri',
        cache => $cache
    );
    return RDF::Source->new( 
        sub {
            return $cached->( @_ );
        }, 
        name => "cached $name"
    );
}

sub has_retrieved {
    my ($self, $result, $msg) = @_;
    log_trace {
        $msg = "%s returned %s" unless $msg;
        sprintf $msg, name($self),
            (defined $result ? $result->size : 'no') . ' triples';
    };
    return $result;
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

=method sourceref

Return a reference to a code that calls the source's retrieve method.

    $source->retrieve( $env );
    $source->sourceref->( $env ); # equivalent

This method can also be exportet as function. It is useful to retrieve from
sources that may be code references or instances of RDF::Source:

    use RDF::Source qw(sourceref);

    my $s2 = RDF::Source->new( ... );
    my $s1 = sub { ... }; 

    sourceref( $s1 )->( $env );
    sourceref( $s2 )->( $env );

=method has_retrieved ( $source, $result [, $message ] )

Creates a logging event at trace level to log that some result has been
retrieved from a source. Returns the result. By default the logging messages is
constructed from the source's name and the result's size. This function is
automatically called at the end of method 'retrieve', so you do not have to
call it, if your source only implements the method _retrieve_rdf.

=head1 FUNCTIONS

=head2 source_uri ( $env | $uri )

Gets and or sets the request URI. You can either provide either a request URI
as byte string, or an environment as hash reference.  The environment must be a
specific subset of a L<PSGI> environment with the following variables:

=over 4

=item rdfsource.uri

A request URI as byte string. If this variable is provided, no other variables
are needed and the following variables will not modify this value.

=item psgi.url_scheme

A string C<http> (assumed if not set) or C<https>.

=item HTTP_HOST

The base URL of the host for constructing an URI. This or SERVER_NAME is
required unless rdfsource.uri is set.

=item SERVER_NAME

Name of the host for construction an URI. Only used if HTTP_HOST is not set.

=item SERVER_PORT

Port of the host for constructing an URI. By default C<80> is used, but not
kept as part of an HTTP-URI due to URI normalization.

=item SCRIPT_NAME

Path for constructing an URI. Must start with C</> if given.

=item QUERY_STRING

Portion of the request URI that follows the ?, if any.

=item rdfsource.ignorepath

If this variable is set, no query part is used when constructing an URI. 

=back

The method reuses code from L<Plack::Request> by Tatsuhiko Miyagawa. Note that
the environment variable REQUEST_URI is not included. When this method
constructs a request URI from a given environment hash, it always sets the
variable rdfsource.uri, so it is always guaranteed to be set after calling.

=head2 dummy_source

This source returns a single triple such as the following, based on the
request URI. The request URI is either taken from the PSGI request variable
'rdflight.uri' or build from the request's base and path:

    <http://example.org/your/request> rdf:type rdfs:Resource .

=head2 LOGGING

RDF::Source uses L<Log::Contextual> for logging. By default no logging messages
are created, unless you enable a logger.

To simply see what's going on:

  use Log::Contextual::SimpleLogger;
  use Log::Contextual qw( :log ),
     -logger => Log::Contextual::SimpleLogger->new({ levels => [qw(trace)]});

=head2 CACHING

The method/function 'cached' can be used to plug a cache in front of source.
It is based on L<Plack::Middleware::Cached> which is only required if you use
'cached'.

  use CHI;
  my $cache = CHI->new( ... );

  use RDF::Source qw(cached);
  my $cached_source = cached( $source, $cache );

=cut
