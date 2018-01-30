package OutGD;

# This file is the output driver for bitmap graphics for dtc.

use Moose;
use GD::Simple;
use Convert::Color;

has verbose => (is => 'rw');
has max_prot_level => (is => 'ro', required => 1);

# Reference to the GD object
has _img => (is => 'rw');

# Reference to the ImageMagick object
# (this is a bit ugly; you can't call any GD-based method after having called a
# ImMagick method)
has _img_magick => (is => 'rw');

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
# Palette operations
# Refer to
# http://demosthenes.info/blog/576/Three-Ways-You-Should-Be-Using-HSL-Color-In-Your-Site-Today
# to understand the idea behind these

# Given a Convert::Color::HSL, return the specified palette of related
# monochromatic variants (in HSL)
sub create_monochrome_palette {
    my ($num, $color) = @_;

    my ($h, $s, $l) = $color->hsl;

    my @out;
    foreach my $i (0 .. $num - 1) {
         my $s1 =  $i / $num;
         my $color = Convert::Color->new("hsv:$h,$s1,$l");
         push @out, $color;
    }
    return @out;
}

# Creates a palette with hues around given color
# $num: How many colors in the palette
# $range: angle around the reference
# $color: reference color
# Hues will for from $reference - $range / 2 to $reference + $range / 2
# so range of 360 creates a color scheme across the entire circle
sub create_neutral_palette {
    my ($num, $range, $color) = @_;

    my ($h, $s, $l) = $color->hsl;

    my @out;
    foreach my $i (0 .. $num - 1) {
         my $h1 = ($h - $range + 2 * ($range/2) * ($i-1) / $num) % 360;
         my $color = Convert::Color->new("hsl:$h1,$s,$l");
         push @out, $color;
    }
    return @out;
}

sub opposite_color {
    my ($color) = @_;

    my ($h, $s, $v) = $color->hsl;

    return Convert::Color->new("hsl:".($h+180).",$s,$v");
}

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
    $FONT_SIZE = _val($cfg, 'font_size', 8);

    $no_sf_cfg = _val($cfg, 'no_sf', '192,192,192');

    # Pick one: http://hslpicker.com/

    if (exists $cfg->{'base_color'}) {
        my $base_color_str = _val($cfg, 'base_color', 'hsl:314,0.8,0.65');
        my $base_color = Convert::Color->new($base_color_str);
        my ($arrow_base, $prot_base ,$system_base) = create_neutral_palette(3, 180, $base_color);
        @prot_box_cfg = map { [ $_->as_rgb8->rgb8 ] } create_monochrome_palette($self->max_prot_level, $prot_base);
        @sf_color_cfg = map { [ $_->as_rgb8->rgb8 ] } create_neutral_palette(5, 180, $arrow_base);
        @system_box_cfg = $system_base->as_rgb8->rgb8;
    } else {
        # Default, boring color scheme
        my $rgb = Convert::Color->new("rgb8:213,184,127");
        for ( 0 .. $self->max_prot_level - 1 ) {
            push @prot_box_cfg, $rgb;
        }
        @sf_color_cfg = (
            Convert::Color->new("rgb8:57,142,19"),
            Convert::Color->new("rgb8:88,221,28"),
            Convert::Color->new("rgb8:250,245,0"),
            Convert::Color->new("rgb8:244,167,28"),
            Convert::Color->new("rgb8:221,29,29")
        );
        $rgb = Convert::Color->new("rgb8:200,200,200");
        @system_box_cfg = $rgb->rgb8;
    }
}

sub make_prot_box {
    my ($self, $box) = @_;
    my $img = $self->_img;
    my ($x, $y, $length, $caption) = @$box{qw/box_x box_y box_len box_label/};
    return if $caption eq 'void';

    $img->bgcolor($img->colorAllocate(@{$prot_box_cfg[$y]}));

    $img->rectangle($x * $PROT_SIZE_X + $PROT_SHIFT_X, $y * $PROT_SIZE_Y + $PROT_SHIFT_Y, 
                   ($x + $length) * $PROT_SIZE_X + $PROT_SHIFT_X, ($y + 1 ) * $PROT_SIZE_Y + $PROT_SHIFT_Y);
    my ($xd, $yd) = $img->stringBounds($caption);
    $img->moveTo(($x + $length/2) * $PROT_SIZE_X - $xd / 2 + $PROT_SHIFT_X, 
                 ($y + .5) * $PROT_SIZE_Y + $yd / 2 + $PROT_SHIFT_Y);
    $img->string($caption);
}

