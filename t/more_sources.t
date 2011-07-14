use strict;
use warnings;

use Test::More;
use RDF::Source qw(union dummy_source);
use RDF::Trine::Model;
use RDF::Trine qw(iri statement);

my $example_model = RDF::Trine::Model->new;
$example_model->add_statement(statement( 
    map { iri("http://example.com/$_") } qw(subject predicate object) ));

# '/subject', [ 'Accept' => 'text/turtle' ] ],
#        content => qr{subject>.+predicate>.+object>},

# '/adverb', [ 'Accept' => 'text/turtle' ] ],
#  content => 'Not found',

my $source = union( $example_model, \&dummy_source );

# request => '/subject'
# content => qr{subject>.+predicate>.+object>},
#
ok( $source->retrieve('http://example.com/subject') );

# request => '/adverb'
# content => qr{adverb> a.+Resource>},

$source = sub { die "boo!"; };

# name => 'Failing source',
# request => '/foo'
# content => 'boo!'

#  name => 'Empty source',
#  source => sub { } ),
#  request => '/foo'

done_testing;
