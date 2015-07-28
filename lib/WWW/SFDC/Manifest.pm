package WWW::SFDC::Manifest;
# ABSTRACT: Utility functions for Salesforce Metadata API interactions.

use 5.12.0;
use strict;
use warnings;

# VERSION

use Data::Dumper;
use List::Util 1.29 qw'first reduce pairmap pairgrep pairfirst';
use Log::Log4perl ':easy';
use Method::Signatures;
use Scalar::Util qw(blessed);
use XML::Parser;

use Moo;

has 'apiVersion', is => 'rw', default => '34';
has 'constants', is => 'ro', required => 1;
has 'isDeletion', is => 'ro';
has 'manifest', is => 'rw', default => sub { {} };

=head1 SYNOPSIS

This module is used to read SFDC manifests from disk, add files to them,
and get a structure suitable for passing into WWW::SFDC::Metadata functions.

    my $SFDC = WWW::SFDC->new(...);
    my $Manifest = WWW::SFDC::Manifest
        ->new(constants => $SFDC->Constants)
        ->readFromFile("filename")
        ->addList()
        ->add({Document => ["bar/foo.png"]});

    my $HashRef = $Manifest->manifest();
    my $XMLString = $Manifest->getXML();

=cut

# _splitLine($line)

# Takes a string representing a file on disk, such as "email/foo/bar.email-meta.xml",
# and returns a hash containing the metadata type, folder name, file name, and
# file extension, excluding -meta.xml.

method _splitLine ($line) {
  # clean up the line
  $line =~ s/.*src\///;
  $line =~ s/[\n\r]//g;

  my %result = ("extension" => "");

  ($result{"type"}) = $line =~ /^(\w+)\//
    or LOGDIE "Line $line doesn't have a type.";
  $result{"folder"} = $1
    if $line =~ /\/(\w+)\//;

  my $extension = (grep {$_ eq $result{type}} keys $self->constants->TYPES)
    ? $self->constants->getEnding($result{"type"})
    : undef;

  if ($line =~ /\/(\w+)-meta.xml/) {
    $result{"name"} = $1
  } elsif (!defined $extension) {
    ($result{"name"}) = $line =~ /\/([^\/]*?)(-meta\.xml)?$/;
    # This is because components get passed back from listDeletions with : replacing .
    $result{"name"} =~ s/:/./;
  } elsif ($line =~ /\/([^\/]*?)($extension)(-meta\.xml)?$/) {
    $result{"name"} = $1;
    $result{"extension"} = $2;
  }

  LOGDIE "Line $line doesn't have a name." unless $result{"name"};

  return \%result;
}

# _getFilesForLine($line)

# Takes a string representing a file on disk, such as "email/foo/bar.email",
# and returns a list representing all the files needed in the zip file for
# that file to be successfully deployed, for example:

# - email/foo-meta.xml
# - email/foo/bar.email
# - email/foo/bar.email-meta.xml

method _getFilesForLine ($line?) {
  return () unless $line;

  my %split = %{$self->_splitLine($line)};

  return map {"$split{type}/$_"} (
    $split{"folder"}
    ?(
      "$split{folder}-meta.xml",
      "$split{folder}/$split{name}$split{extension}",
      ($self->constants->needsMetaFile($split{"type"}) ? "$split{folder}/$split{name}$split{extension}-meta.xml" : ())
     )
    :(
      "$split{name}$split{extension}",
      ($self->constants->needsMetaFile($split{"type"}) ? "$split{name}$split{extension}-meta.xml" : ())
     )
   )
}


# _dedupe($listref)

# Returns a list reference to a _deduped version of the list
# reference passed in.

method _dedupe {
  my %result;
  for my $key (keys %{$self->manifest}) {
    my %_deduped = map {$_ => 1} @{$self->manifest->{$key}};
    $result{$key} = [sort keys %_deduped];
  }
  $self->manifest(\%result);
  return $self;
}

=method getFileList(@list)

Returns a list of files needed to deploy this manifest. Use this to construct
a .zip file.

=cut

method getFileList {

  return map {
    my $type = $self->constants->getDiskName($_);
    my $ending = $self->constants->getEnding($type) || "";

    map {
      if ($self->constants->hasFolders($type) and $_ !~ /\//) {
        "$type/$_-meta.xml";
      } else {
	      "$type/$_$ending", ($self->constants->needsMetaFile($type) ? "$type/$_$ending-meta.xml" : () );
      }
    } @{ $self->manifest->{$_} }
  } keys %{$self->manifest};
}

=method add($manifest)

Adds an existing manifest object or hash to this one.

=cut

method add ($new) {

  if (defined blessed $new and blessed $new eq blessed $self) {
    push @{$self->manifest->{$_}}, @{$new->manifest->{$_}} for keys %{$new->manifest};
  } else {
    push @{$self->manifest->{$_}}, @{$new->{$_}} for keys %$new;
  }

  return $self->_dedupe();
}

=method addList($isDeletion, @list)

Adds a list of components or file paths to the manifest file.

=cut

method addList (@_) {

  return reduce {$a->add($b)} $self, map {
    TRACE "Adding $_ to manifest";
    +{
      $self->constants->getName($$_{type}) => [
        defined $$_{folder}
          ? (
              ($self->isDeletion ? () : $$_{folder}),
              "$$_{folder}/$$_{name}"
            )
          : ($$_{name})
      ]
    }
  } map {$self->_splitLine($_)} @_;
}

=method readFromFile $location

Reads a salesforce package manifest and adds it to the current object, then
returns it.

=cut

method readFromFile ($fileName) {
  return reduce {$a->add($b)} $self, map {+{
    do {
      pairmap {$b->[2]} pairfirst {$a eq 'name'} @$_
    } => [
      pairmap {$b->[2]} pairgrep {$a eq 'members'} @$_
     ]
  }}
    pairmap {[splice @{$b}, 1]} pairgrep {$a eq 'types'}
    splice @{
      XML::Parser->new(Style=>"Tree")->parsefile($fileName)->[1]
      }, 1;
}

=method writeToFile $location

Writes the manifest's XML representation to the given file and returns
the manifest object.

=cut

method writeToFile ($fileName) {
  open my $fh, ">", $fileName or LOGDIE "Couldn't open $fileName to write manifest to disk";
  print $fh $self->getXML();
  return $self;
}

=method getXML($mapref)

Returns the XML representation for this manifest.

=cut

method getXML {
  return join "", (
    "<?xml version='1.0' encoding='UTF-8'?>",
    "<Package xmlns='http://soap.sforce.com/2006/04/metadata'>",
    (
      map {(
      	"<types>",
      	"<name>$_</name>",
      	( map {"<members>$_</members>"} @{$self->manifest->{$_}} ),
      	"</types>",
       )} sort keys %{$self->manifest}
     ),
    "<version>",$self->apiVersion,"</version></Package>"
   );
}


1;

__END__

=head1 BUGS

Please report any bugs or feature requests at L<https://github.com/alexander-brett/WWW-SFDC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::SFDC::Manifest

You can also look for information at L<https://github.com/alexander-brett/WWW-SFDC>
