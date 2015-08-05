package WWW::SFDC::CallResult;
# ABSTRACT: Provides a flexible container for calls to SFDC containers
use strict;
use warnings;
use overload
  bool => sub {!$_[0]->request->fault};

# VERSION


use Log::Log4perl ':easy';

use Moo;

=attr request

The original request sent to SFDC. This is a SOAP::SOM.

=cut

has 'request',
  is => 'ro',
  required => 1;

=attr headers

A hashref of headers from the call, which might contain, for example, usage
limit info or debug logs.

=cut

has 'headers',
  is => 'ro',
  lazy => 1,
  builder => sub {
    return $_[0]->request->headers()
  };

=attr result

The result of the call. This is appropriate when expecting a scalar - for
instance, a deployment ID.

=cut

has 'result',
  is => 'ro',
  lazy => 1,
  builder => sub {
    $_[0]->request->result;
  };

=attr results

The results of the call. This is appropriate when recieving a list of results,
for instance when querying or updating data.

=cut

has 'results',
  is => 'ro',
  lazy => 1,
  builder => sub {
    my $results = [$_[0]->request->paramsall()];
    TRACE sub { Dumper $results};
    return $results;
  };

1;

__END__

