#! /usr/bin/perl -w
# dtc: dataflow tabular chart
# Copyright (C) 2015-2018  Yves Rutschle
# 
# This program is free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE.  See the GNU General Public License for more
# details.
# 
# The full text for the General Public License is here:
# http://www.gnu.org/licenses/gpl.html

use strict;
use Cwd 'abs_path';
use File::Basename;
use lib dirname( abs_path $0 );


use Getopt::Long;
use Pod::Usage;
use Data::Dumper;

=head1 NAME

 dtc -- dataflow tabular chart

=head1 SYNOPSIS

dtc.pl [--config|-f <config>] [--format <png|txt|svg>] <input1> [<input2> ...] -o <out.png>

=head1 DESCRIPTION

I<dtc> takes a textual description of a dafatlow diagram and produces a
graphical output of the diagram. It is very convenient to present complex
transport and filtering systems in one synthetic view.

The goal of the graphical representation is to convey information that is not
usually available on a standard architecture representation: those
representations usually show functional dataflows with no details on the
transport mechanisms. DTC represents the protocol layers across the whole
dataflow, allowing to show which device or service processes which part of the
protocol layers.

For example I<email.svg> shows a simple, typical e-mail setup whereby the
sender (on the right) sends e-mail to an SMTP server. The SMTP server saves
e-mail in local files (maybe using Maildir). An IMAP server on the same system
serves the local user. This diagram shows easily that a malformed e-mail
message can reach right inside the protected domain.

=head1 DIAGRAM DESCRIPTION

The diagrams are composed of three types of lines:

=over 4

=item Systems

Systems are drawn in the background and represent the
physical hardware performing functions on the dataflow. An
input line describing a system simply contains the system
name followed by a colon:

 DMZ server:

=item Functions

Functions are typically processes that happen within a system and act on the
dataflow. They correspond to vertical arrows in the output diagram. An input
line describing a function is composed of C<-E<gt>> followed by the function
name, followed by the number of protocol layers that are filtered in brackets,
followed by an optional list of icons that will be added at specific protocol
levels:

 -> Firewall (3) [2,cisco.png;3,iptables.png]

Here we define a firewall that would cross three protocol levels, and add two
PNGs at level 2 and 3 (a strange firewall).

Note that the number of protocol layers is linked to the
number of layers I<in the diagram> (see below), this has
nothing to do with OSI layers.

=item Protocols

A protocol stack is present between each function and contains the stack of
protocols that these functions will use to exchange data. Each protocol is
separated by a slash.  A protocol name can be left blank (e.g. if the protocol
used is irrelevant for the diagram) or named C<void> in which case the box
won't be drawn at all (e.g. if no protocol is used for that layer in the
current stack, but is used somewhere else. This is often the case when
transport goes through tunnels.)

Each protocol can also receive an arrow pointing left or right, which is used
to show where security filtering happens. These are presented by adding
C<E<lt>> or C<E<gt>> character to the left or right of the protocol name,
followed by the arrow colour (which can be used to represent the strenght of
the filtering, or the assurance level of the security function) and an optional
reference character that will be printed in the arrow. 

Colours are indexes in the 'sf_colours' list in the INI files, otherwise
correspond to blue, green, yellow, orange and red.

All protocol input lines must contain the same number of protocols.

For example, a file posted using DAV over HTTPS could be presented as such:

 Ethernet / <3 IP / <3 TCP / <3 SSL / <x,A HTTP / DAV file

Meaning the file is carried over HTTP over SSL over TCP over
IP over Ethernet, and a firewall with assurance level 3
filters IP, TCP and SSL, and a Web server with no assurance
level fiters HTTP. Reference 1, 2, 3 will be automatically
added to the IP, TCP and SSL layers, and reference A will be
added to HTTP.

=back

Refer to the EXAMPLES section for full examples of diagrams.

=head1 CONFIGURATION FILE

The configuration file allows to override a number of settings. See example to
make the output more colourful than the default.

It is not currently possible to change the security function arrow colours.

=head1 OPTIONS

=over 4

=item C<--config|-f config>

Specifies a file that contains the configuration for the
diagrams: sizes, colours and so on. If not specified,
defaults to F<dtc.ini>. All parameters have reasonable
defaults if no configuration file is present.

=item C<--format>

