package WWW::SFDC::Partner;
# ABSTRACT: Interface to the Salesforce.com Partner API

use 5.12.0;
use strict;
use warnings;

# VERSION

use Data::Dumper;
use Log::Log4perl ':easy';
use Scalar::Util 'blessed';
use SOAP::Lite;

use Moo;
with "WWW::SFDC::Role::SessionConsumer", "WWW::SFDC::Role::CRUD";

=head1 SYNOPSIS

    my @objects = WWW::SFDC::Partner->instance(creds => {
        username => "foo",
        password => "bar",
        url      => "url",
    })->query("SELECT field, ID FROM Object__c WHERE conditions");

    WWW::SFDC::Partner->instance()->update(
        map { $_->{field} =~ s/baz/bat/ } @objects
    );

=cut

has 'uri',
  is => 'ro',
  default => "urn:partner.soap.sforce.com";

sub _extractURL { return $_[1]->{serverUrl} }

sub _prepareSObjects {
  my $self = shift;
  # prepares an array of objects for an update or insert call by converting
  # it to an array of SOAP::Data

  TRACE "objects for operation", Dumper \@_;

  return map {
      my $obj = $_;
      my @type;
      if ($obj->{type}) {
        @type = SOAP::Data->name('type' => $obj->{type});
        delete $obj->{type};
      }

      SOAP::Data->name(sObjects => \SOAP::Data->value(
        @type,
        map {
          (blessed ($obj->{$_}) and blessed ($obj->{$_}) eq 'SOAP::Data')
            ? $obj->{$_}
            : SOAP::Data->name($_ => $obj->{$_})
        } keys %$obj
      ))
    } @_;
}

=method setPassword

    WWW::SFDC::Partner->instance()->setPassword(Id=>$ID, Password=$newPassword);

=cut

sub setPassword {
  my ($self, %params) = @_;
  LOGDIE "You must provide an Id and Password" unless $params{Id} and $params{Password};
  INFO "Setting password for user $params{Id}";
  return $self->_call(
    'setPassword',
    SOAP::Data->name(userID => $params{Id}),
    SOAP::Data->name(password => $params{Password}),
   );
}

1;

__END__

=head1 BUGS

Please report any bugs or feature requests at L<https://github.com/alexander-brett/WWW-SFDC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::SFDC::Partner

You can also look for information at L<https://github.com/alexander-brett/WWW-SFDC>
