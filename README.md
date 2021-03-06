# NAME

RDF::Flow - RDF data flow pipeline

# VERSION

version 0.178

# SYNOPSIS

    # define RDF sources (see RDF::Flow::Source)
    $src = rdflow( "mydata.ttl", name => "RDF file as source" );
    $src = rdflow( "mydirectory", name => "directory with RDF files as source" );
    $src = rdflow( \&mysub, name => "code reference as source" );
    $src = rdflow( $model,  name => "RDF::Trine::Model as source" );

    # using a RDF::Trine::Model as source is equivalent to:
    $src = RDF::Flow->new( sub {
        my $env = shift;
        my $uri = RDF::Flow::uri( $env );
        return $model->bounded_description( RDF::Trine::iri( $uri ) );
    } );

    # retrieve RDF data
    $rdf = $src->retrieve( $uri );
    $rdf = $src->retrieve( $env ); # uri constructed from $env

    # code reference as source (more detailed example)
    $src = rdflow( sub {
        my $uri = RDF::Flow::uri( $env );
        my $model = RDF::Trine::Model->temporary_model;
        add_some_statements( $uri, $model );
        return $model;
    });

# DESCRIPTION

RDF::Flow provides a simple framework on top of [RDF::Trine](http://search.cpan.org/perldoc?RDF::Trine) to define and
connect RDF sources in data flow pipes. In a nutshell, a source is connected
to some data (possibly RDF but it could also wrap any other forms) and you
can retrieve RDF data from it, based on a request URI:

                     +--------+
    Request (URI)--->+ Source +-->Response (RDF)
                     +---+----+
                         ^
                Data (possibly RDF)

The base class to define RDF sources is [RDF::Flow::Source](http://search.cpan.org/perldoc?RDF::Flow::Source), so please have a
look at the documentation of this class. Multiple sources can be connected to
data flow networks: Predefined sources exist to combine sources
([RDF::Flow::Union](http://search.cpan.org/perldoc?RDF::Flow::Union), [RDF::Flow::Pipeline](http://search.cpan.org/perldoc?RDF::Flow::Pipeline), [RDF::Flow::Cascade](http://search.cpan.org/perldoc?RDF::Flow::Cascade)), to access
LinkedData ([RDF::Flow::LinkedData](http://search.cpan.org/perldoc?RDF::Flow::LinkedData)), to cache requests
([RDF::Flow::Cached](http://search.cpan.org/perldoc?RDF::Flow::Cached)), and for testing ([RDF::Flow::Dummy](http://search.cpan.org/perldoc?RDF::Flow::Dummy)).

# EXPORTED FUNCTIONS

By default this module only exports `rdflow` as constructor shortcut.
Additional shortcut functions can be exported on request. The `:all`
tag exports all functions.

- `rdflow`

Shortcut to create a new source with [RDF::Flow::Source](http://search.cpan.org/perldoc?RDF::Flow::Source).

- `cached`

Shortcut to create a new cached source with [RDF::Flow::Cached](http://search.cpan.org/perldoc?RDF::Flow::Cached).

- `cascade`

Shortcut to create a new source cascade with [RDF::Flow::Cascade](http://search.cpan.org/perldoc?RDF::Flow::Cascade).

- `pipeline`

Shortcut to create a new source pipeline with [RDF::Flow::Pipeline](http://search.cpan.org/perldoc?RDF::Flow::Pipeline).

- `previous`

A source that always returns `rdflow.data` without modification.

- `union`

Shortcut to create a new union of sources with [RDF::Flow::Union](http://search.cpan.org/perldoc?RDF::Flow::Union).

## LOGGING

RDF::Flow uses [Log::Contextual](http://search.cpan.org/perldoc?Log::Contextual) for logging. By default no logging messages
are created, unless you enable a logger.  To simply see what's going on in
detail, enable a simple logger:

    use Log::Contextual::SimpleLogger;
    use Log::Contextual qw( :log ),
       -logger => Log::Contextual::SimpleLogger->new({ levels => [qw(trace)]});

# DEFINING NEW SOURCE TYPES

Basically you must only derive from [RDF::Flow::Source](http://search.cpan.org/perldoc?RDF::Flow::Source) and create the method
`retrieve_rdf`:

    package MySource;
    use parent 'RDF::Flow::Source';
    use RDF::Flow::Source qw(:util); # if you need utilty functions

    sub retrieve_rdf {
        my ($self, $env) = @_;
        my $uri = $env->{'rdflow.uri'};

        # ... your logic here ...

        return $model;
    }

# LIMITATIONS

The current version of this module does not check for circular references if
you connect multiple sources.  Maybe environment variable such as `rdflow.depth`
or `rdflow.stack` will be introduced. Surely performance can also be increased.

# SEE ALSO

You can use this module together with [Plack::Middleware::RDF::Flow](http://search.cpan.org/perldoc?Plack::Middleware::RDF::Flow) (available
at [at github](https://github.com/nichtich/Plack-Middleware-RDF-Flow)) to create
Linked Data applications.

There are some CPAN modules for general data flow processing, such as [Flow](http://search.cpan.org/perldoc?Flow)
and [DataFlow](http://search.cpan.org/perldoc?DataFlow). As RDF::Flow is inspired by [PSGI](http://search.cpan.org/perldoc?PSGI), you should also have a
look at the PSGI toolkit [Plack](http://search.cpan.org/perldoc?Plack). Some RDF sources can also be connected
with [RDF::Trine::Model::Union](http://search.cpan.org/perldoc?RDF::Trine::Model::Union) and [RDF::Trine::Model::StatementFilter](http://search.cpan.org/perldoc?RDF::Trine::Model::StatementFilter).
More RDF-related Perl modules are collected at [http://www.perlrdf.org/](http://www.perlrdf.org/).

Research references on RDF pipelining can be found in the presentation "RDF
Data Pipelines for Semantic Data Federation", more elaborated and not connected
to this module: [http://dbooth.org/2011/pipeline/](http://dbooth.org/2011/pipeline/). Another framework for
RDF integration based on a pipe model is RDF Gears:
[https://bitbucket.org/feliksik/rdfgears/](https://bitbucket.org/feliksik/rdfgears/).

# AUTHOR

Jakob Voß <voss@gbv.de>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Jakob Voß.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.