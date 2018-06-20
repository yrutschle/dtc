package OutSVG;

# This file is the output driver for vector graphics for dtc.

use strict;
use Moose;
use SVG;
use MIME::Base64;

has verbose => (is => 'rw');
has max_prot_level => (is => 'ro', required => 1);

# Reference to the svg object
has _svg => (is => 'rw');

# Protocol shift: Where to start drawing protocol boxes
my $PROT_SHIFT_X;
my $PROT_SHIFT_Y;

# Protocol box size
my $PROT_SIZE_X;
my $PROT_SIZE_Y;

my $FONT;
my $FONT_SIZE;

my @sf_color_cfg;
my $no_sf_cfg;

my @prot_box_cfg;
my @system_box_cfg;


################################################################################

sub _val {
    my ($cfg, $param, $default) = @_;
    return exists $cfg->{$param} ? $cfg->{$param} : $default;
}

sub _load_cfg {
    my ($self, $cfg) = @_;

    $PROT_SHIFT_X = _val($cfg, 'prot_shift_x', 60);;
    $PROT_SHIFT_Y = _val($cfg, 'prot_shift_y', 30);;

# Protocol box size
    $PROT_SIZE_X = _val($cfg, 'prot_size_x', 150);;
    $PROT_SIZE_Y = _val($cfg, 'prot_size_y', 45);;

    $FONT = _val($cfg, 'font', 'Arial');
    $FONT_SIZE = _val($cfg, 'font_size', 12);

    $no_sf_cfg = _val($cfg, 'no_sf', 'rgb(192,192,192)');

    # Pick one: http://hslpicker.com/

        # Default, boring color scheme
        my $rgb = Convert::Color->new("rgb8:213,184,127");
        for ( 0 .. $self->max_prot_level - 1 ) {
            push @prot_box_cfg, $rgb;
        }
        @sf_color_cfg = (
            "rgb(57,142,19)",
            "rgb(88,221,28)",
            "rgb(250,245,0)",
            "rgb(244,167,28)",
            "rgb(221,29,29)"
        );
        $rgb = Convert::Color->new("rgb8:200,200,200");
        @system_box_cfg = $rgb->rgb8;
}

sub make_prot_box {
    my ($self, $box) = @_;
    my $img = $self->_svg;
    my ($x, $y, $length, $caption) = @$box{qw/box_x box_y box_len box_label/};
    return if $caption eq 'void';

#    $img->bgcolor($img->colorAllocate(@{$prot_box_cfg[$y]}));

    $img->rectangle(
        x => $x * $PROT_SIZE_X + $PROT_SHIFT_X, 
        y => $y * $PROT_SIZE_Y + $PROT_SHIFT_Y, 
        width => $length * $PROT_SIZE_X, 
        height => $PROT_SIZE_Y,
        'stroke' => 'black',
        'stroke-width' => 1,
        'fill' => 'rgb('.(join ",", @{$prot_box_cfg[$y]}) . ")",
    );

    my $txt = $img->text(
        x => ($x + $length/2) * $PROT_SIZE_X + $PROT_SHIFT_X, 
        y => ($y + .5) * $PROT_SIZE_Y + $FONT_SIZE / 2 + $PROT_SHIFT_Y,
        style=>"font-family: Arial; font-size: ${FONT_SIZE}px; text-anchor: middle",
    )->cdata($caption);
}

# Make a filtering function arrow.
# $x: location
# $level: how many protocol levels are filtered
# $caption: string describing the function
sub make_function_arrow {
    my ($self, $arrow) = @_;
    my $img = $self->_svg;
    my ($x, $level, $caption, $r_icons) = @$arrow{qw/arrow_x arrow_height arrow_service arrow_icons/};
    my $end_x = $x * $PROT_SIZE_X + $PROT_SHIFT_X;
    my $end_y = ($self->max_prot_level + 1) * $PROT_SIZE_Y + $PROT_SHIFT_Y;

    $img->line(
        x1 => $end_x, y1 =>($self->max_prot_level - $level) * $PROT_SIZE_Y + $PROT_SHIFT_Y,
        x2 => $end_x, y2 => $end_y,
        stroke => 'black',
        'stroke-width' => 4,
        'stroke-linecap' => 'round',
        fill=> 'white',
        style => "marker-end: url(#triangleMarker);",
    );

    $img->text(
        x => $end_x - 18,
        y => $end_y + 5,
        style=>"font-family: Arial; font-size: ${FONT_SIZE}px; text-anchor: end;",
        transform => "rotate(-90,".$end_x.",".$end_y.")",
    )->cdata($caption);
}




# Draw the icons of a function arrow
sub _make_function_arrow_icons {
    my ($self, $arrow) = @_;
    my $img = $self->_img_magick;
    my ($x, $level, $caption, $r_icons) = @$arrow{qw/arrow_x arrow_height arrow_service arrow_icons/};

    my $end_x = $x * $PROT_SIZE_X + $PROT_SHIFT_X;

    # draw icons
    foreach my $i (@$r_icons) {
        my ($level, $filename) = @$i;
        my $icon = Image::Magick->new;
        my $r = $icon->Read($filename);
        die "$filename: $r\n" if $r;
        my ($icon_x, $icon_y) = $icon->Get('width', 'height');
        my $ratio = $icon_x / $icon_y;
        $icon->Resize(height => $PROT_SIZE_Y, width => $PROT_SIZE_Y * $ratio);
        $img->Composite(
            image=>$icon, 
            x=> $end_x - $PROT_SIZE_Y * $ratio / 2,
            y=> ($self->max_prot_level - $level) * $PROT_SIZE_Y + $PROT_SHIFT_Y
        );
    }
}


