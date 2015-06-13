package WWW::SFDC::Constants;
# ABSTRACT: Data about SFDC Metadata Components.

use 5.12.0;
use strict;
use warnings;

use List::Util 'first';
use Log::Log4perl ':easy';
use WWW::SFDC::Metadata;

BEGIN {
  use Exporter;
  our @ISA = qw(Exporter);
  our @EXPORT_OK = qw(needsMetaFile hasFolders getEnding getDiskName getName getSubcomponents);
}

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

my @subcomponents;

my %TYPES = map {
  @subcomponents += @{$_->{childXmlNames}} if exists $_->{childXmlNames};
  $_->{directoryName} => $_;
} WWW::SFDC::Metadata->instance->describeMetadata(
  WWW::SFDC::SessionManager->instance->apiVersion
)

=method needsMetaFile

=cut

sub needsMetaFile {
  return $TYPES{$_[0]} && exists $TYPES{$_[0]}->{metaFile}
    ? $TYPES{$_[0]}->{metaFile} eq 'true'
    : LOGDIE "$_[0] is not a recognised type";
}

=method hasFolders

=cut

sub hasFolders {
  return $TYPES{$_[0]} && exists $TYPES{$_[0]}->{inFolder}
    ? $TYPES{$_[0]}->{inFolder} eq 'true'
    : LOGDIE "$_[0] is not a recognised type";
}

=method getEnding

=cut

sub getEnding {
  LOGDIE "$_[0] is not a recognised type" unless $TYPES{$_[0]};
  return $TYPES{$_[0]}->{suffix}
    ? ".".$TYPES{$_[0]}->{suffix}
    : undef;
}

=method getDiskName

=cut

sub getDiskName {
  my $query = shift;
  return first {$TYPES{$_}->{xmlName} eq $query} keys %TYPES;
}

=method getName

=cut

sub getName {
  my $type = shift;
  return $_[0] if grep {/$_[0]/} @subcomponents;
  LOGDIE "$_[0] is not a recognised type" unless $TYPES{$_[0]};
  return $TYPES{$_[0]}->{xmlName};
}

=method getSubcomponents

=cut

sub getSubcomponents {
  return @subcomponents;
}
