use v6.c;

use HTTP::UserAgent;
use XML::Class;
use URI::Template;

class Monitor::Monit {

    has Str  $.host      =   'localhost';
    has Int  $.port      =   2812;
    has Bool $.secure    =   False;
    has Str  $.username  =   'admin';
    has Str  $.password  =   'monit';

    role MonitResponse {

    }

    class UserAgent is HTTP::UserAgent {
        use HTTP::Request::Common;

        has Str  $.host      =   'localhost';
        has Int  $.port      =   2812;
        has Bool $.secure    =   False;
        has Str  $.username  =   'admin';
        has Str  $.password  =   'monit';

        has %!default-headers;

        has Str $!base-url;


        method base-url() returns Str {
            if not $!base-url.defined {
                $!base-url = 'http' ~ ($!secure ?? 's' !! '') ~ '://' ~ $!host ~ ':' ~ $!port.Str ~ '{/path*}{?params*}';
            }
            $!base-url;
        }

        has URI::Template $!base-template;

        method base-template() returns URI::Template handles <process> {
            if not $!base-template.defined {
                $!base-template = URI::Template.new(template => self.base-url);
            }
            $!base-template;
        }


        proto method get(|c) { * }

        multi method get(:$path!, :$params, *%headers) returns MonitResponse {
            self.request(GET(self.process(:$path, :$params), |%!default-headers, |%headers)) but MonitResponse;
        }

        proto method post(|c) { * }

        multi method post(:$path!, :$params, Str :$content, :%form, *%headers) returns MonitResponse {
            if %form {
                # Need to force this here
                my %h = Content-Type => 'application/x-www-form-urlencoded', content-type => 'application/x-www-form-urlencoded';
                self.request(POST(self.process(:$path, :$params), %form, |%!default-headers, |%headers, |%h)) but MonitResponse;
            }
            else {
                self.request(POST(self.process(:$path, :$params), :$content, |%!default-headers, |%headers)) but MonitResponse;
            }
        }

    }

    has UserAgent $.ua;

    method ua() returns UserAgent handles <get put post> {
        if not $!ua.defined {
            $!ua = UserAgent.new(:$!host, :$!port, :$!secure, :$!username, :$!password);
            $!ua.auth($!username, $!password);
        }
        $!ua;
    }

    enum ServiceType <Filesystem Directory File Process Host System Fifo State>;

    class Status does XML::Class[xml-element => 'monit'] {
        sub duration-in(Str $v) returns Duration {
            $v.defined ?? Duration.new(Int($v)) !! Duration;
        }
        sub version-in(Str $v) returns Version {
            Version.new($v);
        }
        class Server does XML::Class[xml-element => 'server'] {
            class Httpd does XML::Class[xml-element => 'httpd'] {
                has Str $.address is xml-element;
                has Int $.port    is xml-element;
                has Bool $.ssl    is xml-element;
            }
            has Str         $.id            is xml-element;
            has Int         $.incarnation   is xml-element;
            has Version     $.version       is xml-element  is xml-deserialise(&version-in);
            has Duration    $.uptime        is xml-element  is xml-deserialise(&duration-in);
            has Duration    $.poll          is xml-element  is xml-deserialise(&duration-in);
            has Duration    $.startdelay    is xml-element  is xml-deserialise(&duration-in);
            has Str         $.localhostname is xml-element;
            has Str         $.controlfile   is xml-element;
            has Httpd       $.httpd;
        }
        class Platform does XML::Class[xml-element => 'platform'] {
            has Str     $.name  is xml-element;
            has Str     $.version   is  xml-element;
            has Str     $.machine   is  xml-element;
            has Int     $.cpu       is  xml-element;
            has Int     $.memory    is  xml-element;
            has Int     $.swap      is  xml-element;
        }

