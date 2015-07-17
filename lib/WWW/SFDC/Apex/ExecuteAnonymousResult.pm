package WWW::SFDC::Apex::ExecuteAnonymousResult;
# ABSTRACT: Container for the result of an executeAnonymous call

use strict;
use warnings;

# VERSION

use overload
  bool => sub {
    return $_[0]->success;
  };

use Log::Log4perl ':easy';
use Moo;

has 'result',
    is => 'ro',
    required => 1;

has 'headers',
    is => 'ro';

has 'success',
    is => 'ro',
    lazy => 1,
    builder => sub {
        my $self = shift;
        return $self->result->{success} eq 'true';
    };

has 'failureMessage',
    is => 'ro',
    lazy => 1,
    builder => sub {
        my $self = shift;
        return $self->result->{compiled} eq 'true'
            ? $self->result->{exceptionMessage}
            : $self->result->{compileProblem};
    };

has 'log',
    is => 'ro',
    lazy => 1,
    builder => sub {
        my $self = shift;
        return $self->headers ? $self->headers->{debugLog} : "";
    };

1;

