use strict;
use warnings;
package RDF::Source::Cascade;
#ABSTRACT: Returns the first non-empty response of a sequence of sources

use Log::Contextual::WarnLogger;
use Log::Contextual qw(:log), -default_logger 
    => Log::Contextual::WarnLogger->new({ env_prefix => __PACKAGE__ });

use parent 'RDF::Source';
our @EXPORT = qw(cascade);

use Scalar::Util 'blessed';
use Carp 'croak';

sub new {
    my $class = shift;
	bless { 
        sources => [ map { RDF::Source::source($_) } @_ ],
        name    => 'anonymous cascade'
    } , $class;
}

sub retrieve { # TODO: try/catch errors?
    my ($self, $env) = @_;

    log_trace { 
        'retrieve from ' . $self->name . ' with ' . $self->size . ' sources' 
    };

    my $i = 1;
    my $rdf;
    foreach my $src ( @{$self->{sources}} ) {
        $rdf = $src->retrieve( $env );

		next unless defined $rdf;
		if ( blessed $rdf and $rdf->isa('RDF::Trine::Model') ) {
	        last if $rdf->size > 0;
		} elsif ( blessed $rdf and $rdf->isa('RDF::Trine::Iterator') ) {
	        last if $rdf->peek;
	    } else {
		    croak 'unexpected response in source union: '.$rdf;
		}

        $i++;
    }

    log_trace { 
        $self->name . " returned $i. with " . (defined $rdf ? $rdf->size : 'no') . ' triples'
    };

    return $rdf;
}

sub cascade { RDF::Source::Cascade->new(@_) }

1;

__END__

=head1 DESCRIPTION

This L<RDF::Source> returns the first non-empty response of a given
sequence of sources. It exports the function 'cascade' as constructor shortcut.

=head1 SYNOPSIS

	use RDF::Source::Cascade;

	$src = cascade(@sources);                            # shortcut
    $src = RDF::Source::Cascade->new( @sources ); # explicit
	$rdf = $src->retrieve( $env );

=head2 SEE ALSO

L<RDF::Source::Union>, L<RDF::Source::Pipeline>

=cut
