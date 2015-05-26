use 5.12.0;
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Config::Properties;

use_ok "WWW::SFDC::SessionManager";

throws_ok
  { WWW::SFDC::SessionManager->instance() }
  qr/Missing required arguments:/,
  "Constructor requires options";

throws_ok
  { WWW::SFDC::SessionManager->instance(
    username => 'foo',
    password => 'baz',
    url => 'https://test.salesforce.com',
    apiVersion => 30
   ) }
  qr/The API version must be >= 31/,
  "The API version must be >= 31";

new_ok 'WWW::SFDC::SessionManager', [
  username => 'foo',
  password => 'baz',
  url => 'https://test.salesforce.com',
  apiVersion => 31
 ];

is WWW::SFDC::SessionManager->instance(
  username => 'foo',
  password => 'baz',
  url => 'https://test.salesforce.com/'
 )->url(),
  'https://test.salesforce.com', "url trailing slash removal";

done_testing;
