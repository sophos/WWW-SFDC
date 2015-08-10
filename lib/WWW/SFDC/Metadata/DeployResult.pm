package WWW::SFDC::Metadata::DeployResult;
# ABSTRACT: Container for Salesforce Metadata API Deployment result

use strict;
use warnings;

# VERSION

use Log::Log4perl ':easy';

use overload
  '""' => sub {
    return $_[0]->id;
  };

use Moo;

=attr id

The deployment ID. When stringified, this is the object's value.

=cut

has 'id',
  is => 'ro',
  lazy => 1,
  builder => sub {return $_[0]->result->{id}};

=attr success

A boolean representing whether the deployment's status is 'Succeeded'.

=cut

has 'success',
  is => 'ro',
  lazy => 1,
  builder => sub {return $_[0]->result->{status} eq 'Succeeded'};

=attr complete

A boolean representing whether the deployment is in any complete status,
successful or otherwise.

=cut

has 'complete',
  is => 'ro',
  lazy => 1,
  builder => sub {
    return $_[0]->result->{status} !~ /Queued|Pending|InProgress/;
  };

=attr result

The 'result' element of a SOAP::SOM returned from a Salesforce Deploy call.
This is used for the generation of all other attributes.

=cut

has 'result',
  is => 'ro',
  required => 1;

=attr testFailures

An arrayref of testResults, sorted by class name and method name.

=cut

has 'testFailures',
  is => 'ro',
  lazy => 1,
  builder => sub {
    my $self = shift;
    return []
      if $self->result->{runTestsEnabled} eq 'false'
      or $self->result->{numberTestErrors} == 0
      or not $self->result->{details};
    return ref $self->result->{details}->{runTestResult}->{failures} eq 'ARRAY'
      ? [
        sort {$a->{name}.$a->{methodName} cmp $b->{name}.$b->{methodName}}
          @{$self->result->{details}->{runTestResult}->{failures}}
      ]
      : [$self->result->{details}->{runTestResult}->{failures}]
  };

=attr testFailures

An arrayref of failed components, sorted by file name and component name.

=cut

has 'componentFailures',
  is => 'ro',
  lazy => 1,
  builder => sub {
    my $self = shift;
    return []
      if $self->result->{numberComponentErrors} == 0
      or not $self->result->{details};
    return ref $self->result->{details}->{componentFailures} eq 'ARRAY'
      ? [
        sort {$a->{fileName}.$a->{fullName} cmp $b->{fileName}.$b->{fullName}}
          @{$self->result->{details}->{componentFailures}}
      ]
      : [$self->result->{details}->{componentFailures}]
  };

sub BUILD {
  my $self = shift;
  INFO "Deployment Status:\t"
    . $self->result->{status}
    . (
      $self->result->{stateDetail}
        ? " - " . $self->result->{stateDetail}
        : ""
    );
}

=method testFailuresSince($previous)

Here, $previous is another WWW::SFDC::Metadata::DeployResult. This attribute
holds all failures that are new in this result compared to the previous one.
This is useful for providing a running commentary on what's failed so far.

=cut

sub testFailuresSince {
  my ($self, $previous) = @_;
  return ()
    if $self->result->{runTestsEnabled} eq 'false'
    or $self->result->{numberTestErrors} == 0
    or (
      $previous
      and $previous->result->{numberTestErrors} == $self->result->{numberTestErrors}
    );

  my @oldResults = $previous ? @{$previous->testFailures} : ();
  my @newResults;
  my $i = 0;
  for my $failure (@{$self->testFailures}) {
    if (
      scalar @oldResults > $i
      and $failure->{name}.$failure->{methodName} cmp $oldResults[$i]->{name}.$oldResults[$i]->{methodName}
    ) {
      $i++;
    } else {
      push @newResults, $failure;
    }
  }

  return @newResults
}

=method componentFailuresSince($previous)

Here, $previous is another WWW::SFDC::Metadata::DeployResult. This attribute
holds all failures that are new in this result compared to the previous one.
This is useful for providing a running commentary on what's failed so far.

=cut

sub componentFailuresSince {
  my ($self, $previous) = @_;
  return ()
    if $self->result->{numberComponentErrors} == 0
    or (
      $previous
      and $previous->result->{numberComponentErrors} == $self->result->{numberComponentErrors}
    );

  my @oldResults = $previous ? @{$previous->componentFailures} : ();
  my @newResults;
  my $i = 0;
  for my $failure (@{$self->componentFailures}) {
    if (
      scalar @oldResults > $i
      and $failure->{fileName}.$failure->{fullName} cmp $oldResults[$i]->{fileName}.$oldResults[$i]->{fullName}
    ) {
      $i++;
    } else {
      push @newResults, $failure;
    }
  }

  return @newResults
}

1;

__END__

=head1 DESCRIPTION

L<WWW::SFDC::Metadata>->Deploy returns a DeployResult in order to provide rich
ability for handling different categories of errors, including categorised test
results and component failures.

It is overloaded such that when stringified it returns the deployment ID,
because that's the most important element, and it enables chaining with
DeployRecentValidation.

You probably will only consume this, rather than explicitly creating it.

=head1 BUGS

Please report any bugs or feature requests at L<https://github.com/sophos/WWW-SFDC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::SFDC::Metadata::DeployResult

You can also look for information at L<https://github.com/sophos/WWW-SFDC>
