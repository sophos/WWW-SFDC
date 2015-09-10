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

=attr TYPES

A hashref containing the result of the metadataObjects member of a
describeMetadata result. If this is populated, Constants will not send any API
calls, so setting this in the constructor with a cached version provides
offline functionality. If you specify a session, this attribute is optional.

=cut

has 'TYPES',
  is => 'ro',
  lazy => 1,
  default => sub {
    my $self = shift;
    +{
      map {
        $_->{directoryName} => $_;
      } @{$self->session->Metadata->describeMetadata->{metadataObjects}}
    }
  };

has '_subcomponents',
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

  
my %_SUBCOMPONENTS = (
  actionOverrides => 'ActionOverride',
  alerts => 'WorkflowAlert',
  businessProcesses => 'BusinessProcess',
  fieldSets => 'FieldSet',
  fieldUpdates => 'WorkflowFieldUpdate',
  fields => 'CustomField',
  flowActions => 'WorkflowFlowAction',
  labels => 'CustomLabel',
  listViews => 'ListView',
  outboundMessages => 'WorkflowOutboundMessage',
  recordTypes => 'RecordType',
  rules => 'WorkflowRule',
  tasks => 'WorkflowTask',
  validationRules => 'ValidationRule',
  webLinks => 'WebLink'
);
    
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

When provided with the disk (folder) name for a component type or the node name of a subcomponent,
provides the Metadata API name for that type.

=cut

sub getName {
  my ($self, $type) = @_;
  return $_SUBCOMPONENTS{$type} if grep {/$type/} keys %_SUBCOMPONENTS;
  LOGDIE "$type is not a recognised type" unless $self->TYPES->{$type};
  return $self->TYPES->{$type}->{xmlName};
}

=method getSubcomponents

Returns a list of API names of subcomponents

=cut

sub getSubcomponents {
  my $self = shift;
  return @{$self->_subcomponents};
}

=method getXMLSubcomponents

Returns a list of XML node names for subcomponents.

=cut

sub getXMLSubcomponents {
  return keys %_SUBCOMPONENTS;
}

1;

__END__

=head1 SYNOPSIS

Provides the methods required for translating on-disk file names and component
names to forms that the metadata API recognises, and vice-versa.

  WWW::SFDC::Constants->new(
    session => $session
  );

OR

  WWW::SFDC::Constants->new(
    TYPES => $types
  );
