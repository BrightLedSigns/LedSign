package LedSign::Image;
use 5.008001;
use strict;
use Carp;

use constant default_color_to_character => {
    'black'         => ' ',
    'clear'         => ' ',
    '#000000'       => ' ',
    '#000000000000' => ' ',
    other           => '*',
};

sub new {
    my ( $class, %param ) = @_;

    if ( ref $class ) {

        # clone by copying fields and data array
        my $self = bless {%$class}, $class;
        $self->{'-rows_array'} = [ @{ $class->{'-rows_array'} } ];
        return $self;
    }

    my $self = bless {
        -rows_array         => [],
        -width              => 0,
        -color_to_character => $class->default_color_to_character,
    }, $class;

    if ( defined( my $filename = delete $param{'-file'} ) ) {
        $self->load($filename);
    }
    $self->set(%param);
    return $self;
}

sub get {
    my ( $self, $key ) = @_;
    if ( $key eq '-height' ) {
        return scalar @{ $self->{'-rows_array'} };
    }
    return $self->SUPER::_get($key);
}

sub set {
    my ( $self, %param ) = @_;
    ### set(): \%param

    if ( defined( my $width = delete $param{'-width'} ) ) {
        foreach my $row ( @{ $self->{'-rows_array'} } ) {
            if ( length($row) < $width ) {
                $row .= ' ' x ( $width - length($row) );
            }
            else {
                substr( $row, $width ) = '';
            }
        }

        # ready for -height to use
        $self->{'-width'} = $width;
    }

    if ( defined( my $height = delete $param{'-height'} ) ) {
        my $rows_array = $self->{'-rows_array'};
        if ( @$rows_array >= $height ) {
            ### rows_array shorten
            splice @$rows_array, $height;
        }
        else {
            ### rows_array extend by: ($height - scalar(@$rows_array))
            my $row = ' ' x $self->{'-width'};
            push @$rows_array, ($row) x ( $height - scalar(@$rows_array) );
        }
    }

    %$self = ( %$self, %param );
}

sub load {
    my ( $self, $filename ) = @_;
    ### Image-Base-Text load()
    if ( @_ == 1 ) {
        $filename = $self->get('-file');
    }
    else {
        $self->set( '-file', $filename );
    }
    ### $filename

    open my $fh, '<', $filename or croak "Cannot open $filename: $!";
    $self->load_fh($fh);
    close $fh or croak "Error closing $filename: $!";
}

sub load_string {
    my ( $self, $str ) = @_;
    ### Image-Base-Text load_string(): $str
    # split
    my @lines = split /\n/, $str, -1;
    if ( @lines && $lines[-1] eq '' ) {

        # drop the empty element after the last newline, but keep a non-empty
        # final element from chars without a final newline
        pop @lines;
    }
    $self->load_lines(@lines);
}

sub load_lines {
    my ( $self, @rows_array ) = @_;
    ### load_lines: @rows_array

    my $width = 0;
    foreach my $row (@rows_array) {
        if ( $width < length($row) ) {
            $width = length($row);
        }
    }

    $self->{'-rows_array'} = \@rows_array;
    $self->set( -width => $width );    # pad out shorter lines
}

sub save {
    my ( $self, $filename ) = @_;
    ### Image-Base-Text save(): @_
    if ( @_ == 2 ) {
        $self->set( '-file', $filename );
    }
    else {
        $filename = $self->get('-file');
    }
    ### $filename
    my $fh;
    ( open $fh, '>', $filename and $self->save_fh($fh) and close $fh )
      or croak "Error writing $filename: $!";
}

# these undocumented yet ...
sub save_fh {
    my ( $self, $fh ) = @_;
    my $rows_array = $self->{'-rows_array'};
    local $, = "\n";
    return print $fh @$rows_array, ( @$rows_array ? '' : () );
}

sub save_string {
    my ($self) = @_;
    my $rows_array = $self->{'-rows_array'};
    return join( "\n", @$rows_array, ( @$rows_array ? '' : () ) );
}

#------------------------------------------------------------------------------
# drawing

sub xy {
    my ( $self, $x, $y, $color ) = @_;

    # clip to width,height
    return
      if ( $x < 0
        || $x >= $self->{'-width'}
        || $y < 0
        || $y >= @{ $self->{'-rows_array'} } );

    my $rows_array = $self->{'-rows_array'};
    if ( @_ == 3 ) {
        return $self->character_to_color( substr( $rows_array->[$y], $x, 1 ) );
    }
    else {
        substr( $rows_array->[$y], $x, 1 ) = $self->color_to_character($color);
    }
}

sub color_to_character {
    my ( $self, $color ) = @_;
    if ( defined( my $char = $self->{'-color_to_character'}->{$color} ) ) {
        return $char;
    }
    if ( length($color) == 1 ) {
        return $color;
    }
    if ( defined( my $char = $self->{'-color_to_character'}->{'other'} ) ) {
        return $char;
    }
    croak "Unknown color: $color";
}

sub character_to_color {
    my ( $self, $char ) = @_;
    if ( length($char) == 0 ) {
        return undef;
    }
    if ( defined( my $color = $self->{'-character_to_color'}->{$char} ) ) {
        return $color;
    }
    return $char;
}
1;
