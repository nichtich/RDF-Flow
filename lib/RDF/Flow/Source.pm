use strict;
use warnings;
package RDF::Flow::Source;
#ABSTRACT: Source of RDF data

use Log::Contextual::WarnLogger;
use Log::Contextual qw(:log), -default_logger
    => Log::Contextual::WarnLogger->new({ env_prefix => __PACKAGE__ });

use RDF::Trine qw(iri);
use Scalar::Util qw(blessed refaddr);
use Try::Tiny;
use Carp;

use RDF::Trine::Model;
use RDF::Trine::Parser;
use RDF::Flow::Util;
use RDF::Flow::Pipeline;

sub new {
    my $class = shift;
    my ($src, %args) = ref($_[0]) ?  @_ : (undef,@_);

    $src = delete $args{from} unless defined $src;

    my $code;

    if ( $src and not ref $src ) { # load from file
        my $model = RDF::Trine::Model->new;
        eval { RDF::Trine::Parser->parse_file_into_model( "file:///$src", $src, $model ); };
        if ( @_ ) {
            log_info { "failed to loaded from $src"; }
        } else {
            log_info { "loaded from $src"; }
        }
        $src = $model;
    }

    if (blessed $src and $src->isa('RDF::Flow::Source')) {
        return $src; # don't wrap
        # TODO: use args to modify object!
    } elsif ( blessed $src and $src->isa('RDF::Trine::Model') ) {
        $code = sub {
            my $uri = rdflow_uri( shift );
            iterator_to_model( $src->bounded_description(
                iri( $uri )
            ) );
        };
    } elsif ( ref $src and ref $src eq 'CODE' ) {
        $code = $src;
    } elsif (not defined $src) {
        carp 'Missing RDF source in plain RDF::Flow::Source'
            if $class eq 'RDF::Flow::Source';
        $code = sub { };
    } else {
        croak 'expected RDF::Source, RDF::Trine::Model, or code reference'
    }

    my $self = bless { }, $class;
    $self->{name} = $args{name} if defined $args{name};
    $self->{code} = $code;

    $self;
}

sub retrieve {
    my ($self, $env) = @_;
    $env = { 'rdflow.uri' => $env } if ($env and not ref $env);
    log_trace {
        sprintf "retrieve from %s with %s", about($self), rdflow_uri($env);
    };
    $self->timestamp( $env );
    $self->has_retrieved( $self->retrieve_rdf( $env ) );
}

sub retrieve_rdf {
    my ($self, $env) = @_;
    return try {
        $self->{code}->( $env );
    } catch {
        s/[.]?\s+$//s;
        RDF::Flow::Source::source_error( $self, $_, $env );
        RDF::Trine::Model->new;
    }
}



sub pipe_to { # TODO: document this
    my ($self, $next) = @_;
    return RDF::Flow::Pipeline->new( $self, $next );
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

sub id {
    return "source".refaddr(shift);
}


sub graphviz {
    return scalar shift->graphviz_addnode( @_ );
}

sub graphviz_addnode {
    my $self = shift;
    my $g = ( blessed $_[0] and $_[0]->isa('GraphViz') )
            ? shift : eval { GraphViz->new( @_ ) };
    return unless $g;

    $g->add_node( $self->id, $self->_graphviz_nodeattr );

    my $i=1;
    foreach my $s ( $self->inputs ) {
        $s->graphviz($g);
        $g->add_edge( $s->id, $self->id, $self->_graphviz_edgeattr($i++) );
    }

    return $g;
}

sub _graphviz_nodeattr {
    return (label => shift->name);
}

sub _graphviz_edgeattr { }

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

sub cached   { RDF::Flow::Cached->new( @_ ); }

sub name {
    shift->{name} || 'anonymous source';
}

sub about {
    shift->name;
}

sub inputs {
    my $self = shift;
    return $self->{inputs} ? @{ $self->{inputs} } : ();
}

sub size {
    my $self = shift;
    return 1 unless $self->{inputs};
    return scalar @{ $self->{inputs} };
}

1;

=head1 SYNOPSIS

    $src = rdflow( \&mysource, name => "code reference as source" );
    $src = rdflow( $model, name => "RDF::Trine::Model as source" );

    package MySource;
    use parent 'RDF::Flow::Source';

    sub retrieve_rdf {
        my ($self, $env) = @_;
        my $uri = $env->{'rdflow.uri'};

        # ... your logic here ...

        return $model;
    }

=method new ( $source {, name => $name } )

Create a new RDF source by wrapping a code reference or a L<RDF::Trine::Model>.
If you pass an existing RDF::Flow::Source object, it will not be wrapped.

A source returns RDF data as instance of L<RDF::Trine::Model> or
L<RDF::Trine::Iterator> when queried by a L<PSGI> requests. This is
similar to PSGI applications, which return HTTP responses instead of
RDF data. RDF::Light supports three types of sources: code references,
instances of RDF::Flow, and instances of RDF::Trine::Model.

This constructor is exported as function C<rdflow> by L<RDF::Flow>:

  use RDF::Flow qw(rdflow);

  $src = rdflow( @args );               # short form
  $src = RDF:Source->new( @args );      # explicit constructor

=method has_retrieved ( $source, $result [, $message ] )

Creates a logging event at trace level to log that some result has been
retrieved from a source. Returns the result. By default the logging messages is
constructed from the source's name and the result's size. This function is
automatically called at the end of method 'retrieve', so you do not have to
call it, if your source only implements the method C<retrieve_rdf>.

=method name

=method about

=method size

=method inputs

=method timestamp

=method source_error

=method id

=method retrieve

=method retrieve_rdf

=method pipe_to

=method cached ( $cache )

Plugs a cache in front of a source. This method can also be exported as function.
Actually, it is a shortcut for L<RDF::Flow::Cached>-E<gt>new.

=method graphviz

Experimental.

=method graphviz_addnode

Experimental.

=cut
