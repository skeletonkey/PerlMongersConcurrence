package Jundy::Concurrent;

use warnings;
use strict;

use POSIX 'WNOHANG';

my $INSTANCE;
$SIG{CHLD} = \&reaper_of_children;

sub new {
    shift;
    return $INSTANCE || do {
        $INSTANCE = bless({
            max_children     => 0,
            unmarshall       => undef,
            verbose          => 0,
            @_,
            _children        => {},
            _child_count     => 0,
            _future_children => []
        }, __PACKAGE__);

        die("unmarshall needs to be a code reference\n") if defined $INSTANCE->{unmarshall} && ref($INSTANCE->{unmarshall}) ne 'CODE';
        die("max_children needs to be a position integer\n") if $INSTANCE->{max_children} !~ /^\d+$/;
        $INSTANCE;
    };
}

sub register {
    my $self       = shift;
    my $subroutine = shift;
    my @args       = @_;

    if ($self->{max_children} && $self->{_child_count} > $self->{max_children}) {
        push( @{$self->{_future_children}}, { subroutine => $subroutine, args => [@args] } );
    }
    else {
        my $child_pid = open(my $fh, "-|");
        die("Unable to fork using open: $!\n") unless defined $child_pid;
        if ($child_pid) {
            $self->{_child_count}++;
            $self->{_children}{$child_pid} = $fh;
        }
        else {
            &$subroutine(@args);
            exit;
        }
    }
}

sub wait {
    my $self = shift;

    while (keys %{$self->{_children}} || @{$self->{_future_children}}) {
        print 'Children still running (' . join(', ', keys %{$self->{_children}}) . ") - waiting\n" if $self->{verbose};
        sleep(2);
    }
}

sub get_data {
    my $self = shift;
    return $self->{_child_data};
}

sub reaper_of_children {
    my $self = $INSTANCE;

    while ((my $kid = waitpid(-1, WNOHANG)) > 0) {
        next unless exists $self->{_children}{$kid};
        my $fh = $self->{_children}{$kid};
        my @lines = <$fh>;
        if (defined $self->{unmarshall}) {
            eval {
                push(@{$self->{_child_data}}, &{$self->{unmarshall}}(join('', @lines)));
            } || do {
                Erik::log("unable to unmarshall data from $kid");
                Erik::log("Error: $@");
                Erik::dump(child_data => $self->{_children}{$kid});
                Erik::dump(data_returned => \@lines);
            }
        }
        else {
            push(@{$self->{_child_data}}, join('', @lines));
        }
        close($fh);
        delete $self->{_children}{$kid};

        $self->{_child_count}--;
        if (@{$self->{_future_children}}) {
            my $child = shift(@{$self->{_future_children}});
            $self->register($child->{subroutine}, @{$child->{args}});
        }
    }
}

1;
