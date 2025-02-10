#!/usr/bin/perl
use strict;
use warnings;

# Define directories
my $exp_dir = '/home/jsp/SnPbTe_alloys/QE_from_MatCld/cifs_exp';
my $theory_dir = '/home/jsp/SnPbTe_alloys/QE_from_MatCld/cifs_theory';
my $initial_dir = '/home/jsp/SnPbTe_alloys/dp_train_new/initial';

# 1. Get all CIF files in cifs_exp, remove extensions, and place prefixes in @exp array
my @exp = get_cif_prefixes($exp_dir);

# 2. Get CIF files in cifs_theory with both Sn and Pb in prefix, remove extensions, and place prefixes in @theory array
our @notrequired = ('Te');#elements not required in prefix

my @theory = get_cif_prefixes($theory_dir, 'Sn', 'Pb');
#print "@theory\n";
#die;
# 3. Keep folders in initial directory with patterns in @exp or @theory, as well as those without "mp-xxxx"
filter_initial_folders($initial_dir, \@exp, \@theory);

sub get_cif_prefixes {
    my ($dir, @required_terms) = @_;
    opendir(my $dh, $dir) or die "Could not open directory '$dir': $!";
    my @prefixes;

    while (my $file = readdir($dh)) {
        next unless $file =~ /\.cif$/;
        my ($prefix) = $file =~ /^(.*)\.cif$/;
        
        if (@required_terms) {
            my $match = 1;
            for my $term (@required_terms) {
                unless ($prefix =~ /$term/) {
                    $match = 0;
                    last;
                }
            }
            next unless $match;

            for my $nr (@notrequired) {
                if ($prefix =~ /$nr/) {
                    $match = 0;
                    last;
                }
            }
            next unless $match;
        }

        push @prefixes, $prefix;
    }

    closedir($dh);
    return @prefixes;
}

sub filter_initial_folders {
    my ($dir, $exp_ref, $theory_ref) = @_;
    my %valid_prefixes = map { $_ => 1 } (@$exp_ref, @$theory_ref);

    opendir(my $dh, $dir) or die "Could not open directory '$dir': $!";
    my @folders = readdir($dh);
    my $count = 0;
    foreach my $folder (@folders) {
        chomp $folder;
        next unless -d "$dir/$folder";
        next if $folder =~ /^\./;  # Skip . and .. directories
        $count++;
        print "folder $count: $folder\n";
        my $keep = 0;
        foreach my $prefix (keys %valid_prefixes) {
            if ($folder =~ /$prefix/ || $folder !~ /mp-\d+/) {
                $keep = 1;
                last;
            }
        }

        unless ($keep) {
            system("rm -rf '$dir/$folder'");
            print "Removed folder: $dir/$folder\n";
        }
    }

    closedir($dh);
}
