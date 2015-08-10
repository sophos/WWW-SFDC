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

=attr message

The exception message. When this object is stringified, this will be the value
returned.

=cut

has 'message',
    is => 'ro',
    default => 'There was an error in WWW::SFDC';

sub _stringify {
    my ($self) = shift;
    return $self->message;
}

=method throw

This will log the message using Log4perl then die with itself as the error
value. This enables catching the error and determining whether it's
recoverable, or whether the values need using. This is intended for doing
things like getting the debug log from a failed ExecuteAnonymous, or unit
test results from a failed deployment.

=cut

sub throw {
    my $self = shift;
    my $e = blessed $self ? $self : $self->new(@_);

    FATAL $e;
    die $e;
}

1;

__END__

=head1 SYNOPSIS

    package MyException;
    use Moo;
    with 'WWW::SFDC::Role::Exception';

    has 'something', is => 'ro', default => 'value';

    package MAIN;
    # Simple:
    MyException->throw(message => 'Something bad happened!');


    # More complex:
    my $e = MyException->new(message => 'Something bad happened!');
    print $e; # Something bad happened! (not HASH(...))
    eval {
        $e->throw();
    }
    print $@->something; # value


=head1 BUGS

Please report any bugs or feature requests at L<https://github.com/sophos/WWW-SFDC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::SFDC::Role::Exception

You can also look for information at L<https://github.com/sophos/WWW-SFDC>
