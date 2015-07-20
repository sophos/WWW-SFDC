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

has '_result',
    is => 'ro',
    required => 1;

has '_headers',
    is => 'ro';

=attr success

Whether or not the apex code executed successfully

=cut

has 'success',
    is => 'ro',
    lazy => 1,
    builder => sub {
        my $self = shift;
        return $self->_result->{success} eq 'true';
    };

=attr failureMessage

If the code failed to compile, the compilation error; if the code failed to
execute, the exception message. This will be undefined if the code succeeded.

=cut

has 'failureMessage',
    is => 'ro',
    lazy => 1,
    builder => sub {
        my $self = shift;
        return $self->_result->{compiled} eq 'true'
            ? $self->_result->{exceptionMessage}
            : $self->_result->{compileProblem};
    };

=attr log

The debug log for the code. This will be undefined if the code failed to
compile, and an empty string if no logs were requested.

=cut

has 'log',
    is => 'ro',
    lazy => 1,
    builder => sub {
        my $self = shift;
        return $self->_headers ? $self->_headers->{debugLog} : "";
    };

sub BUILD {
    my $self = shift;
    FATAL $self->failureMessage unless $self->success;
}

1;

__END__

=head1 DESCRIPTION

This module acts as a container for the result of an executeAnonymous request.
It's overloaded so that used as a boolean, it acts as the success value of the
call.
