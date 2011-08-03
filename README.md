# NAME

RDF::Flow - RDF data flow pipeline

# VERSION

version 0.169

# SYNOPSIS

    # define sources
    $src = rdflow( \&mysub, name => "code reference as source" );
    $src = rdflow( $model, name => "RDF::Trine::Model as source" );

    # using a RDF::Trine::Model as source is equivalent to:
    $src = rdflow( sub {
        my $env = shift;
        my $uri = RDF::Flow::uri( $env );
        return $model->bounded_description( RDF::Trine::iri( $uri ) );
    });



    # retrieve RDF data
    $rdf = $src->retrieve( $uri ); 
    $rdf = $src->retrieve( $env ); # with $env->{'rdflow.uri'}

    # code reference as source (more detailed example)
    $src = rdflow( sub {
        my $uri = RDF::Flow::uri( $env );
        my $model = RDF::Trine::Model->temporary_model;
        add_some_statements( $uri, $model );
        return $model;
    });



    # It is recommended to define your source as package
    package MySource;
    use parent 'RDF::Flow';

    sub retrieve {
        my ($self, $env) = shift;
        # ..your logic here...
    }

# DESCRIPTION

RDF::Flow provides a simple framework on top of [RDF::Trine](http://search.cpan.org/perldoc?RDF::Trine) to
define and connect RDF sources in data flow pipes.

# FUNCTIONS

## rdflow

Shortcut to create a new source with [RDF::FLow::Source](http://search.cpan.org/perldoc?RDF::FLow::Source).

## rdflow_uri ( $env | $uri )

Gets and/or sets the request URI. You can either provide either a request URI
as byte string, or an environment as hash reference.  The environment must be a
specific subset of a [PSGI](http://search.cpan.org/perldoc?PSGI) environment with the following variables:

- rdflow.uri

A request URI as byte string. If this variable is provided, no other variables
are needed and the following variables will not modify this value.

- psgi.url_scheme

A string `http` (assumed if not set) or `https`.

- HTTP_HOST

The base URL of the host for constructing an URI. This or SERVER_NAME is
required unless rdflow.uri is set.

- SERVER_NAME

Name of the host for construction an URI. Only used if HTTP_HOST is not set.

- SERVER_PORT

Port of the host for constructing an URI. By default `80` is used, but not
kept as part of an HTTP-URI due to URI normalization.

- SCRIPT_NAME

Path for constructing an URI. Must start with `/` if given.

- QUERY_STRING

Portion of the request URI that follows the ?, if any.

- rdflow.ignorepath

If this variable is set, no query part is used when constructing an URI. 

The method reuses code from [Plack::Request](http://search.cpan.org/perldoc?Plack::Request) by Tatsuhiko Miyagawa. Note that
the environment variable REQUEST_URI is not included. When this method
constructs a request URI from a given environment hash, it always sets the
variable `rdflow.uri`, so it is always guaranteed to be set after calling.
However it may be the empty string, if an environment without HTTP_HOST or
SERVER_NAME was provided.

## LOGGING

RDF::Flow uses [Log::Contextual](http://search.cpan.org/perldoc?Log::Contextual) for logging. By default no logging messages
are created, unless you enable a logger.

To simply see what's going on:

  use Log::Contextual::SimpleLogger;
  use Log::Contextual qw( :log ),
     -logger => Log::Contextual::SimpleLogger->new({ levels => [qw(trace)]});

## LIMITATIONS

The current version of this module does not check for circular references.
Another environment variable such as `rdflow.depth` or `rdflow.stack` may
help.

## SEE ALSO

There are some CPAN modules for general data flow processing, such as [Flow](http://search.cpan.org/perldoc?Flow)
and [DataFlow](http://search.cpan.org/perldoc?DataFlow). As RDF::Flow is inspired by [PSGI](http://search.cpan.org/perldoc?PSGI), you should also have a
look at the PSGI toolkit [Plack](http://search.cpan.org/perldoc?Plack). RDF-related Perl modules are collected at
[http://www.perlrdf.org/](http://www.perlrdf.org/).

The presentation "RDF Data Pipelines for Semantic Data Federation", includes
more RDF Pipelining research references: [http://dbooth.org/2011/pipeline/](http://dbooth.org/2011/pipeline/).

# AUTHOR

Jakob Voß <voss@gbv.de>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Jakob Voß.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.