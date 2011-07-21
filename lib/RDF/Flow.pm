use strict;
use warnings;
package RDF::Flow;
#ABSTRACT: RDF data flow aggregation

#TODO: use Log::Contextual 0.00305 (not at CPAN yet)
use Log::Contextual::WarnLogger;
use Log::Contextual qw(:log), -default_logger
    => Log::Contextual::WarnLogger->new({ env_prefix => __PACKAGE__ });

use RDF::Flow::Union;
use RDF::Flow::Cascade;
use RDF::Flow::Pipeline;
use RDF::Flow::Cached;

use RDF::Trine qw(iri);
use Scalar::Util qw(blessed reftype);

use URI;
use URI::Escape;

use Try::Tiny;
use parent 'Exporter';
use Carp;

our @EXPORT_OK = qw(
    rdflow rdflow_uri 
    cached union cascade pipeline
    has_retrieved
);
our %EXPORT_TAGS = (util => [qw(rdflow rdflow_uri)]);

our $PREVIOUS = rdflow( sub { shift->{'rdflow.data'} } );

sub new {
    my $class = shift;
    my ($src, %args) = ref($_[0]) ?  @_ : (undef,@_);

    my $code;

    if (blessed $src and $src->isa('RDF::Flow')) {
        return $src; # don't wrap
    } elsif ( blessed $src and $src->isa('RDF::Trine::Model') ) {
        $code = sub {
            my $uri = rdflow_uri( shift );
            $src->bounded_description( iri( $uri ) );
        };
    } elsif ( ref $src and ref $src eq 'CODE' ) {
        $code = $src;
    } elsif (not defined $src) {
        carp 'Missing source in plain RDF::Flow'
            if $class eq 'RDF::Flow';
        $code = sub { }; # TODO: warn?
    } else {
        croak 'expected RDF::Flow, RDF::Trine::Model, or code reference'
    }

    my $self = bless { }, $class;
    $self->{name} = $args{name} if defined $args{name};
    $self->{code} = $code;

    $self;
}

sub rdflow {
    RDF::Flow->new(@_)
}

sub name {
    shift->{name} || 'anonymous source';
}

*about = *name;

sub size {
    my $self = shift;
    return 1 unless $self->{sources};
    return scalar @{ $self->{sources} };
}

sub retrieve {
    my ($self, $env) = @_;
    $env = { 'rdflow.uri' => $env } if ($env and not ref $env);
    log_trace { 
        sprintf "retrieve from %s with %s", about($self), rdflow_uri($env);
    };
    $self->timestamp( $env );
    $self->has_retrieved( $self->_retrieve_rdf( $env ) );
}

sub _retrieve_rdf {
    my ($self, $env) = @_;
    return try { 
        $self->{code}->( $env );
    } catch {
        s/[.]?\s+$//s;
        RDF::Flow::source_error( $self, $_, $env );
        RDF::Trine::Model->new;
    }
}

sub union    { RDF::Flow::Union->new( @_ ) }
sub cascade  { RDF::Flow::Cascade->new( @_ ) }
sub pipeline { RDF::Flow::Pipeline->new( @_ ) }

sub has_content { # TODO: document this
    my $rdf = shift;
    return unless blessed $rdf;
    return ($rdf->isa('RDF::Trine::Model') and $rdf->size > 0) ||
           ($rdf->isa('RDF::Trine::Iterator') and $rdf->peek);
}

sub pipe_to { # TODO: document this
    my ($self, $next) = @_;
    return RDF::Flow::Pipeline->new( $self, $next );
}

sub previous { $RDF::Flow::PREVIOUS; }

sub rdflow_uri {
    my $env = shift;
    return ($env || '') unless ref $env; # plain scalar or undef

    return $env->{'rdflow.uri'} if defined $env->{'rdflow.uri'};

    # a few lines of code from Plack::Request, so we don't require all of Plack
    my $base = ($env->{'psgi.url_scheme'} || "http") .
        "://" . ($env->{HTTP_HOST} || (($env->{SERVER_NAME} || "") .
        ":" . ($env->{SERVER_PORT} || 80))) . ($env->{SCRIPT_NAME} || '/');
    $base = URI->new($base)->canonical;

    my $path_escape_class = '^A-Za-z0-9\-\._~/';

    my $path = URI::Escape::uri_escape( $env->{PATH_INFO} || '', $path_escape_class );

    $path .= '?' . $env->{QUERY_STRING} if !$env->{'rdflow.ignorepath'} &&
        defined $env->{QUERY_STRING} && $env->{QUERY_STRING} ne '';

    $base =~ s!/$!! if $path =~ m!^/!;

    $env->{'rdflow.uri'} = URI->new( $base . $path )->canonical;
    
    $env->{'rdflow.uri'} =~ s/^https?:\/\/\/$//;
    $env->{'rdflow.uri'};
}

sub cached {
    RDF::Flow::Cached->new( @_ );
}

sub source_error {
    my ($self, $message, $env) = @_;
    $message = 'unknown error' unless $message;
    $env->{'rdflow.error'} = $message if $env;
    log_error { $message };
}

sub has_retrieved {
    my ($self, $result, $msg) = @_;
    log_trace {
        $msg = "%s returned %s" unless $msg;
        my $size = 'no';
        if ( $result ) {
            $size = (blessed $result and $result->can('size')) 
                ? $result->size : 'some';
        };
        sprintf $msg, name($self), "$size triples";
    };
    return $result;
}

