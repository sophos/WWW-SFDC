#!/usr/bin/env perl
package WWW::SFDC::Apex;
# ABSTRACT: Interface to the salesforce.com Apex SOAP Api

use 5.12.0;
use strict;
use warnings;

# VERSION

use Log::Log4perl ':easy';
use Method::Signatures;
use SOAP::Lite;

use WWW::SFDC::Apex::ExecuteAnonymousResult;

use Moo;
with "WWW::SFDC::Role::SessionConsumer";

has 'uri',
    is => 'ro',
    default=> "http://soap.sforce.com/2006/08/apex";

sub _extractURL {
    return $_[1]->{serverUrl} =~ s{/u/}{/s/}r;
}


=method compileAndTest

=cut

sub compileAndTest () {
  ...
}

=method compileClasses

=cut

sub compileClasses {
  ...
}

=method compileTriggers

=cut

sub compileTriggers {
  ...
}

=method executeAnonymous

Returns a WWW::SFDC::Apex::ExecuteAnonymousResult containing the results of the
executeAnonymous call. You must manually check whether this succeeded.

=cut

method executeAnonymous ($code, :$debug = 1) {

  my $callResult = $self->_call(
    'executeAnonymous',
    SOAP::Data->name(string => $code),
    (
      $debug
        ? SOAP::Header->name('DebuggingHeader' => \SOAP::Data->name(
            debugLevel => 'DEBUGONLY'
          ))->uri($self->uri)
        : ()
    ),
  );

  return WWW::SFDC::Apex::ExecuteAnonymousResult->new(
    _result => $callResult->result,
    _headers => $callResult->headers
  );
}

=method runTests

=cut

sub runTests {
  ...
}

=method wsdlToApex

=cut

sub wsdlToApex {
    ...
}

1;

__END__

=head1 WARNING

The only implemented method from the Apex API is currently executeAnonymous.
Without a solid use-case for the other methods, I'm not sure what the return
values of those calls should be.

If you want to implement those calls, please go ahead, constructing results
as you see fit, and submit a pull request!
