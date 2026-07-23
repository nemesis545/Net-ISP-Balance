# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DIST_AUTHOR=LSTEIN
DIST_VERSION=1.33
inherit perl-module toolchain-funcs

DESCRIPTION="Load balance among two or more ISP connections"
HOMEPAGE="https://github.com/lstein/Net-ISP-Balance"
SRC_URI="https://github.com/lstein/Net-ISP-Balance/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="Artistic-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

RDEPEND="
	dev-perl/Net-Netmask
	dev-perl/Net-Subnet
	virtual/perl-DB_File
	sys-apps/iproute2
	net-firewall/iptables
"
BDEPEND="${RDEPEND}
	dev-perl/Module-Build
"

PATCHES=( "${FILESDIR}/gentoo-fixes.patch" )

src_compile() {
	# Ensure the Makefile uses the Portage-defined compiler
	tc-export CC
	perl-module_src_compile
}

src_install() {
	# Perl module installation handles moving blib/ contents to DESTDIR
	perl-module_src_install
	perl_rm_files
	
	# Install OpenRC init script
	newinitd "${FILESDIR}"/net-isp-balance.initd net-isp-balance
	
	# Pre-create the state directory required by lsm
	keepdir /var/lib/lsm
	fowners root:root /var/lib/lsm
	fperms 0755 /var/lib/lsm
	
	# Pre-create configuration directory
	keepdir /etc/net-isp-balance
	
	dodoc README.md "${FILESDIR}"/README.Gentoo
}
