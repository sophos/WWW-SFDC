package WWW::SFDC::Constants;
# ABSTRACT: Data about SFDC Metadata Components.

use 5.12.0;
use strict;
use warnings;

# VERSION

use List::Util 'first';
use Log::Log4perl ':easy';

use Moo;
with "WWW::SFDC::Role::SessionConsumer";

has '+session',
  is => 'ro',
  required => 0;

has 'uri',
  is => 'ro',
  default => "urn:partner.soap.sforce.com";

sub _extractURL { return $_[1]->{serverUrl} }

has 'TYPES',
  is => 'ro',
  lazy => 1,
  default => sub {
    my $self = shift;
    my ($describe) = $self->session->Metadata->describeMetadata(
          $self->session->apiVersion
    );
    +{
      map {
        $_->{directoryName} => $_;
      } @{$describe->{metadataObjects}}
    }
  };

has 'subcomponents',
  is => 'ro',
  lazy => 1,
  default => sub {
    my $self = shift;
    [map {
      exists $_->{childXmlNames}
        ? ref $_->{childXmlNames} eq 'ARRAY'
          ?  @{$_->{childXmlNames}}
          : $_->{childXmlNames}
        : ()
    } values $self->TYPES];
  };

=method needsMetaFile

=cut

sub needsMetaFile {
  my ($self, $type) = @_;
  return $self->TYPES->{$type} && exists $self->TYPES->{$type}->{metaFile}
    ? $self->TYPES->{$type}->{metaFile} eq 'true'
    : LOGDIE "$type is not a recognised type";
}

=method hasFolders

=cut

sub hasFolders {
  my ($self, $type) = @_;
  return $self->TYPES->{$type} && exists $self->TYPES->{$type}->{inFolder}
    ? $self->TYPES->{$type}->{inFolder} eq 'true'
    : LOGDIE "$type is not a recognised type";
}

=method getEnding

=cut

sub getEnding {
  my ($self, $type) = @_;
  LOGDIE "$type is not a recognised type" unless $self->TYPES->{$type};
  return $self->TYPES->{$type}->{suffix}
    ? ".".$self->TYPES->{$type}->{suffix}
    : undef;
}

=method getDiskName

=cut

sub getDiskName {
  my ($self, $query) = @_;
  return first {$self->TYPES->{$_}->{xmlName} eq $query} keys %{$self->TYPES};
}

=method getName

=cut

sub getName {
  my ($self, $type) = @_;
  return $type if grep {/$type/} @{$self->subcomponents};
  LOGDIE "$type is not a recognised type" unless $self->TYPES->{$type};
  return $self->TYPES->{$type}->{xmlName};
}

=method getSubcomponents

=cut

sub getSubcomponents {
  my $self = shift;
  return @{$self->subcomponents};
}

1;