use POSIX qw(strftime);

# ISO 8601 timestamp
sub timestamp {
    my ($self, $env) = @_;
    my $now = time();
    my $tz = strftime("%z", localtime($now));
    $tz =~ s/(\d{2})(\d{2})/$1:$2/;
    $tz =~ s/00:00/Z/; # UTC aka Z-Time
    my $timestamp = strftime("%Y-%m-%dT%H:%M:%S", localtime($now)) . $tz;
    $env->{'rdflow.timestamp'} = $timestamp if $env;
    return $timestamp;
}

1;

__END__

=head1 DESCRIPTION

A source returns RDF data as instance of L<RDF::Trine::Model> or
L<RDF::Trine::Iterator> when queried by a L<PSGI> requests. This is
similar to PSGI applications, which return HTTP responses instead of
RDF data. RDF::Light supports three types of sources: code references,
instances of RDF::Flow, and instances of RDF::Trine::Model.

This package implements a data flow design. Call it RDF::Flow ?

=head1 SYNOPSIS

    # RDF::Flow as source
    $src = RDF::Flow->new( @other_sources );

    # retrieve RDF data
    $rdf = $src->retrieve( $env );
    $rdf = $src->( $env ); # use source as code reference

    # code reference as source
    $src = sub {
        my $env = shift;
        my $uri = RDF::Flow::uri( $env );
        my $model = RDF::Trine::Model->temporary_model;
        add_some_statements( $uri, $model );
        return $model;
    };

    # RDF::Trine::Model as source returns same as the following sub:
    $src = $model;
    $src = sub {
        my $uri = RDF::Flow::uri( shift );
        return $model->bounded_description( RDF::Trine::iri( $uri ) );
    }

    ($x and rdflow($x)) # check whether $x can be used as source

    # It is recommended to define your source as package
    package MySource;
    use parent 'RDF::Flow';

    sub retrieve {
        my ($self, $env) = shift;
        # ..your logic here...
    }

=method new ( [ @sources ] )

OUTDATED

Returns a new source, possibly by wrapping a set of other sources. Croaks if
any if the passes sources is no RDF::Flow, RDF::Trine::Model, or
CODE reference. This constructor can also be exported as function C<source>:

  use RDF::Flow qw(source);

  $src = source( @args );               # short form
  $src = RDF::Flow->source( @args );  # equivalent
  $src = RDF:Source->new( @args );      # explicit constructor

=method has_retrieved ( $source, $result [, $message ] )

Creates a logging event at trace level to log that some result has been
retrieved from a source. Returns the result. By default the logging messages is
constructed from the source's name and the result's size. This function is
automatically called at the end of method 'retrieve', so you do not have to
call it, if your source only implements the method _retrieve_rdf.

=method cached ( $cache )

Plugs a cache in front of a source. This method can also be exported as function.
Actually, it is a shortcut for L<RDF::Flow::Cached>-E<gt>new.

=head1 FUNCTIONS

=head2 rdflow

Constructor that does not copy existing RDF::Flow objects.

=head2 rdflow_uri ( $env | $uri )

Gets and/or sets the request URI. You can either provide either a request URI
as byte string, or an environment as hash reference.  The environment must be a
specific subset of a L<PSGI> environment with the following variables:

=over 4

=item rdflow.uri

A request URI as byte string. If this variable is provided, no other variables
are needed and the following variables will not modify this value.

=item psgi.url_scheme

A string C<http> (assumed if not set) or C<https>.

=item HTTP_HOST

The base URL of the host for constructing an URI. This or SERVER_NAME is
required unless rdflow.uri is set.

=item SERVER_NAME

Name of the host for construction an URI. Only used if HTTP_HOST is not set.

=item SERVER_PORT

Port of the host for constructing an URI. By default C<80> is used, but not
kept as part of an HTTP-URI due to URI normalization.

=item SCRIPT_NAME

Path for constructing an URI. Must start with C</> if given.

=item QUERY_STRING

Portion of the request URI that follows the ?, if any.

=item rdflow.ignorepath

If this variable is set, no query part is used when constructing an URI. 

=back

The method reuses code from L<Plack::Request> by Tatsuhiko Miyagawa. Note that
the environment variable REQUEST_URI is not included. When this method
constructs a request URI from a given environment hash, it always sets the
variable C<rdflow.uri>, so it is always guaranteed to be set after calling.
However it may be the empty string, if an environment without HTTP_HOST or
SERVER_NAME was provided.

=head2 LOGGING

RDF::Flow uses L<Log::Contextual> for logging. By default no logging messages
are created, unless you enable a logger.

To simply see what's going on:

  use Log::Contextual::SimpleLogger;
  use Log::Contextual qw( :log ),
     -logger => Log::Contextual::SimpleLogger->new({ levels => [qw(trace)]});


=head2 LIMITATIONS

The current version of this module does not check for circular references.
Another environment variable such as C<rdflow.depth> or C<rdflow.stack> may
help.

=head2 SEE ALSO

There are some CPAN modules for general data flow processing, such as L<Flow>
and L<DataFlow>. As RDF::Flow is inspired by L<PSGI>, you should also have a
look at the PSGI toolkit L<Plack>. RDF-related Perl modules are collected at
L<http://www.perlrdf.org/>.

=cut
