include ../../../../defines.mk

PERLSOURCE = 			\
	CT.pm		\
	VM.pm

.PHONY: distclean
distclean: clean

.PHONY: clean
clean:
	rm -rf *~

.PHONY: install 
install: ${PERLSOURCE}
	install -d ${PERLLIBDIR}/PVE/API2/Database/Disk
	install -m 0644 ${PERLSOURCE} ${PERLLIBDIR}/PVE/API2/Database/Disk
