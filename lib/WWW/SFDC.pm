package WWW::SFDC;
# ABSTRACT: Wrappers around the Salesforce.com APIs.

use strict;
use warnings;
use 5.12.0;

use Data::Dumper;
use Log::Log4perl ':easy';

use Moo;

has 'username',
  is => 'ro',
  required => 1;

has 'password',
  is => 'ro',
  required => 1;

has 'url',
  is => 'ro',
  default => "https://test.salesforce.com",
  isa => sub { $_[0] and $_[0] =~ s/\/$// or 1; }; #remove trailing slash

has 'apiVersion',
  is => 'ro',
  isa => sub { LOGDIE "The API version ($_[0]) must be >= 31." unless $_[0] and $_[0] >= 31},
  default => '33.0';

has 'pollInterval',
  is => 'rw',
  default => 15;

has 'loginResult',
  is => 'rw',
  lazy => 1,
  builder => '_login';

for my $module (qw'
  Apex Constants Metadata Partner Tooling
'){
  has $module,
    is => 'ro',
    lazy => 1,
    default => sub {
      my $self = shift;
      require "WWW/SFDC/$module.pm";
      "WWW::SFDC::$module"->new(session => $self);
    };
}

sub _login {
  my $self = shift;

  INFO "Logging in...\t";

  my $request = SOAP::Lite
    ->proxy(
      $self->url()."/services/Soap/u/".$self->apiVersion()
    )
    ->readable(1)
    ->ns("urn:partner.soap.sforce.com","urn")
    ->call(
      'login',
      SOAP::Data->name("username")->value($self->username),
      SOAP::Data->name("password")->value($self->password)
     );

  TRACE "Request: " . Dumper $request;
  LOGDIE "Login Failed: ".$request->faultstring if $request->fault;
  return $request->result();
}

=method call

=cut

sub _doCall {
  my $self = shift;
  my ($URL, $NS, @stuff) = @_;

  INFO "Starting $stuff[0] request";

  return SOAP::Lite
    ->proxy($URL)
    ->readable(1)
    ->default_ns($NS)
    ->call(
      @stuff,
      SOAP::Header->name("SessionHeader" => {
        "sessionId" => $self->loginResult()->{"sessionId"}
      })->uri($NS)
     );
}

sub call {
  my $self = shift;
  my $req = $self->_doCall(@_);

  if ($req->fault && $req->faultstring =~ /INVALID_SESSION_ID/) {
    $self->loginResult($self->_login());
    $req = $self->_doCall(@_);
  }

  TRACE "Operation request " => Dumper $req;
  LOGDIE "$_[0] Failed: " . $req->faultstring if $req->fault;

  return $req;
};

=method isSandbox

Returns 1 if the org associated with the given credentials are a sandbox. Use to
decide whether to sanitise metadata or similar.

=cut

sub isSandbox {
  my $self = shift;
  return $self->loginResult->{sandbox} eq  "true";
}

1;

__END__

=head1 SYNOPSIS

WWW::SFDC provides a set of packages which you can use to build useful
interactions with Salesforce.com's many APIs. Initially it was intended
for the construction of powerful and flexible deployment tools.

    use WWW::SFDC; # Import everything

    use WWW::SFDC::Tooling; # Just the tooling API interface

    use WWW::SFDC qw'Metadata Manifest';
        # Equivalent to importing WWW::SFDC::Metadata and WWW::SFDC::Manifest

=head1 CONTENTS

=over 4

=item WWW::SFDC::SessionManager

Provides the lowest-level interaction with SOAP::Lite. Handles the
SessionID and renews it when necessary.

=item WWW::SFDC::Manifest

Stores and manipulates lists of metadata for retrieving and deploying
to and from Salesforce.com.

=item WWW::SFDC::Metadata

Wraps the Metadata API.

=item WWW::SFDC::Partner

Wraps the Partner API.

=item WWW::SFDC::Tooling

Wraps the Tooling API.

=item WWW::SFDC::Zip

Provides utilities for creating and extracting base-64 encoded zip
files for Salesforce.com retrievals and deployments.

=back

=head1 METADATA API EXAMPLES

The following provides a starting point for a simple retrieval tool.
Notice that after the initial setup of WWW::SFDC::Metadata the login
credentials are cached. In this example, you'd use
_retrieveTimeMetadataChanges to remove files you didn't want to track,
change sandbox outbound message endpoints to production, or similar.

Notice that I've tried to keep the interface as fluent as possible in
all of these modules - every method which doesn't have an obvious
return value returns $self.

    package ExampleRetrieval;

    use WWW::SFDC::Metadata;
    use WWW::SFDC::Manifest;
    use WWW::SFDC::Zip qw'unzip';

    WWW::SFDC::Metadata->instance(creds => {
      password  => $password,
      username  => $username,
      url       => $url
    });

    my $manifest = WWW::SFDC::Manifest
      ->readFromFile($manifestFile)
      ->add(
        WWW::SFDC::Metadata
          ->instance()
          ->listMetadata(
            {type => 'Document', folder => 'Apps'},
            {type => 'Document', folder => 'Developer_Documents'},
            {type => 'EmailTemplate', folder => 'Asset'},
            {type => 'ApexClass'}
          )
      );

    unzip
      $destDir,
      WWW::SFDC::Metadata->instance()->retrieveMetadata($manifest->manifest()),
      \&_retrieveTimeMetadataChanges;

Here's a similar example for deployments. You'll want to construct
@filesToDeploy and $deployOptions context-sensitively!

     package ExampleDeployment;

     use WWW::SFDC::Metadata;
     use WWW::SFDC::Manifest;
     use WWW::SFDC::Zip qw'makezip';

     my $manifest = WWW::SFDC::Manifest
       ->new()
       ->addList(@filesToDeploy)
       ->writeToFile($srcDir.'package.xml');

     my $zip = makezip
       $srcDir,
       $manifest->getFileList(),
       'package.xml';

    my $deployOptions = {
       singlePackage => 'true',
       rollbackOnError => 'true',
       checkOnly => 'true'
    };

    WWW::SFDC::Metadata->instance(creds => {
     username=>$username,
     password=>$password,
     url=>$url
   })->deployMetadata $zip, $deployOptions;

=head1 PARTNER API EXAMPLE

To unsanitise some users' email address and change their profiles
on a new sandbox, you might do something like this:

    package ExampleUserSanitisation;

    use WWW::SFDC::Partner;
    use List::Util qw'first';

    WWW::SFDC::Partner->instance(creds => {
      username => $username,
      password => $password,
      url => $url
    });

    my @users = (
      {User => alexander.brett, Email => alex@example.com, Profile => $profileId},
      {User => another.user, Email => a.n.other@example.com, Profile => $profileId},
    );

    WWW::SFDC::Partner->instance()->update(
      map {
        my $row = $_;
        my $original = first {$row->{Username} =~ /$$_{User}/} @users;
        +{
           Id => $row->{Id},
           ProfileId => $original->{Profile},
           Email => $original->{Email},
        }
      } WWW::SFDC::Partner->instance()->query(
          "SELECT Id, Username FROM User WHERE "
          . (join " OR ", map {"Username LIKE '%$_%'"} map {$_->{User}} @inputUsers)
        )
    );

=head1 BUGS

Please report any bugs or feature requests at L<https://github.com/alexander-brett/WWW-SFDC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::SFDC
    perldoc WWW::SFDC::Metadata
    ...

You can also look for information at L<https://github.com/alexander-brett/WWW-SFDC>

