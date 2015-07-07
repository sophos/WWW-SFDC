package WWW::SFDC::Role::Exception;
# ABSTRACT: Exception role for WWW::SFDC libraries

use 5.12.0;
use strict;
use warnings;

# VERSION

use Log::Log4perl ':easy';
use Scalar::Util 'blessed';

use Moo::Role;
use overload '""' => \&_stringify;

has 'message',
    is => 'ro',
    default => 'There was an error in WWW::SFDC';

sub _stringify {
    my ($self) = shift;
    return $self->message;
}

sub throw {
    my $self = shift;
    my $e = blessed $self ? $self : $self->new(@_);

    FATAL $e;
    die $e;
}

1;
