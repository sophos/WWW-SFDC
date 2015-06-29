package WWW::SFDC::SessionManager;
# ABSTRACT: Manages auth and SOAP::Lite interactions for WWW::SFDC modules

use 5.12.0;
use strict;
use warnings;

use Data::Dumper;
use Log::Log4perl ':easy';
use Module::Loaded;
use SOAP::Lite
  +trace => [debug => sub { TRACE 'SOAP Request' . Dumper $_[0] }],
  readable => 1;

use Moo;
with 'MooX::Singleton';

$SOAP::Transport::HTTP::Client::USERAGENT_CLASS = "AnyEvent::HTTP::LWP::UserAgent" if is_loaded "AnyEvent::HTTP::LWP::UserAgent";

=head1 SYNOPSIS

    my $sessionId = WWW::SFDC::Login->instance({
        username => "foo",
        password => "bar",
        url      => "baz",
    })->loginResult()->{"sessionId"};

=cut

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
  isa => sub { LOGDIE "The API version must be >= 31" unless $_[0] and $_[0] >= 31},
  default => '33.0';

has 'loginResult',
  is => 'rw',
  lazy => 1,
  builder => '_login';

has 'attempts',
  is => 'rw',
  default => 3;

sub _login {
  my $self = shift;

  INFO "Logging in...\t";

  $SOAP::Constants::PATCH_HTTP_KEEPALIVE=1;
  my $request = SOAP::Lite
    ->proxy($self->url()."/services/Soap/u/".$self->apiVersion())
    ->readable(1)
    ->ns("urn:partner.soap.sforce.com","urn")
    ->call(
      'login',
      SOAP::Data->name("username")->value($self->username()),
      SOAP::Data->name("password")->value($self->password())
     );

  TRACE "request " => Dumper $request;
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
    ->proxy($URL, timeout => 300)
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
  my $req;
  my $attempts = $self->attempts;

  while (
    $req = $self->_doCall(@_)
    and $req->fault
  ) {
    TRACE "Operation request ". Dumper $req;

    if ($req->faultstring =~ /INVALID_SESSION_ID/) {
        $self->loginResult($self->_login());
    } elsif ($attempts > 0 and $req->faultcode > 499) {
        $attempts--
    } else {
        LOGDIE "$_[0] Failed: " . $req->faultstring
    }
  }

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

=head1 BUGS

Please report any bugs or feature requests at L<https://github.com/alexander-brett/WWW-SFDC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::SFDC::SessionManager

You can also look for information at L<https://github.com/alexander-brett/WWW-SFDC>
