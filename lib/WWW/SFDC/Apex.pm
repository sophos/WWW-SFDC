#!/usr/bin/env perl
package WWW::SFDC::Apex;
# ABSTRACT: Interface to the salesforce.com Apex SOAP Api

use 5.12.0;
use strict;
use warnings;

use Log::Log4perl ':easy';
use SOAP::Lite;

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

sub compileAndTest {
  my ($self, @names) = @_;

  return $self->_call(
    'compileAndTest',
    map {\SOAP::Data->name(classes => $_)} @names
    );
}

=method compileClasses

=cut

sub compileClasses {
  my ($self, @names) = @_;

  return $self->_call(
    'compileClasses',
    SOAP::Data->value(map {SOAP::Data->name(scripts => $_)} @names)
    );
}

=method compileTriggers

=cut

sub compileTriggers {
  my ($self, @names) = @_;

  return $self->_call(
    'compileTriggers',
    map {\SOAP::Data->name(classes => $_)} @names
    );
}

=method executeAnonymous

=cut

sub executeAnonymous {
  my ($self, $code, %options) = @_;
  my ($result, $headers) = $self->_call(
    'executeAnonymous',
    SOAP::Data->name(string => $code),
    $options{debug} ? SOAP::Header->name('DebuggingHeader' => \SOAP::Data->name(
        debugLevel => 'DEBUGONLY'
      ))->uri($self->uri) : (),
   );

  LOGDIE "ExecuteAnonymous failed to compile: " . $result->{compileProblem}
    if $result->{compiled} eq "false";

  LOGDIE "ExecuteAnonymous failed to complete: " . $result->{exceptionMessage}
    if ($result->{success} eq "false");

  return $result, (defined $headers ? $headers->{debugLog} : ());
}

=method runTests

=cut

sub runTests {
  my ($self, @names) = @_;

  return $self->_call(
    'runTests',
    map {\SOAP::Data->name(classes => $_)} @names
    );
}

=method wsdlToApex

Unimplemented

=cut

sub wsdlToApex {
    ...
}

1;

__END__
