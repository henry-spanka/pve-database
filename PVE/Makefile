include ../defines.mk

SUBDIRS=API2

PERLSOURCE = 			\
	Database.pm

.PHONY: distclean
distclean: clean
	set -e && for i in ${SUBDIRS}; do ${MAKE} -C $$i $@; done

.PHONY: clean
clean:
	set -e && for i in ${SUBDIRS}; do ${MAKE} -C $$i $@; done

.PHONY: install 
install: ${PERLSOURCE}
	install -d ${PERLLIBDIR}/PVE
	install -m 0644 ${PERLSOURCE} ${PERLLIBDIR}/PVE/
	set -e && for i in ${SUBDIRS}; do ${MAKE} -C $$i $@; done
