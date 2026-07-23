#!/usr/bin/perl

use strict;
use warnings;
use Module::Build;

use lib './lib';
use Net::ISP::Balance;

my $class = Module::Build->subclass(code=><<'EOF');

use File::Find 'find';
use File::Basename 'basename';
use lib './lib';
use Net::ISP::Balance;

sub ACTION_clean {
    my $self = shift;
    my $dir  = $self->base_dir();
    system "cd lsm; make -s clean; cd $dir";
    $self->SUPER::ACTION_clean();
}


sub ACTION_install {
    my $self = shift;
    my $dir  = $self->base_dir();
    $self->SUPER::ACTION_install();
    
    my $destdir = $self->destdir || $ENV{DESTDIR} || '';
    
    mkdir "$destdir/var/lib/lsm";
    my $path = $self->install_destination('script');
    my $install_etc = Net::ISP::Balance->install_etc;
    
    system "mkdir -p $destdir$install_etc";
    system "cp etc/balance.conf $destdir$install_etc/";
    system "cp -a etc/balance $destdir$install_etc/";
    
    chmod 0755, glob("$destdir$install_etc/balance/firewall/*");
    chmod 0755, glob("$destdir$install_etc/balance/routes/*");
    chmod 0755, glob("$destdir$install_etc/balance/pre-run/*");
    chmod 0755, glob("$destdir$install_etc/balance/post-run/*");

    system "ln -sf $path/load_balance.pl $destdir/etc/load_balance.pl" unless $destdir;
}

sub process_lsm_files {
     my $self = shift;
     my $dir  = $self->base_dir();
     $self->SUPER::ACTION_build();
     chomp(my $make  = `which make 2>/dev/null`);
     chomp(my $nmake = `which nmake 2>/dev/null`);
     $make ||= $nmake;
     system "cd lsm; $make install; cd $dir";
}

sub process_etc_files {
    my $self = shift;
    find({no_chdir=>1,
	  wanted => sub { return unless -f $File::Find::name;
			  my $bn = basename($_);
			  return if $bn =~ /~$/ || $bn =~ /^#/;
			  (my $strip = $File::Find::name) =~ s!^\./etc/!!;
			  my $install_etc = Net::ISP::Balance->install_etc;
			  if (-e "$install_etc/$strip") {
			      print STDERR "skip $install_etc/$strip: already installed\n";
			      unlink "./blib/$File::Find::name";
			      return;
			  }
			  $self->copy_if_modified(from => $File::Find::name,
						  to_dir => './blib');
	  }},
	 './etc'
	);
}

EOF

my $build = $class->new(
    module_name       => 'Net::ISP::Balance',
    license           => 'perl',
    dist_version_from => 'lib/Net/ISP/Balance.pm',
    dist_abstract     => 'Load balance among two or more ISP connections',
    dist_author       => 'Lincoln Stein <lincoln.stein@gmail.com>',
    configure_requires => { 'Module::Build' => 0 },
    requires          => {
	'perl'        => '5.8.0',
        'Net::Netmask'  => 0,
        'Net::Subnet' => 0,
        'Pod::Usage'    => 0,
        'DB_File'       => 0,
       },
    );

my $install_etc = Net::ISP::Balance->install_etc;
$build->add_build_element('etc');
$build->add_build_element('lsm');
$build->install_path('etc'       => $install_etc);
$build->config_data('lsm_path'=>$build->install_destination('script').'/foolsm');
$build->create_build_script;
exit 0;
