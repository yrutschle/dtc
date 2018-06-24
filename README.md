# NAME

    dtc -- dataflow tabular chart

# SYNOPSIS

dtc.pl \[--config|-f &lt;config>\] \[--format &lt;png|txt|svg>\] &lt;input1> \[&lt;input2> ...\] -o &lt;out.png>

# DESCRIPTION

_dtc_ takes a textual description of a dafatlow diagram and produces a
graphical output of the diagram. It is very convenient to present complex
transport and filtering systems in one synthetic view.

The goal of the graphical representation is to convey information that is not
usually available on a standard architecture representation: those
representations usually show functional dataflows with no details on the
transport mechanisms. DTC represents the protocol layers across the whole
dataflow, allowing to show which device or service processes which part of the
protocol layers.

For example _email.svg_ shows a simple, typical e-mail setup whereby the
sender (on the right) sends e-mail to an SMTP server. The SMTP server saves
e-mail in local files (maybe using Maildir). An IMAP server on the same system
serves the local user. This diagram shows easily that a malformed e-mail
message can reach right inside the protected domain.

# DIAGRAM DESCRIPTION

The diagrams are composed of three types of lines:

- Systems

    Systems are drawn in the background and represent the
    physical hardware performing functions on the dataflow. An
    input line describing a system simply contains the system
    name followed by a colon:

        DMZ server:

- Functions

    Functions are typically processes that happen within a system and act on the
    dataflow. They correspond to vertical arrows in the output diagram. An input
    line describing a function is composed of `->` followed by the function
    name, followed by the number of protocol layers that are filtered in brackets,
    followed by an optional list of icons that will be added at specific protocol
    levels:

        -> Firewall (3) [2,cisco.png;3,iptables.png]

    Here we define a firewall that would cross three protocol levels, and add two
    PNGs at level 2 and 3 (a strange firewall).

    Note that the number of protocol layers is linked to the
    number of layers _in the diagram_ (see below), this has
    nothing to do with OSI layers.

- Protocols

    A protocol stack is present between each function and contains the stack of
    protocols that these functions will use to exchange data. Each protocol is
    separated by a slash.  A protocol name can be left blank (e.g. if the protocol
    used is irrelevant for the diagram) or named `void` in which case the box
    won't be drawn at all (e.g. if no protocol is used for that layer in the
    current stack, but is used somewhere else. This is often the case when
    transport goes through tunnels.)

    Each protocol can also receive an arrow pointing left or right, which is used
    to show where security filtering happens. These are presented by adding
    `<` or `>` character to the left or right of the protocol name,
    followed by the arrow colour (which can be used to represent the strenght of
    the filtering, or the assurance level of the security function) and an optional
    reference character that will be printed in the arrow. 

    Colours are indexes in the 'sf\_colours' list in the INI files, otherwise
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

Refer to the EXAMPLES section for full examples of diagrams.

# CONFIGURATION FILE

The configuration file allows to override a number of settings. See example to
make the output more colourful than the default.

It is not currently possible to change the security function arrow colours.

# OPTIONS

- `--config|-f config`

    Specifies a file that contains the configuration for the
    diagrams: sizes, colours and so on. If not specified,
    defaults to `dtc.ini`. All parameters have reasonable
    defaults if no configuration file is present.

- `--format`

    Specifies the output format. _png_ will produce a bitmap image. _txt_ will
    produce a glamorous, RFC-style text diagram. _SVG_ will produce standard
    vector graphics. The default is _SVG_.

- `--output`

    Specifies the output file name. By default, an extension '.png', '.svg' or
    '.txt' is appended to the input filename. If the input filename has the '.dtc'
    extension, it will be removed. '-' specifies stdout.

# EXAMPLE

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

The result of this diagram is included in the archive as _print.png_.

# BUGS

Empty lines at the end of the file are a bad idea.

Order of statements is important: First it's 'function', then 'protocol'.
System lines must come after a dataflow line.

# AUTHOR

Written by Yves Rutschle (dflows@rutschle.net)
