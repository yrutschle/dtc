package OutText;

# This file is the output driver for text diagrams for dtc.

use Moose;
use Data::Dumper;

has verbose => (is => 'rw');
has max_prot_level => (is => 'ro', required => 1);

# length of longest protocol name
has _max_prot_len => (is => 'rw');

# length of protocol boxes
sub _prot_box_len {
    return $_[0]->_max_prot_len + 10;
}

my $debug = 0;


# length of longest system box label
has _max_system_label => (is => 'rw');

# ref to an array of text lines
has _text => (is => 'rw', default => sub { [] });

# Initialises out
# $prot: ref to of protocol box list
# $functions: ref to function arrow list
# $systems: ref to system box list
# $cfg: ref to configuration hash
#
# The unit for all measurements is the length of the protocol box. It's set to
# be the size of the longest protocol name OR the longest function name
sub init_out {
    my ($self, $prot, $functions, $systems, $cfg) = @_;

    # Find longest protocol box
    $self->_max_prot_len(0);
    foreach my $col (@$prot) {
        foreach my $cell (@$col) {
            my $len = length $cell->{box_label};
            $self->_max_prot_len($len) if $len > $self->_max_prot_len;
        }
    }

    # find longest function arrow caption
    foreach my $arrow (@$functions) {
        my $len = length($arrow->{arrow_service}) - 4;
        $self->_max_prot_len($len) if $len > $self->_max_prot_len;
    }

    # Find longest system box
    $self->_max_system_label(0);
    foreach (@$systems) {
        my $len = length $_->{box_name};
        $self->_max_system_label($len) if $len > $self->_max_system_label;
    }

    # Create enough lines
    my $max_x = (1 + scalar @$prot) * $self->_prot_box_len;
    my $max_y = $self->max_prot_level * 2 + 12;
    warn "size: $max_x x $max_y\n" if $self->verbose;
    for (my $i = 0; $i < $max_y; $i++) {
        # Create enough columns
        $self->_text->[$i] = ' ' x $max_x;
    } 
}

sub save {
    my ($self, $filename) = @_;
    warn "saving to $filename\n" if $self->verbose;

    open my $f, ">>$filename" or die "$filename: $!\n";

    foreach my $line (@{$self->_text}) {
        print $f "$line\n";
    }
}

sub make_prot_box {
    my ($self, $box) = @_;
    my ($x, $y, $length, $caption) = @$box{qw/box_x box_y box_len box_label/};

    return if $caption eq 'void';

    $self->_draw_rectangle(
        $x * $self->_prot_box_len + 4, 
        $y * 2 + 4,
        ($x + $length) * $self->_prot_box_len + 4,
        $y * 2 + 4 + 2,
        fill => ' ',
    );
    $self->_draw_text( 
        ($x + $length/2) * $self->_prot_box_len + 4 - length($caption)/2,
        $y * 2 + 5,
        $caption
    );
}



# Make a filtering function arrow.
# $x: location
# $level: how many protocol levels are filtered
# $caption: string describing the function
sub make_function_arrow {
    my ($self, $arrow) = @_;
    my ($x, $level, $caption, $r_icons) = @$arrow{qw/arrow_x arrow_height arrow_service arrow_icons/};

    warn "arrow ".($self->_prot_box_len + 4).",".($self->max_prot_level*2 + 7)." $caption\n" if $debug;

    for (my $j = ($self->max_prot_level - $level) * 2 + 4; $j < $self->max_prot_level * 2 + 10; $j++) {
        substr($self->_text->[$j], $x * $self->_prot_box_len + 4, 1) = '#';
    }
    substr($self->_text->[$self->max_prot_level*2+9], 
        $x * $self->_prot_box_len + 4, 1) = 'V';

    substr($self->_text->[$self->max_prot_level*2+11], 
        $x * $self->_prot_box_len + 4, length $caption) = $caption;
}


sub add_icons {
#    warn "icons are not supported in text output\n";
}
    

# Make a security function arrow
# $x, $y: box location
# $orient: 'r' or 'l' depending on where it's going
# $colour: 0-4: changes the colour of the arrow depending on # SAL
# $caption: 0-9: reference printed in the arrow
sub make_security_function_arrow {
    my ($self, $arrow) = @_;
    my ($x, $y, $orient, $colour, $caption) = @$arrow{qw/sf_x sf_y sf_orient sf_level sf_caption/};

    if ($orient eq 'l') {
    $self->_draw_text(
        $x * $self->_prot_box_len + 6,
        $y * 2 + 5,
        "<$caption",
    );
} else {
    $self->_draw_text(
        ($x + 1) * $self->_prot_box_len + 1,
        $y * 2 + 5,
        "$caption>",
    );
}
}


# Make a system box that goes in the background (must draw
# first)
# $x1, $x2: where does the box start and end
# $caption: system name
sub make_system_box {
    my ($self, $box) = @_;
    my ($start, $end, $name) = @$box{qw/box_start box_end box_name/};

    $self->_draw_rectangle(
        $start * $self->_prot_box_len, 
        0,
        ($end + 1) * $self->_prot_box_len - 3, 
        $self->max_prot_level * 3 + 2
    );
    $self->_draw_text($start * $self->_prot_box_len + 2, 2, $name);
}


sub _draw_rectangle {
    my ($self, $x1, $y1, $x2, $y2, %opts) = @_;

    warn "rect $x1,$y1 $x2,$y2\n" if $debug;

    # vertical lines and fill
    for (my $j = $y1; $j < $y2; $j++) {
        substr($self->_text->[$j], $x1, 1) = '|';
        substr($self->_text->[$j], $x2, 1) = '|';
        if (exists $opts{fill}) {
            substr($self->_text->[$j], $x1 + 1, $x2 - $x1 - 2) = $opts{fill} x ($x2 - $x1 - 2);
        }
    }

    # horizontal lines
    substr($self->_text->[$y1], $x1, $x2 - $x1) = '-' x ($x2 - $x1);
    substr($self->_text->[$y2], $x1, $x2 - $x1) = '-' x ($x2 - $x1);

    # corners
    substr($self->_text->[$y1], $x1, 1) = '+';
    substr($self->_text->[$y2], $x1, 1) = '+';
    substr($self->_text->[$y1], $x2, 1) = '+';
    substr($self->_text->[$y2], $x2, 1) = '+';
}

sub _draw_text {
    my ($self, $x, $y, $text) = @_;

    warn "text: $x $y $text\n" if $debug;

    substr($self->_text->[$y], $x, length $text) = $text;
}

1;
