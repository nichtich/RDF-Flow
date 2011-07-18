use strict;
use warnings;

use Test::More;
use Test::RDF;
use RDF::Trine qw(statement iri);
use RDF::Source qw(source_uri);

sub simple_source { 
    my $env = shift;
    my $uri = source_uri($env);

    my $model = RDF::Trine::Model->new;
    $model->add_statement(statement( 
        iri($uri), iri('x:foo'), iri('x:bar')
    ));

    return $model;
};

my $source = RDF::Source->new( \&simple_source );

my $env = make_query('/hello'); 
my $rdf = $source->retrieve($env);

isa_ok( $rdf, 'RDF::Trine::Model', 'simple source returns RDF::Trine::Model' );
# use RDF::Dumper; print rdfdump($rdf)."\n";

$source = MySource->new;
$rdf = $source->retrieve($env);
isa_ok( $rdf, 'RDF::Trine::Model', 'simple source returns RDF::Trine::Model' );

my $uri = RDF::Source::source_uri( { HTTP_HOST => "example.org", SCRIPT_NAME => '/x', } );
is( $uri, 'http://example.org/x', 'source_uri' );

done_testing;


sub make_query { 
    return { HTTP_HOST => 'example.org', PATH_INFO => shift };
}


package MySource;
use base 'RDF::Source';

sub retrieve { 
    RDF::Source::dummy_source( shift ) 
}

1;