# Make a filtering function arrow.
# $x: location
# $level: how many protocol levels are filtered
# $caption: string describing the function
sub make_function_arrow {
    my ($self, $arrow) = @_;
    my $img = $self->_img;
    my ($x, $level, $caption, $r_icons) = @$arrow{qw/arrow_x arrow_height arrow_service arrow_icons/};
    my $end_x = $x * $PROT_SIZE_X + $PROT_SHIFT_X;
    my $end_y = ($self->max_prot_level + 1) * $PROT_SIZE_Y + $PROT_SHIFT_Y;
    $img->moveTo($end_x, ($self->max_prot_level - $level) * $PROT_SIZE_Y + $PROT_SHIFT_Y);
    $img->penSize(3,3);
    $img->angle(90); # down
    $img->lineTo($end_x, $end_y);
    $img->penSize(1,1);
    $img->angle(0);

    # draw arrow end
    my $poly = new GD::Polygon;
    $poly->addPt($end_x - 5, $end_y);
    $poly->addPt($end_x + 5, $end_y);
    $poly->addPt($end_x, $end_y + 5);
    $img->bgcolor('black');
    $img->polygon($poly);

    # draw description
    my ($xd, $yd) = $img->stringBounds($caption);
    $img->moveTo($end_x + $yd / 2, $end_y + $xd + 15);
    $img->angle(-90);
    $img->string($caption);
}




# Draw the icons of a function arrow
# This uses ImageMagick because GD doesn't handle transparency all that well,
# so this needs to be called after the GD image has been saved.
# Caveat: $img now points to an Image::Magick object!
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


# Make just an arrow
# Position the cursor and orientation before calling
sub _draw_arrow {
    my ($self, $step) = @_;
    my $img = $self->_img;

    # Each step is one turn (in degree) followed by a distance.
    my @steps = (
        [ -60,  1.932 * $step], 
        [ 150, $step],
        [ -90, $step],
        [ 90, 1.550 * $step],
        [ 90, $step ],
        [ -90, $step ],
        [ 150, 1.932 * $step], 
        [ 30, 1 ],
    );

    foreach (@steps) {
        $img->turn($$_[0]);
        $img->line($$_[1]);
    }

}

# Make a caption arrow
# $x, $y: box location
# $orient: 'r' or 'l' depending on where it's going
# $sf: 0-4: changes the colour of the arrow depending on # SAL
# $caption: 0-9: reference printed in the arrow
sub make_security_function_arrow {
    my ($self, $arrow) = @_;
    my $img = $self->_img;
    my ($x, $y, $orient, $colour, $caption) = @$arrow{qw/sf_x sf_y sf_orient sf_level sf_caption/};
    my $step = 9;
    my $pt_x = $x * $PROT_SIZE_X + $PROT_SHIFT_X + $step;
    my $pt_y = $y * $PROT_SIZE_Y + $PROT_SIZE_Y / 2 + $PROT_SHIFT_Y;

    # Create colours from configuration
    my @sf_colour = map { $img->colorAllocate(@$_ ) } @sf_color_cfg;
    my $no_sf = $img->colorAllocate(split ',', $no_sf_cfg);

    if ($orient eq 'r') {
        $pt_x = ($x + 1) * $PROT_SIZE_X + $PROT_SHIFT_X - $step;
    }

    $img->angle($orient eq 'r' ? 180 : 0);
    $img->moveTo($pt_x, $pt_y);
    $self->_draw_arrow($step);
    $img->fill($pt_x + ($orient eq 'r' ? -5:+5), $pt_y, $colour =~ /\d+/ ? $sf_colour[$colour] : $no_sf);

    # print reference inside arrow
    $img->angle(0);
    my ($xd, $yd) = $img->stringBounds($caption);
    if ($orient eq 'r') {
        $img->moveTo($pt_x - $step - $xd/2, $pt_y + $yd / 2 - 1);
    } else {
        $img->moveTo($pt_x + $step, $pt_y + $yd / 2);
    }
    $img->string($caption);
}

