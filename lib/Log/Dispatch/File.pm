package Log::Dispatch::File;

use strict;

use Log::Dispatch::Output;

use base qw( Log::Dispatch::Output );

use Params::Validate qw(validate SCALAR BOOLEAN);
Params::Validate::validation_options( allow_extra => 1 );

use vars qw[ $VERSION ];

$VERSION = sprintf "%d.%02d", q$Revision: 1.22 $ =~ /: (\d+)\.(\d+)/;

# Prevents death later on if IO::File can't export this constant.
BEGIN
{
    my $exists;
    eval { $exists = O_APPEND(); };

    *O_APPEND = \&APPEND unless defined $exists;
}

sub APPEND {;};

1;

sub new
{
    my $proto = shift;
    my $class = ref $proto || $proto;

    my %p = @_;

    my $self = bless {}, $class;

    $self->_basic_init(%p);
    $self->_make_handle(%p);

    return $self;
}

sub _make_handle
{
    my $self = shift;

    my %p = validate( @_, { filename  => { type => SCALAR },
			    mode      => { type => SCALAR,
					   default => '>' },
			    autoflush => { type => BOOLEAN,
					   default => 1 },
          		    close_after_write => { type => BOOLEAN,
                                                   default => 0 },
			  } );

    $self->{filename} = $p{filename};
    $self->{close} = $p{close_after_write};

    if ( $self->{close} )
    {
        $self->{mode} = '>>';
    }
    elsif ( exists $p{mode} &&
	 defined $p{mode} &&
	 ( $p{mode} =~ /^(?:>>|append)$/ ||
	   ( $p{mode} =~ /^\d+$/ &&
	     $p{mode} == O_APPEND() ) ) )
    {
	$self->{mode} = '>>';
    }
    else
    {
	$self->{mode} = '>';
    }

    $self->{autoflush} = $p{autoflush};

    $self->_open_file() unless $p{close_after_write};

}

sub _open_file
{
    my $self = shift;

    my $fh = do { local *FH; *FH; };

    open $fh, "$self->{mode}$self->{filename}"
	     or die "Can't write to '$self->{filename}': $!";

    if ( $self->{autoflush} )
    {
        my $oldfh = select $fh; $| = 1; select $oldfh;
    }

    $self->{fh} = $fh;
}

sub log_message
{
    my $self = shift;
    my %p = @_;

    my $fh;

    if ( $self->{close} )
    {
      	$self->_open_file;
	$fh = $self->{fh};
      	print $fh $p{message};

      	close $fh;
    }
    else
    {
        $fh = $self->{fh};
        print $fh $p{message};
    }
}


sub DESTROY
{
    my $self = shift;

    if ( $self->{fh} )
    {
	my $fh = $self->{fh};
	close $fh;
    }
}

__END__

=head1 NAME

Log::Dispatch::File - Object for logging to files

=head1 SYNOPSIS

  use Log::Dispatch::File;

  my $file = Log::Dispatch::File->new( name      => 'file1',
                                       min_level => 'info',
                                       filename  => 'Somefile.log',
                                       mode      => 'append' );

  $file->log( level => 'emerg', message => "I've fallen and I can't get up\n" );

=head1 DESCRIPTION

This module provides a simple object for logging to files under the
Log::Dispatch::* system.

=head1 METHODS

=over 4

=item * new(%p)

This method takes a hash of parameters.  The following options are
valid:

=item -- name ($)

The name of the object (not the filename!).  Required.

=item -- min_level ($)

The minimum logging level this object will accept.  See the
Log::Dispatch documentation for more information.  Required.

=item -- max_level ($)

The maximum logging level this obejct will accept.  See the
Log::Dispatch documentation for more information.  This is not
required.  By default the maximum is the highest possible level (which
means functionally that the object has no maximum).

=item -- filename ($)

The filename to be opened for writing.

=item -- mode ($)

The mode the file should be opened with.  Valid options are 'write',
'>', 'append', '>>', or the relevant constants from Fcntl.  The
default is 'write'.

=item -- close_after_write ($)

Whether or not the file should be closed after each write.  This
defaults to false.

If this is true, then the mode will aways be append, so that the file
is not re-written for each new message.

=item -- autoflush ($)

Whether or not the file should be autoflushed.  This defaults to true.

=item -- callbacks( \& or [ \&, \&, ... ] )

This parameter may be a single subroutine reference or an array
reference of subroutine references.  These callbacks will be called in
the order they are given and passed a hash containing the following keys:

 ( message => $log_message, level => $log_level )

The callbacks are expected to modify the message and then return a
single scalar containing that modified message.  These callbacks will
be called when either the C<log> or C<log_to> methods are called and
will only be applied to a given message once.

=item * log_message( message => $ )

Sends a message to the appropriate output.  Generally this shouldn't
be called directly but should be called through the C<log()> method
(in Log::Dispatch::Output).

=back

=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>

=cut

