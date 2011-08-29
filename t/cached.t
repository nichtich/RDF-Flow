use strict;
use warnings;

use Test::More;
use Test::RDF;
use RDF::Trine qw(statement iri literal);
use RDF::Trine::Iterator;
use RDF::Flow qw(cached rdflow);
use RDF::Flow::Source qw(rdflow_uri);

{
    package OneTimeCache;
    sub new { bless { }, shift }
    sub get { $_ = $_[0]->{$_[1]}; delete $_[0]->{$_[1]}; $_; }
    sub set { $_[0]->{$_[1]} = $_[2] }
}

sub make_model {
    my $model = RDF::Trine::Model->new;
    $model->add_statement(statement(
        iri($_[0]),
        iri('http://www.w3.org/1999/02/22-rdf-syntax-ns#value'),
        literal($_[1])));
    return $model;
}

my $count = 1;
sub counting_source { make_model( rdflow_uri(shift), $count++ ) }

my $cache = OneTimeCache->new;
my $source = cached( \&counting_source, $cache );

my $env = { 'rdflow.uri' => 'x:foo' };
my $rdf = $source->retrieve( $env );
isomorph_graphs( $rdf, make_model('x:foo', 1), 'first request: foo' );
ok( !$env->{'rdflow.cached'}, 'not cached' );

$env->{'rdflow.uri'} = 'x:bar';
$rdf = $source->retrieve( $env );
isomorph_graphs( $rdf, make_model('x:bar', 2), 'second request: bar' );
ok( !$env->{'rdflow.cached'}, 'not cached' );

$env->{'rdflow.uri'} = 'x:foo';
$rdf = $source->retrieve( $env );
isomorph_graphs( $rdf, make_model('x:foo', 1), 'second request: foo' );
ok( $env->{'rdflow.cached'}, 'cached' );
like( $env->{'rdflow.timestamp'}, qr{^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d}, 'with timestamp' );

$env = { 'rdflow.uri' => 'x:foo' };
$rdf = $source->retrieve( $env );
isomorph_graphs( $rdf, make_model('x:foo', 3), 'third request: foo' );
ok( !$env->{'rdflow.cached'}, 'not cached' );

my $model = make_model('x:foo', 'bar');
$source = rdflow( sub { $model->as_stream; } );
$cache = OneTimeCache->new;
$source = cached( $source, $cache );

$env = { 'rdflow.uri' => 'x:foo' };
$rdf = $source->retrieve( $env );
isomorph_graphs( $rdf, $model, 'new from iterator source' );
ok( !$env->{'rdflow.cached'}, 'not cached' );

$env = { 'rdflow.uri' => 'x:foo' };
$rdf = $source->retrieve( $env );
ok( $env->{'rdflow.cached'}, 'now cached' );

done_testing;
