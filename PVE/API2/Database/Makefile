include ../../../defines.mk

PERLSOURCE = 			\
	VM.pm			\
	Host.pm

SUBDIRS=Network Disk

.PHONY: distclean
distclean: clean

.PHONY: clean
clean:
	rm -rf *~
	set -e && for i in ${SUBDIRS}; do ${MAKE} -C $$i $@; done

.PHONY: install 
install: ${PERLSOURCE}
	install -d ${PERLLIBDIR}/PVE/API2/Database
	install -m 0644 ${PERLSOURCE} ${PERLLIBDIR}/PVE/API2/Database
	set -e && for i in ${SUBDIRS}; do ${MAKE} -C $$i $@; done
