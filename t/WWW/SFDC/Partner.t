use 5.12.0;
use strict;
use warnings;
use Test::More;
use Config::Properties;
use Data::Dumper;

use_ok 'WWW::SFDC::Partner';

my $options = Config::Properties
  ->new(file => "t/test.config")
  ->splitToTree() if -e "t/test.config";

ok my $client = WWW::SFDC::Partner->instance(creds => {
  username => $options->{username},
  password => $options->{password},
  url => $options->{url},
 }), "can create an sfdc client";

SKIP: {

  skip "There aren't any login details", 1 unless -e "t/test.config";

  ok my @results = $client->query("SELECT Id,Name FROM User WHERE Profile.Name = 'System Administrator'");

  diag Dumper @results;

}

done_testing;
