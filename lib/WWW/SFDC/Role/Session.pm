package WWW::SFDC::Role::Session;
# ABSTRACT: Provides a transparent interface to WWW::SFDC::SessionManager

use 5.12.0;
use strict;
use warnings;

use Moo::Role;
use Module::Loaded;

use WWW::SFDC::SessionManager;

=head1 SYNOPSIS

    package Example;
    use Moo;
    with "WWW::SFDC::Role::Session";

    sub _extractURL {
      # this is a required method. $_[0] is self, as normal.
      # $_[1] is the loginResult hash, which has a serverUrl as
      # well as a metadataServerUrl defined.
      return $_[1]->{serverUrl};
    }

    # uri is a required property, containing the default namespace
    # for the SOAP request.
    has 'uri', is => 'ro', default => 'urn:partner.soap.salesforce.com';

    sub doSomething {
      my $self = shift;
      # this uses the above-defined uri and url, and generates
      # a new sessionId upon an INVALID_SESSION_ID error:
      return $self->_call('method', @_);
    }

    1;

=cut

requires qw'_extractURL';

has 'creds',
  is => 'ro',
  trigger => sub {WWW::SFDC::SessionManager->instance(shift->creds())};

has 'url',
  is => 'ro',
  lazy => 1,
  builder => '_buildURL';

has 'pollInterval',
  is => 'rw',
  default => 15;

sub _buildURL {
  my $self = shift;
  return $self->_extractURL(WWW::SFDC::SessionManager->instance()->loginResult());
}

sub _call {
  my $self = shift;
  my $req = WWW::SFDC::SessionManager->instance()->call($self->url(), $self->uri(), @_);

  return $req->result(),
    (defined $req->paramsout() ? $req->paramsout() : ()),
    (defined $req->headers() ? $req->headers() : ());
}

sub _sleep {
  my $self = shift;
  sleep $self->pollInterval;
}

1;

__END__

=head1 BUGS

Please report any bugs or feature requests at L<https://github.com/alexander-brett/WWW-SFDC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::SFDC::Role::Session

You can also look for information at L<https://github.com/alexander-brett/WWW-SFDC>
