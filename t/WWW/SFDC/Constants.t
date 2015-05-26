use 5.12.0;
use strict;
use warnings;

use Test::More;

use_ok('WWW::SFDC::Constants');

is
  WWW::SFDC::Constants::needsMetaFile('documents'),
  1,
  "Documents should need meta files";

is
  WWW::SFDC::Constants::hasFolders('documents'),
  1,
  "Documents should need folders";

is
  WWW::SFDC::Constants::getEnding('reports'),
  '.report',
  "Reports should have a .report ending";

is
  WWW::SFDC::Constants::getDiskName('CustomObject'),
  'objects',
  "The CustomObject should be saved in objects/";

is
  WWW::SFDC::Constants::getName('objects'),
  'CustomObject',
  "objects/ should have API name CustomObject";

ok
  scalar WWW::SFDC::Constants::getSubcomponents() > 0,
  "There should be multiple subcomponents";

done_testing();