        class Service does XML::Class[xml-element => 'service'] {
            class Memory does XML::Class[xml-element => 'memory'] {
                has Num $.percent           is xml-element;
                has Num $.percent-total     is xml-element('percenttotal');
                has Int $.kilobyte          is xml-element;
                has Int $.kilobyte-total    is xml-element('kilobytetotal');
            }
            class Cpu does XML::Class[xml-element => 'cpu'] {
                has Num $.percent           is xml-element;
                has Num $.percent-total     is xml-element('percenttotal');
            }
            class Port does XML::Class[xml-element => 'port'] {
                has Str $.hostname          is xml-element;
                has Int $.portnumber        is xml-element;
                has Str $.request           is xml-element;
                has Str $.protocol          is xml-element;
                has Str $.type              is xml-element;
                has Num $.response-time     is xml-element('responsetime');
            }
            class Unix does XML::Class[xml-element => 'unix'] {
                has Str $.path              is xml-element;
                has Str $.protocol          is xml-element;
                has Num $.response-time     is xml-element('responsetime');
            }
            class System does XML::Class[xml-element => 'system'] {
                class Load does XML::Class[xml-element => 'load'] {
                    has Num $.average-minute    is xml-element('avg01');
                    has Num $.average-five      is xml-element('avg05');
                    has Num $.average-fifteen   is xml-element('avg15');
                }
                class Cpu does XML::Class[xml-element => 'cpu'] {
                    has Num $.user              is xml-element;
                    has Num $.system            is xml-element;
                    has Num $.wait              is xml-element;
                }
                class Memory does XML::Class[xml-element => 'memory'] {
                    has Num $.percent           is xml-element;
                    has Int $.kilobyte          is xml-element;
                }
                class Swap does XML::Class[xml-element => 'swap'] {
                    has Num $.percent           is xml-element;
                    has Int $.kilobyte          is xml-element;
                }
                has Load    $.load;
                has Cpu     $.cpu;
                has Memory  $.memory;
                has Swap    $.swap;
            }
            has ServiceType $.type              is xml-deserialise(-> Str $v { ServiceType($v) });
            has Str         $.name              is xml-element;
            has DateTime    $.collected         is xml-element('collected_sec') is xml-deserialise(-> Int(Str) $v { DateTime.new($v) } );
            has Int         $.collected-usec    is xml-element('collected_usec');
            has Int         $.status            is xml-element; 
            has Int         $.status-hint       is xml-element('status_hint');
            has Bool        $.monitor           is xml-element;
            has Int         $.monitormode       is xml-element;
            has Int         $.pendingaction     is xml-element;
            has Int         $.pid               is xml-element;
            has Int         $.ppid              is xml-element;
            has Int         $.uid               is xml-element;
            has Int         $.euid              is xml-element;
            has Int         $.gid               is xml-element;
            has Duration    $.uptime            is xml-element is xml-deserialise(&duration-in);
            has Int         $.children          is xml-element;
            has Memory      $.memory;
            has Cpu         $.cpu;
            has Port        @.port;
            has Unix        @.unix;
            has System      $.system;
        }

        has Server      $.server;
        has Platform    $.platform;
        has Service     @.service;

    }

    enum Action ( Stop => 'stop', Start => 'start', Restart => 'restart', Monitor => 'monitor', Unmonitor => 'unmonitor');

    class X::Monit::HTTP is Exception {
        has $.code is required;
        has $.status-line is required;

        method message() {
            "HTTP request failed : { $!code } {$!status-line}";
        }
    }

    role ServiceWrapper[UserAgent $ua] {
        has UserAgent $!ua handles <get put post> = $ua;

        method command(Action $action) returns Bool {
            my Bool $rc = False;
            my %form = action => $action.Str;
            if my $resp = self.post(path => [ self.name ], :%form  ) {
                $rc = $resp.is-success;
            }
            $rc;
        }

        method stop() {
            self.command(Stop);
        }
        method start() {
            self.command(Start);
        }
        method restart() {
            self.command(Restart);
        }
        method monitor() {
            self.command(Monitor);
        }
        method unmonitor() {
            self.command(Unmonitor);
        }
    }


    method status() returns Status {
        my Status $status;

        if my $resp = self.get(path => ['_status'], params => format => 'xml') {
            if $resp.is-success {
                $status = Status.from-xml($resp.content);
                $= $_ does ServiceWrapper[$!ua] for $status.service;
            }
            else {
                X::HTTP.new(code => $resp.code, status-line => $resp.status-line).throw;
            }
        }
        $status;
    }


}
# vim: expandtab shiftwidth=4 ft=perl6
