include defines.mk

DESTDIR=

SUBDIRS = bin PVE

ARCH=amd64
GITVERSION:=$(shell cat .git/refs/heads/master)

DEB=${PACKAGE}_${VERSION}-${PACKAGERELEASE}_${ARCH}.deb

all: ${DEB}

.PHONY: dinstall
dinstall: deb
	dpkg -i ${DEB}


.PHONY: deb
deb ${DEB}:
	make clean
	rm -rf dest
	mkdir dest
	make DESTDIR=`pwd`/dest install
	mkdir dest/DEBIAN
	sed -e s/@VERSION@/${VERSION}/ -e s/@PACKAGE@/${PACKAGE}/ -e s/@PACKAGERELEASE@/${PACKAGERELEASE}/ debian/control.in >dest/DEBIAN/control
	install -m 0644 debian/conffiles dest/DEBIAN
	install -m 0755 debian/config dest/DEBIAN
	install -m 0755 debian/postinst dest/DEBIAN
	install -m 0755 debian/postrm dest/DEBIAN
	install -m 0644 debian/triggers dest/DEBIAN
	echo "git clone https://git.myvirtualserver.de/proxmox/pve-database.git\\ngit checkout ${GITVERSION}" > dest/usr/share/doc/${PACKAGE}/SOURCE
	gzip --best dest/usr/share/man/*/*
	gzip --best dest/usr/share/doc/${PACKAGE}/changelog.Debian
	dpkg-deb --build dest
	mv dest.deb ${DEB}
	rm -rf dest
	lintian ${DEB}


.PHONY: install
install:
	install -d ${DESTDIR}/usr/share/${PACKAGE}
	install -d ${DESTDIR}/usr/share/man/man1
	install -d ${DOCDIR}
	install -m 0644 copyright ${DOCDIR}
	install -m 0644 debian/changelog.Debian ${DOCDIR}
	set -e && for i in ${SUBDIRS}; do ${MAKE} -C $$i $@; done

.PHONY: distclean
distclean: clean
	set -e && for i in ${SUBDIRS}; do ${MAKE} -C $$i $@; done

.PHONY: clean
clean:
	set -e && for i in ${SUBDIRS}; do ${MAKE} -C $$i $@; done
	find . -name '*~' -exec rm {} ';'
	rm -rf dest *.deb

.PHONY: upload
upload: ${DEB}
	umount /pve/${RELEASE}; mount /pve/${RELEASE} -o rw 
	mkdir -p /pve/${RELEASE}/extra
	rm -f /pve/${RELEASE}/extra/${PACKAGE}_*.deb
	rm -f /pve/${RELEASE}/extra/Packages*
	cp ${DEB} /pve/${RELEASE}/extra
	cd /pve/${RELEASE}/extra; dpkg-scanpackages . /dev/null > Packages; gzip -9c Packages > Packages.gz
	umount /pve/${RELEASE}; mount /pve/${RELEASE} -o ro
