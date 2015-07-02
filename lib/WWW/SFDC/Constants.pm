package WWW::SFDC::Constants;
# ABSTRACT: Data about SFDC Metadata Components.

use 5.12.0;
use strict;
use warnings;

use List::Util 'first';
use Log::Log4perl ':easy';

use Moo;
with "WWW::SFDC::Role::SessionConsumer";

=head1 Metadata Types

=head2 ending

Stores the file ending for the metadata type, if there is one.

NB that two of these values are UNKNOWN because I don't know what the value is.

=head2 name

Stores the metadata API name corresponding to the folder name on disk. For instance, the
metadata name corresponding to the applications/ folder is CustomApplication, but the name
corresponding to flows/ is Flow.

=head2 meta

Set if the component has associated -meta.xml files (nb not counting folder xml files).

=head2 folders

Set if the type occurs within folders.

=cut

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
    use Data::Dumper;
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
