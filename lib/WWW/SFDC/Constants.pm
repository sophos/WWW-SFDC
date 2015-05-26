package WWW::SFDC::Constants;
# ABSTRACT: Data about SFDC Metadata Components.

use 5.12.0;
use strict;
use warnings;

use List::Util 'first';
use Log::Log4perl ':easy';

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

my %TYPES = (
  applications       => {
    name => "CustomApplication",
    ending => ".app",
  },
  approvalProcesses  => {
    name => "ApprovalProcess",
    ending => ".approvalProcess"
  },
  classes            => {
    name => "ApexClass",
    ending => ".cls",
    meta => 1,
  },
  components         => {
    name => "ApexComponent",
    ending => ".component",
    meta => 1,
  },
  datacategorygroups => {
    name => "DataCategoryGroup",
    ending => "UNKNOWN"
  },
  documents          => {
    name => "Document",
    ending => undef,
    meta => 1,
    folders => 1,
  },
  email              => {
    name => "EmailTemplate",
    ending => ".email",
    meta => 1,
    folders => 1,
  },
  flows              => {
    name => "Flow",
    ending => "UNKNOWN"
  },
  groups             => {
    name => "Group",
    ending => ".group"
  },
  homePageComponents => {
    name => "HomePageComponent",
    ending => ".homePageComponent"
  },
  homePageLayouts    => {
    name => "HomePageLayout",
    ending => ".homePageLayout"
  },
  labels             => {
    name => "CustomLabels",
    ending => ".labels"
  },
  layouts            => {
    name => "Layout",
    ending => ".layout"
  },
  objects            => {
    name => "CustomObject",
    ending => ".object"
  },
  pages              => {
    name => "ApexPage",
    ending => ".page",
    meta => 1,
  },
  permissionsets     => {
    name => "PermissionSet",
    ending => ".permissionset"
  },
  portals            => {
    name => "Portal",
    ending => ".portal"
  },
  profiles           => {
    name => "Profile",
    ending => ".profile"
  },
  queues             => {
    name => "Queue",
    ending => ".queue"
  },
  quickActions       => {
    name => "QuickAction",
    ending => ".quickAction"
  },
  remoteSiteSettings => {
    name => "RemoteSiteSetting",
    ending => ".remoteSite"
  },
  reportTypes        => {
    name => "ReportType",
    ending => ".reportType"
  },
  reports            => {
    name => "Report",
    ending => ".report",
    folders => 1,
  },
  roles              => {
    name => "Role",
    ending => "role"
  },
  sites              => {
    name => "CustomSite",
    ending => ".site"
  },
  settings           => {
    name => "Settings",
    ending => ".settings",
  },
  sharingRules       => {
    name => "SharingRules",
    ending => ".sharingRules"
  },
  staticresources    => {
    name => "StaticResource",
    ending => ".resource",
    meta => 1,
  },
  tabs               => {
    name => "CustomTab",
    ending => ".tab"
  },
  translations       => {
    name => "Translations",
    ending => ".translation",
  },
  triggers           => {
    name => "ApexTrigger",
    ending => ".trigger",
    meta => 1,
  },
  weblinks           => {
    name => "CustomPageWebLink",
    ending => ".weblink"
  },
  workflows          => {
    name => "Workflow",
    ending => ".workflow"
  },
  #subcomponents
  actionOverrides    => {
    name => "ActionOverride",
    subcomponent => 1
  },
  alerts             => {
    name => "WorkflowAlert",
    subcomponent => 1
  },
  businessProcesses  => {
    name => "BusinessProcess",
    subcomponent => 1
  },
  fieldSets          => {
    name => "FieldSet",
    subcomponent => 1
  },
  fieldUpdates       => {
    name => "WorkflowFieldUpdate",
    subcomponent => 1
  },
  fields             => {
    name => "CustomField",
    subcomponent => 1
  },
  listViews          => {
    name => "ListView",
    subcomponent => 1
  },
  outboundMessages   => {
    name => "WorkflowOutboundMessage",
    subcomponent => 1
  },
  recordTypes        => {
    name => "RecordType",
    subcomponent => 1
  },
  rules              => {
    name => "WorkflowRule",
    subcomponent => 1
  },
  tasks              => {
    name => "WorkflowTask",
    subcomponent => 1
  },
  validationRules    => {
    name => "ValidationRule",
    subcomponent => 1
  },
  webLinks           => {
    name => "WebLink",
    subcomponent => 1
  },
);

=method needsMetaFile

=cut

sub needsMetaFile {
  return $TYPES{+shift}->{meta};
}

=method hasFolders

=cut

sub hasFolders {
  return $TYPES{+shift}->{folders};
}

=method getEnding

=cut

sub getEnding {
  return $TYPES{+shift}->{ending};
}

=method getDiskName

=cut

sub getDiskName {
  my $query = shift;
  return first {$TYPES{$_}->{name} eq $query} keys %TYPES;
}

=method getName

=cut

sub getName {
  my $type = shift;
  return $TYPES{$type}->{name} or LOGDIE "Type $type doesn't have a name!";
}

=method getSubcomponents

=cut

sub getSubcomponents {
  return grep {$TYPES{$_}->{subcomponent}} keys %TYPES;
}
