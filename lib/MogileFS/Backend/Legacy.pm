package MogileFS::Backend::Legacy;

use strict;
use warnings;
no strict 'refs';

use base 'MogileFS::Backend';

sub _escape_url_string {
    my $str = shift;
    $str =~ s/([^a-zA-Z0-9_\,\-.\/\\\: ])/uc sprintf("%%%02x",ord($1))/eg;
    $str =~ tr/ /+/;
    return $str;
}

sub _unescape_url_string {
    my $str = shift;
    $str =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
    $str =~ tr/+/ /;
    return $str;
}

sub _encode_url_string {
    my %args = @_;
    return "" unless %args;
    return join("&",
                map { _escape_url_string($_) . '=' .
                      _escape_url_string($args{$_}) }
                grep { defined $args{$_} } keys %args
                );
}

sub _decode_url_string {
    my $arg = shift;
    my $buffer = ref $arg ? $arg : \$arg;
    my $hashref = {};  # output hash

    my $pair;
    my @pairs = split(/&/, $$buffer);
    my ($name, $value);
    foreach $pair (@pairs) {
        ($name, $value) = split(/=/, $pair);
        $value =~ tr/+/ /;
        $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
        $name =~ tr/+/ /;
        $name =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
        $hashref->{$name} .= $hashref->{$name} ? "\0$value" : $value;
    }

    return $hashref;
}

sub prepare_req {
    my $self = shift;
    my ($cmd, $args) = @_;

    my $argstr = _encode_url_string(%$args);
    return "$cmd $argstr\r\n";
}

sub parse_line {
    my $self = shift;
    my $line = shift;

    # ERR <errcode> <errstr>
    if ($line =~ /^ERR\s+(\w+)\s*(\S*)/) {
        $self->{'lasterr'} = $1;
        $self->{'lasterrstr'} = $2 ? _unescape_url_string($2) : undef;
        #_debug("LASTERR: $1 $2");
        return undef;
    }

    # OK <arg_len> <response>
    if ($line =~ /^OK\s+\d*\s*(\S*)/) {
        my $args = _decode_url_string($1);
        #_debug("RETURN_VARS: ", $args);
        return $args;
    }

    die "Parse error";
}

1;
