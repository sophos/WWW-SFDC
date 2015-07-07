package WWW::SFDC::Role::CRUD;
# ABSTRACT: Shared methods between partner and tooling APIs

use 5.12.0;
use strict;
use warnings;

# VERSION

use List::NSect 'spart';
use Log::Log4perl ':easy';
use Moo::Role;
use Scalar::Util 'blessed';
use SOAP::Lite;

requires qw'';

=method query

  say $_->{Id} for WWW::SFDC::Partner->instance()->query($queryString);

If the query() API call is incomplete and returns a queryLocator, this
library will continue calling queryMore() until there are no more records to
recieve, at which point it will return the entire list.

As it stands, if you want the native API behaviour, you will need to use the
internal methods _query and _queryMore.

=method queryAll

This has the same additional behaviour as query().

=cut

sub _query {
  my ($self, $query) = @_;
  return $self->_call(
    'query',
    SOAP::Data->name(queryString => $query),
  );
}

sub _queryAll {
  my ($self, $query) = @_;
  return $self->_call(
    'queryAll',
    SOAP::Data->name(queryString => $query),
  );
}

sub _queryMore {
  my ($self, $locator) = @_;
  return $self->_call(
    'queryMore',
    SOAP::Data->name(queryLocator => $locator),
  );
}

# Extract the results from a $request. This handles the case
# where there is only one result, as well as 0 or more than 1.
# They require different handling because in the 1 case, you
# can't handle it as an array
sub _getQueryResults {
  my ($self, $request) = @_;
  return ref $request->{records} eq 'ARRAY'
    ? map {$self->_cleanUpSObject($_)} @{$request->{records}}
    : ( $self->_cleanUpSObject($request->{records}) );
}

# Unbless an SObject, and de-duplicate the ID field - SFDC
# duplicates the ID, which is interpreted as an arrayref!
sub _cleanUpSObject {
  my ($self, $obj) = @_;
  return () unless $obj;
  my %copy = %$obj; # strip the class from $obj
  $copy{Id} = $copy{Id}->[0] if ref $copy{Id} eq "ARRAY";

  while (my ($key, $entry) = each %copy) {
    if (blessed $entry eq 'sObject') {
      $copy{$key} = $self->_cleanUpSObject($entry);
    } elsif (blessed $entry eq 'QueryResult') {
      $entry = [
        ref $entry->{records} eq 'ARRAY'
          ? map {$self->_cleanUpSObject($_)} @{$entry->{records}}
          : $self->_cleanUpSObject($entry->{records})
      ];
    }
  }

  return \%copy;
}

# Given the output of _query() or _queryAll(), chain
# together calls to _queryMore() and aggregate the results.
sub _completeQuery {
  my ($self, $request) = @_;
  my @results = $self->_getQueryResults($request);

  until ($request->{done} eq 'true') {
    $self->_sleep();
    $request = $self->_queryMore($request->{queryLocator});
    push @results, $self->_getQueryResults($request);
  }

  return @results;
}

sub query {
  my ($self, $query) = @_;
  INFO "Executing SOQL query: ".$query;
  return $self->_completeQuery(
    $self->_query($query)
  );
}

sub queryAll {
  my ($self, $query) = @_;
  return $self->_completeQuery(
    $self->_queryAll($query)
  );
}

=method create

  say "$$_{id}:\t$$_{success}" for WWW::SFDC::Partner->instance()->create(
    {type => 'thing', Id => 'foo', Field__c => 'bar', Name => 'baz'}
    {type => 'otherthing', Id => 'bam', Field__c => 'bas', Name => 'bat'}
  );

Create chunks your SObjects into 200s before calling create(). This means that if
you have more than 200 objects, you will incur multiple API calls.

=cut

sub create {
  my $self = shift;

  return map {
    $self->_call(
      'create',
      $self->_prepareSObjects(@$_)
    );
  } spart 200, @_;
}

=method update

  say "$$_{id}:\t$$_{success}" for WWW::SFDC::Partner->instance()->update(
    {type => 'thing', Id => 'foo', Field__c => 'bar', Name => 'baz'}
    {type => 'otherthing', Id => 'bam', Field__c => 'bas', Name => 'bat'}
  );

Returns an array that looks like [{success => 1, id => 'id'}, {}...] with LOWERCASE keys.

=cut

sub update {
  my $self = shift;

  TRACE "Objects for update" => \@_;
  INFO "Updating objects";

  return $self->_call(
    'update',
    $self->_prepareSObjects(@_)
   );
}

=method delete

  say "$$_{id}:\t$$_{success}" for WWW::SFDC::Partner->instance()->delete(@ids);

Returns an array that looks like [{success => 1, id => 'id'}, {}...] with LOWERCASE keys.

=cut

sub delete {
    my $self = shift;

    DEBUG "IDs for deletion" => \@_;
    INFO "Deleting objects";

    return $self->_call(
        'delete',
        map {SOAP::Data->name('ids' => $_)} @_
    );
}

=method undelete

  say "$$_{id}:\t$$_{success}" for WWW::SFDC::Partner->instance()->undelete(@ids);

Returns an array that looks like [{success => 1, id => 'id'}, {}...] with LOWERCASE keys.

=cut

sub undelete {
    my $self = shift;

    DEBUG "IDs for undelete" => \@_;
    INFO "Deleting objects";

    return $self->_call(
        'undelete',
        map {SOAP::Data->name('ids' => $_)} @_
    );
}

=method retrieve

Retrieves SObjects by ID. Not to be confused with the metadata retrieve method.

=cut

sub retrieve {
    my $self = shift;

    DEBUG "IDs for retrieve" => \@_;
    INFO "Retrieving objects";

    return $self->_call(
        'retrieve',
        map {SOAP::Data->name('ids' => $_)} @_
    );
}

1;

__END__

=head1 BUGS

Please report any bugs or feature requests at L<https://github.com/alexander-brett/WWW-SFDC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::SFDC::Role::CRUD

You can also look for information at L<https://github.com/alexander-brett/WWW-SFDC>
