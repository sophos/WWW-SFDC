package WWW::SFDC::Tooling;
# ABSTRACT: Interface to the Salesforce.com Tooling API

use 5.12.0;
use strict;
use warnings;

# VERSION

use Log::Log4perl ':easy';
use Scalar::Util 'blessed';

use Moo;
with 'WWW::SFDC::Role::SessionConsumer', 'WWW::SFDC::Role::CRUD';

=head1 SYNOPSIS

   my $result = SFDC::tooling->instance(creds => {
    username => $USER,
    password => $PASS,
    url => $URL
   })->executeAnonymous("System.debug(1);");

Note that $URL is the _login_ URL, not the Tooling API endpoint URL - which gets calculated internally.

=cut

has 'uri',
  is => 'ro',
  default => 'urn:tooling.soap.sforce.com';

sub _extractURL {
  return $_[1]->{serverUrl} =~ s{/u/}{/T/}r;
}

=method create

=cut

sub _prepareSObjects {
  my $self = shift;
  # prepares an array of objects for an update or insert call by converting
  # it to an array of SOAP::Data

  # THIS IMPLEMENTATION IS DIFFERENT TO THE EQUIVALENT PARTNER API IMPLEMENTATION

  TRACE "objects for operation" => \@_;

  return map {
      my $obj = $_;
      my $type;
      if ($obj->{type}) {
        $type = $obj->{type};
        delete $obj->{type};
      }

      SOAP::Data->name(sObjects => \SOAP::Data->value(
        map {
          (blessed ($obj->{$_}) and blessed ($obj->{$_}) eq 'SOAP::Data')
            ? $obj->{$_}
            : SOAP::Data->name($_ => $obj->{$_})
        } keys %$obj
      ))->type($type)
    } @_;
}

=method describeGlobal

=cut

sub describeGlobal {
  ...
}

=method describeSObjects

=cut

sub describeSObjects {
  ...
}

=method executeAnonymous

    WWW::SFDC::Tooling->instance()->executeAnonymous("system.debug(1);")

=cut

sub executeAnonymous {
  my ($self, $code, %options) = @_;
  my $result = $self->_call(
    'executeAnonymous',
    SOAP::Data->name(string => $code),
    $options{debug} ? SOAP::Header->name('DebuggingHeader' => \SOAP::Data->name(
        debugLevel => 'DEBUGONLY'
      )) : (),
   );

  LOGDIE "ExecuteAnonymous failed to compile: " . $result->{compileProblem}
    if $result->{compiled} eq "false";

  LOGDIE "ExecuteAnonymous failed to complete: " . $result->{exceptionMessage}
    if $result->{success} eq "false";

  return $result;
}

=method runTests

  SFDC::Tooling->instance()->runTests('name','name2');

=cut

sub runTests {
  my ($self, @names) = @_;

  return $self->_call(
    'runTests',
    map {\SOAP::Data->name(classes => $_)} @names
  );
}

=method runTestsAsynchronous

=cut

sub runTestsAsynchronous {
  my ($self, @ids) = @_;

  return $self->_call('runTestsAsynchronous', join ",", @ids);
}

1;

__END__

=head1 BUGS

Please report any bugs or feature requests at L<https://github.com/alexander-brett/WWW-SFDC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::SFDC::Tooling

You can also look for information at L<https://github.com/alexander-brett/WWW-SFDC>