# Make an arrow with a number in it at specified position
# (x,y) is the tip of the arrow, which points to the left
# like this, only vectorised:
#  /|__
# <  __|
#  \|
sub _draw_arrow {
    my ($self, $x, $y, $color) = @_;
    my $img = $self->_svg;

    my @x = map { $_ + $x } (0, 10, 10, 25, 25,10, 10, 0);
    my @y = map { $_ + $y } (0,-20,-10,-10, 10,10, 20, 0);

    my $points = $img->get_path(
        x => \@x,
        y => \@y,
        -type => 'path',
        -closed => 'true',
    );

    my $shape = $img->path(
        %$points,
        style=>"fill: $color; stroke: black; stroke-width: 1",
    );

    return $shape;
}

# Make a caption arrow
# $x, $y: box location
# $orient: 'r' or 'l' depending on where it's going
# $sf: 0-4: changes the colour of the arrow depending on # SAL
# $caption: 0-9: reference printed in the arrow
sub make_security_function_arrow {
    my ($self, $arrow) = @_;
    my $img = $self->_svg;
    my ($x, $y, $orient, $color, $caption) = @$arrow{qw/sf_x sf_y sf_orient sf_level sf_caption/};
    my $step = 9;
    my $pt_x = $x * $PROT_SIZE_X + $PROT_SHIFT_X + $step;
    my $pt_y = $y * $PROT_SIZE_Y + $PROT_SIZE_Y / 2 + $PROT_SHIFT_Y;

    if ($orient eq 'r') {
        $pt_x = ($x + 1) * $PROT_SIZE_X + $PROT_SHIFT_X - $step;
    }

    $color = $sf_color_cfg[$color];
    my $shape = $self->_draw_arrow($pt_x, $pt_y, $color);

    if ($orient eq 'r') {
        $shape->setAttribute('transform', "rotate(180,$pt_x,$pt_y)");
    }

    $img->text(
        x=>$pt_x + ($orient eq 'r' ? -12 : + 12),
        y=>$pt_y + 5,
        style=>"font-family: Arial; font-size: ${FONT_SIZE}px; text-anchor: middle",
    )->cdata($caption);
}

# Make a system box that goes in the background (must draw
# first)
# $x1, $x2: where does the box start and end
# $caption: system name
sub make_system_box {
    my ($self, $box) = @_;
    my $img = $self->_svg;
    my ($x1, $x2, $caption) = @$box{qw/ box_start box_end box_name /};
    my $yd = $FONT_SIZE;

    $img->rectangle(
x => $x1 * $PROT_SIZE_X + $PROT_SHIFT_X - $PROT_SIZE_X * .33,
y => $PROT_SHIFT_Y - 2 * $yd,
        width => ($x2 - $x1 + .66 ) * $PROT_SIZE_X,
        height => $self->max_prot_level * $PROT_SIZE_Y + $PROT_SHIFT_Y + $PROT_SIZE_Y * .5,
        'stroke' => 'black',
        'stroke-width' => 1,
        'fill' => 'rgb('.(join ",", @system_box_cfg) . ")",
    );

    my $txt = $img->text(
        x => $x1 * $PROT_SIZE_X + $PROT_SHIFT_X - $PROT_SIZE_X * .33 + 5,
        y =>  $PROT_SHIFT_Y - $yd,
        style=>"font-family: Arial; font-size  : ${FONT_SIZE}px;"
    )->cdata($caption);
}

sub add_icons {
    my ($self, @function_arrows) = @_;
    my $img = $self->_svg;

    warn "adding icons\n" if $self->verbose;

    foreach my $arrow (@function_arrows) {
        my ($x, $level, $caption, $r_icons) = 
            @$arrow{qw/arrow_x arrow_height arrow_service arrow_icons/};

        my $end_x = $x * $PROT_SIZE_X + $PROT_SHIFT_X;

        foreach my $i (@$r_icons) {
            my ($level, $filename) = @$i;
            my $ratio = 1;
            local ($/) = undef;
            open my $file, $filename or die "$filename: $!\n";
            my $contents = encode_base64(<$file>);
            $img->image(
                -href => "data:image/png;base64,$contents", 
                x=> $end_x - $PROT_SIZE_Y * $ratio / 2,
                y=> ($self->max_prot_level - $level) * $PROT_SIZE_Y + $PROT_SHIFT_Y,
                width => $PROT_SIZE_Y * $ratio,
                height => $PROT_SIZE_Y,
            );
        }
    }

}


sub save {
    my ($self, $filename) = @_;
    my $svg = $self->_svg;
    warn "saving to $filename\n" if $self->verbose;
    open my $f, "> $filename" or die "$filename: $!\n";
    my $xml = $svg->xmlify();
    print $f $xml;
}

# Initialises out
# $prot: ref to of protocol box list
# $functions: ref to function arrow list
# $systems: ref to system box list
# $cfg: ref to configuration hash
sub init_out {
    my ($self, $prot, $functions, $systems, $cfg) = @_;
    my ($max_x, $max_y);

    $self->_load_cfg($cfg);


    warn "creating image...\n" if $self->verbose;

    my $svg = SVG->new();

    $self->_svg($svg);

    $svg->comment(<<EOF);
Generated by dtc by Yves Rűtschlé: https://github.com/yrutschle/dtc
EOF

    $svg->marker( 
        id => 'triangleMarker',
        markerWidth=>8,
        markerHeight=>8,
        refX=>0, 
        refY=>4,
        orient => 'auto'
    )-> path(
        d=> "M0,0 L0,8 L4,4 L0,0",
        style => "fill: #000000;"
    );
}

1;

