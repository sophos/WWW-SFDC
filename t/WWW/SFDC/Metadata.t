use 5.12.0;
use strict;
use warnings;
use Test::More;
use Test::Exception;
use Config::Properties;

use_ok "WWW::SFDC::Metadata";


SKIP: { #only execute if creds provided

  my $options = Config::Properties
    ->new(file => "t/test.config")
    ->splitToTree() if -e "t/test.config";

  skip "No test credentials found in t/test.config", 2
    unless $options->{username}
    and $options->{password}
    and $options->{url};

  ok my $client = WWW::SFDC::Metadata->instance(creds => {
    username => $options->{username},
    password => $options->{password},
    url => $options->{url},
   }), "can create an sfdc client";

 SKIP: {

    ok my $manifest = $client->listMetadata(
      {type => "CustomObject"},
      {type => "ApexClass"},
      {type => "Profile"},
      {type => "CustomObject"},
      {type => "Report", folder => "FooReports"}
     ), "List Metadata"
       or skip "Can't retrieve or deploy because list failed", 2;

    ok my $base64ZipString = $client->retrieveMetadata($manifest),
      "Retrieve Metadata" or skip "Can't deploy because retrieve failed", 1;

    lives_ok {$client->deployMetadata($base64ZipString)}
      "Retrieve Metadata";
  }


 TODO: {
    local $TODO = "test retrieve, deploy and list failures";

    ok 0;
  }
}

done_testing();
