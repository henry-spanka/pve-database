include ../../../../defines.mk

PERLSOURCE = 			\
	CT.pm		\
	VM.pm		\
	Host.pm

.PHONY: distclean
distclean: clean

.PHONY: clean
clean:
	rm -rf *~

.PHONY: install 
install: ${PERLSOURCE}
	install -d ${PERLLIBDIR}/PVE/API2/Database/Network
	install -m 0644 ${PERLSOURCE} ${PERLLIBDIR}/PVE/API2/Database/Network
