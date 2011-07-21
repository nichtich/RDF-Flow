use strict;
use warnings;

use Test::More;
use RDF::Flow qw(rdflow_uri);
use RDF::Flow::Dummy;
use RDF::Trine::Serializer::Turtle;

my $ser = RDF::Trine::Serializer::Turtle->new;

my $ttl1 = "<http://example.org/x> a <http://www.w3.org/2000/01/rdf-schema#Resource> .\n";
my $time = qr/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(Z|[+-]\d\d:\d\d)$/;

my $dummy = RDF::Flow::Dummy->new( name => 'foo' );

my $rdf = $dummy->retrieve( "http://example.org/x" );
is( $ser->serialize_model_to_string($rdf), $ttl1, 'retriev from plain URI' );

my $env = { };
$rdf = $dummy->retrieve( $env );
isa_ok( $rdf, 'RDF::Trine::Model', 'valid response' );
is( $rdf->size, 0, 'empty response' );

$env = { 'rdflow.uri' => "http://example.org/x" };
$rdf = $dummy->retrieve( $env );
is( $ser->serialize_model_to_string($rdf), $ttl1, 'retriev from env (URI given)' );
like( $env->{'rdflow.timestamp'}, $time, 'timestamp has been set' );

$env = { HTTP_HOST => "example.org", SCRIPT_NAME => '/x', };
$rdf = $dummy->retrieve( $env );
is( $ser->serialize_model_to_string($rdf), $ttl1, 'retriev from env (URI build)' );

done_testing;
