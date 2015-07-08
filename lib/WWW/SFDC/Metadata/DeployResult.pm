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

has 'id',
  is => 'ro',
  lazy => 1,
  builder => sub {return $_[0]->result->{id}};

has 'success',
  is => 'ro',
  lazy => 1,
  builder => sub {return $_[0]->result->{status} eq 'Succeeded'};

has 'complete',
  is => 'ro',
  lazy => 1,
  builder => sub {return $_[0]->result->{status} !~ /Queued|Pending|InProgress/;};

has 'result',
  is => 'ro',
  required => 1;

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
