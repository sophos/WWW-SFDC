package WWW::SFDC::Metadata;
# ABSTRACT: Interface to the Salesforce.com Metadata API

use 5.12.0;
use strict;
use warnings;

use Data::Dumper;
use Log::Log4perl ':easy';
use SOAP::Lite;

use Moo;
with "WWW::SFDC::Role::SessionConsumer";

=head1 SYNOPSIS

 my $client = WWW::SFDC->new(
   username => 'foo',
   password => 'bar',
   url => 'https://login.salesforce.com'
 )->Metadata;

 my $manifest = $client->listMetadata(
   {type => "CustomObject"},
   {type => "Report", folder => "FooReports"}
 );

 my $base64zipstring = $client->retrieveMetadata(
   $manifest
 );

 $client->deployMetadata(
   $base64zipstring,
   {checkOnly => 'true'}
 );

For more in-depth examples, see t/WWW/SFDC/Metadata.t

=cut

has 'uri',
  is => 'ro',
  default => "http://soap.sforce.com/2006/04/metadata";

sub _extractURL {
  return $_[1]->{metadataServerUrl};
}

=method listMetadata @queries

Accepts a list of types and folders, such as

   {type => "CustomObject"},
   {type => "Report", folder => "FooReports"}

and generates a list of file names suitable for turning into a WWW::SFDC::Manifest.

=cut

sub listMetadata {

  my $self = shift; #remaining elements of @_ are queries;

  INFO "Listing Metadata...\t";

  my @result;
  my @queryData = map {SOAP::Data->new(name => "queries", value => $_)} @_;

  # listMetadata can only handle 3 requests at a time, so we chunk them.
  while (my @items = splice @queryData, 0, 3) {
    push @result, $$_{fileName} for $self->_call('listMetadata', @items);
  }

  return @result;
}

=method retrieveMetadata $manifest

Sets up a retrieval from then checks it until done. Returns the
same data as checkRetrieval. Requires a manifest of the form:

 my $manifest = {
   "ApexClass" => ["MyApexClass"],
   "CustomObject" => ["*", "Account", "User", 'Opportunity"],
   "Profile" => ["*"]
  };

=cut

# Sets up an asynchronous metadata retrieval request and
# returns just the id, for checking later. Accepts a manifest.

sub _startRetrieval {
  INFO "Starting retrieval";

  my ($self, $manifest) = @_;

  # These maps basically preserve the structure passed in,
  # translating it to salesforce's special package.xml structure.
  my @queryData = map {
    SOAP::Data->name (
      types => \SOAP::Data->value(
      	map {SOAP::Data->name(members => $_) } @{ $$manifest{$_} },
      	SOAP::Data->name(name => $_ )
       )
     )
    } keys %$manifest;


  return ($self->_call(
    'retrieve',
    SOAP::Data->name(
      retrieveRequest => {
      	# a lower value than 31 means no status is retrieved, causing an error.
      	apiVersion => $self->session->apiVersion(),
      	unpackaged => \SOAP::Data->value(@queryData)
      })
   ) )[0]->{id};

}

# Uses the id to request a status update from SFDC, and returns
# undef unless there's something to give back, in which case it
# returns the base64 encoded zip file from the response.

sub _checkRetrieval {
  my ($self, $id) = @_;
  LOGDIE "No ID was passed in!" unless $id;

  my ($result) = $self->_call(
    'checkRetrieveStatus',
    SOAP::Data->name("asyncProcessId" => $id)
   );

  INFO "Status:" . $$result{status};

  return $result->{zipFile} if $$result{status} eq "Succeeded";
  return if $$result{status} =~ /Pending|InProgress/;
  LOGDIE "Check Retrieve had an unexpected result: ".$$result{message};
}


sub retrieveMetadata {

  my ($self, $manifest) = @_;
  LOGDIE "This method must be called with a manifest" unless $manifest;

  my $requestId = $self->_startRetrieval($manifest);

  my $result;

  do { $self->_sleep() } until $result = $self->_checkRetrieval($requestId);

  return $result;
}

=method deployMetadata $zipString, \%deployOptions

Takes a base64 zip file and deploys it. Deploy options will be
passed verbatim into the request; see the metadata developer
guide for a description.

=cut

#Check up on an async deployment request. Returns 1 when complete.
sub _checkDeployment {
  my ($self, $id) = @_;
  LOGDIE "No ID was passed in" unless $id;

  my ($result) = $self->_call(
    'checkDeployStatus',
    SOAP::Data->name("id" => $id),
    SOAP::Data->name("includeDetails" => "true")
   );

  INFO "Deployment status:\t".$$result{status};
  return 1 if $$result{status} eq "Succeeded";
  return if $$result{status} =~ /Queued|Pending|InProgress/;
  # useful deployment error here please
  LOGDIE "DEPLOYMENT FAILED: ".Dumper $result->{details}->{componentFailures}
    if $result->{status} eq "Failed";
  LOGDIE "Check Deploy had an unexpected result: ".Dumper $result;
}

sub deployMetadata {
  my ($self, $zip, $deployOptions) = @_;

  my ($result) = $self->_call(
    'deploy',
    SOAP::Data->name( zipfile => $zip),
    (
      $deployOptions
        ? SOAP::Data->name(DeployOptions=>$deployOptions)
        : ()
    )
   );

  INFO "Deployment status:\t".$$result{state};

  #do..until guarantees that sleep() executes at least once.
  do {$self->_sleep()} until $self->_checkDeployment($$result{id});

  return $$result{id};

}

=method deployRecentValidation $id

Calls deployRecentValidation with your successfully-validated deployment.

=cut

sub deployRecentValidation {
  my ($self, $id) = @_;

  chomp $id;

  return $self->_call(
    'deployRecentValidation',
    SOAP::Data->name(validationID => $id)
   );
}

sub describeMetadata {
  my ($self) = @_;

  return $self->_call(
    'describeMetadata',
    SOAP::Data->name(apiVersion => $self->session->apiVersion)
   );
}

1;

__END__

=head1 BUGS

Please report any bugs or feature requests at L<https://github.com/alexander-brett/WWW-SFDC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::SFDC::Metadata

You can also look for information at L<https://github.com/alexander-brett/WWW-SFDC>