Specifies the output format. I<png> will produce a bitmap image. I<txt> will
produce a glamorous, RFC-style text diagram. I<SVG> will produce standard
vector graphics. The default is I<SVG>.

=item C<--output>

Specifies the output file name. By default, an extension '.png', '.svg' or
'.txt' is appended to the input filename. If the input filename has the '.dtc'
extension, it will be removed. '-' specifies stdout.

=back

=head1 EXAMPLE

    Printer:
    -> Printer (5)
    Ethernet / IP 4,4> / TCP 3,5> / ? / ?
    Router:
    -> Netfilter (3)
    void / IP / TCP / ? / ?
    -> CUPS (5)
    void / IP / TCP / IPP 3,6> / IPP printing payload
    -> IPP proxy (5)
    void / IP / TCP / <2,3 IPP / IPP printing payload
    -> Netfilter (3) [2,firewall.png]
    Ethernet / <0,1 IP / <1,2 TCP / IPP / IPP printing payload
    Laptop:
    -> Application (5)

(The example firewall icon is from http://icons.iconarchive.com/).

The result of this diagram is included in the archive as I<print.png>.

=head1 BUGS

Empty lines at the end of the file are a bad idea.

Order of statements is important: First it's 'function', then 'protocol'.
System lines must come after a dataflow line.

=head1 AUTHOR

Written by Yves Rutschle (dflows2@rutschle.net)

=cut

my ($help, $verbose, $ini_filename, $out_format, $out_filename);
GetOptions(
    'help' => \$help,
    'config=s' => \$ini_filename,
    'verbose' => \$verbose,
    'output=s' => \$out_filename,
    'format=s' => \$out_format,
    'f=s' => \$ini_filename,
) or die pod2usage();
die pod2usage(-verbose=>2) if defined $help;

$out_format //= 'svg';

##############################
# Read Configuration, with Reasonable defaults

$ini_filename = 'dtc.ini' if not defined $ini_filename;
my %cfg;
if (-e $ini_filename) {
    open my $f, "$ini_filename" or warn "$!\n";
    while (<$f>) {
        next unless /^(\w+)\s*:\s*(.*)/;
        my ($param, $val) = ($1, $2);
        if ($val =~ /\[(.*)\]/) {
            my @a = split /\s+/, $1;
            $val = \@a;
        }
        $cfg{$param} = $val;
    }
}



my $max_prot_level;  # Maximum protocol layer number (set during parsing)

##############################
# Input parsing
##############################

my $x = 0;
my $arrow_ref = 1; # Filter arrow reference counter, if not set explicitely
my ($system_name, $system_x);

warn "parsing input...\n" if $verbose;

# Arrays to store all the objects we'll draw
my (@system_boxes, @prot_boxes, @function_arrows, @sf_arrows); 
while (my $line = <>) {
    chop $line;

    if ($line =~ /^(.*):/) {
        if (defined $system_name) {
            # Draw the system box
            push @system_boxes, {
                box_start => $system_x, 
                box_end => $x - 1, 
                box_name => $system_name
            };
        }
        $system_name = $1;
        $system_x = $x;
        next;
    }

    if ($line =~ /^-> (.*)\s*\((\d+)\)(.*)/) {
        my ($service, $level, $rest) = ($1, $2, $3);
        my @icons;
        warn "$.: level not defined\n" if not defined $level;
	if ($rest =~ /\[(.*)\]/) {
            my @specs = split /;/, $1;
            foreach (@specs) {
                my ($prot, $icon) = split /,/, $_;
                die "Cannot read $icon\n" if not -r $icon;
                push @icons, [ $prot, $icon ];
            }
	}
        die "Missing protocols between `$function_arrows[-1]->{arrow_service}` and `$service`\n" 
            if @function_arrows and $x == $function_arrows[-1]->{arrow_x};
        push @function_arrows, {
            arrow_x => $x, 
            arrow_height => $level, 
            arrow_service => $service, 
            arrow_icons => \@icons
        };
        next;
    }

    if (my @prots = split /\s*\/\s*/, $line) {
        $max_prot_level = scalar @prots if not defined $max_prot_level;
        die "Incomplete protocol stack line $.:`$line`\n" if scalar @prots != $max_prot_level;
        @prots = reverse @prots;
        for (my $i = 0; $i < @prots; $i++) {
            my $prot = $prots[$i];
            if ($prot =~ s/\s*<(\S)(,(\S+))?\s*//) {
                my $ref = $3;
                $ref = $arrow_ref++ if not defined $ref;
                push @sf_arrows, {
                    sf_x => $x, 
                    sf_y => $i, 
                    sf_orient => 'l', 
                    sf_level => $1, 
                    sf_caption => $ref
                };
            }
            if ($prot =~ s/\s*(\S)(,(\S+))?>\s*//) {
                my $ref = $3;
		$ref = $arrow_ref++ if not defined $ref;
                push @sf_arrows, {
                    sf_x => $x, 
                    sf_y => $i, 
                    sf_orient => 'r', 
                    sf_level => $1, 
                    sf_caption => $ref
                };
            }
            $prot_boxes[$x][$i] = {
                box_x => $x, 
                box_y => $i, 
                box_len => 1, 
                box_label => $prot
            };
        }
        $x++;
        next;
    }

    warn "$.: Unable to parse\n";
}

# Draw the last system
push @system_boxes, {
    box_start => $system_x, 
    box_end => $x, 
    box_name => $system_name
};


##############################
# Image creation
##############################
# Now we have enough information to create the image object

my $out;

if ($out_format eq 'png') {
    use OutGD;
    $out = new OutGD(
        verbose => $verbose, 
        max_prot_level => $max_prot_level
    );
} elsif ($out_format eq 'txt') {
    use OutText;
    $out = new OutText(
        verbose => $verbose, 
        max_prot_level => $max_prot_level
    );
} elsif ($out_format eq 'svg') {
    use OutSVG;
    $out = new OutSVG(
        verbose => $verbose,
        max_prot_level => $max_prot_level
    );
} else {
    die "Unknown output format `$out_format'\n";
}

$out->init_out(\@prot_boxes, \@function_arrows, \@system_boxes, \%cfg);


#
# Now for drawing everthing, starting from the background:
# system boxes, then protocol boxes, then function arrows,
# then SAL arrows.
#

warn "drawing system boxes\n" if $verbose;
foreach (@system_boxes) {
    $out->make_system_box($_);
}

warn "merging protocol boxes\n" if $verbose;

my $debug_merge = 0;

# Merge protocol boxes that aren't cut by an arrow
warn "max_prot_level $max_prot_level\n" if $debug_merge;
for (my $y = 0; $y < $max_prot_level; $y++) {
    my $start_x = 0;
    my $x = 1;
    while (($x < @prot_boxes) ) {
        $prot_boxes[$start_x][$y]->{box_label} //= "";
        $prot_boxes[$x][$y]->{box_label} //= "";
        # Extend the box if the label is the same and the filtering arrow
        # doesn't reach that high
        if ($prot_boxes[$start_x][$y]->{box_label} eq $prot_boxes[$x][$y]->{box_label}
                and $y < ($max_prot_level - $function_arrows[$x]->{arrow_height})
        ) {
            $prot_boxes[$start_x][$y]->{box_len}++;
            $prot_boxes[$x][$y] = undef;
            warn "prot box[$start_x][$y] extended to $x\n" if $debug_merge;
        } else {
            $start_x = $x;
            warn "$start_x,$y: $prot_boxes[$start_x][$y]->{box_label} $x,$y: $prot_boxes[$x][$y]->{box_label} arrow to: $function_arrows[$x]->{arrow_height}\n" if $debug_merge;
        }
        $x++;
    }
}

warn "drawing protocol boxes\n" if $verbose;

# Draw all protocol boxes
foreach my $col (@prot_boxes) {
    foreach my $cell (@$col) {
        $out->make_prot_box($cell) if defined $cell;
    }
}

warn "drawing function arrows\n" if $verbose;

foreach my $arrow (@function_arrows) {
    $out->make_function_arrow($arrow);
}

warn "drawing security function arrows\n" if $verbose;

foreach (@sf_arrows) {
    $out->make_security_function_arrow($_);
}

warn "adding icons\n" if $verbose;

$out->add_icons(@function_arrows);

if (not defined $out_filename) {
    $out_filename = $ARGV;
    $out_filename =~ s/\.dtc/.$out_format/;
    $out_filename .= "$out_format" if $out_filename eq $ARGV; # avoid erasing input file
}

$out->save($out_filename);