# Make a system box that goes in the background (must draw
# first)
# $x1, $x2: where does the box start and end
# $caption: system name
sub make_system_box {
    my ($self, $box) = @_;
    my $img = $self->_img;
    my ($x1, $x2, $caption) = @$box{qw/ box_start box_end box_name /};
    my ($xd, $yd) = $img->stringBounds($caption);

    $img->bgcolor($img->colorAllocate(@system_box_cfg));
    $img->rectangle(
        $x1 * $PROT_SIZE_X + $PROT_SHIFT_X - $PROT_SIZE_X * .33, $PROT_SHIFT_Y - 2 * $yd,
        $x2 * $PROT_SIZE_X + $PROT_SHIFT_X + $PROT_SIZE_X * .33, $self->max_prot_level * $PROT_SIZE_Y + $PROT_SHIFT_Y + $PROT_SIZE_Y * .5
    );

    $img->moveTo( $x1 * $PROT_SIZE_X + $PROT_SHIFT_X - $PROT_SIZE_X * .33 + 5,  $PROT_SHIFT_Y - $yd);
    $img->string($caption);
}

sub add_icons {
    my ($self, @function_arrows) = @_;
    my $img = $self->_img;

    warn "adding icons\n" if $self->verbose;

    my $tmp_filename = "/tmp/dtc_$$.png";
    open my $out, "> $tmp_filename" or die $!;
    print $out $img->png;
    close $out;

# Add icons using Image::Magick
    use Image::Magick;
    $img = Image::Magick->new;
    $img->Read($tmp_filename);
    $self->_img_magick($img);
    unlink $tmp_filename;
    foreach my $arrow (@function_arrows) {
        $self->_make_function_arrow_icons($arrow);
    }

    # to be clean, we should reload the image in a GD object. As it is, you
    # can't call any drawing method after this one.
}


# And this works on the ImageMagick object...
sub save {
    my ($self, $filename) = @_;
    my $img = $self->_img_magick;
    warn "saving to $filename\n" if $self->verbose;
    my $r = $img->Write($filename);
    warn "$r\n" if $r;
}

# Initialises out
# $prot: ref to of protocol box list
# $functions: ref to function arrow list
# $systems: ref to system box list
# $cfg: ref to configuration hash
sub init_out {
    my ($self, $prot, $functions, $systems, $cfg) = @_;
    my ($max_x, $max_y);
    my $img = $self->_img;

    $self->_load_cfg($cfg);

    my @function_arrows = @$functions;

# Find X size: depends on the number of protocol columns
    $max_x = ( scalar @$prot + .40) * $PROT_SIZE_X + $PROT_SHIFT_X;
    warn "max_x: $max_x\n" if $self->verbose;

# Find Y size (depends on the number of protocols and
# function arrow caption length)
    {
        my $max_caption_length = 0;
        foreach (@function_arrows) {
            my $tmpimg = GD::Simple->new(1024,1024);
            $tmpimg->font($FONT);
            $tmpimg->fontsize($FONT_SIZE);
            my ($xd, $yd) = $tmpimg->stringBounds($_->{arrow_service});
            if ($max_caption_length < $xd) {
                $max_caption_length = $xd;
            }
            undef $tmpimg;
        }
        $max_y = ($self->max_prot_level + 1) * $PROT_SIZE_Y + $PROT_SHIFT_Y + $max_caption_length + 20;
    }

    warn "max_y: $max_y\n" if $self->verbose;

    warn "creating image...\n" if $self->verbose;

    $img = GD::Simple->new($max_x, $max_y);
    $img->font($FONT);
    $img->fontsize($FONT_SIZE);

    $self->_img($img);
}

1;

