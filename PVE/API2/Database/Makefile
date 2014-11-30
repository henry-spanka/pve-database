include ../../../defines.mk

PERLSOURCE = 			\
	Network.pm		\
	VM.pm

.PHONY: distclean
distclean: clean

.PHONY: clean
clean:
	rm -rf *~

.PHONY: install 
install: ${PERLSOURCE}
	install -d ${PERLLIBDIR}/PVE/API2/Database
	install -m 0644 ${PERLSOURCE} ${PERLLIBDIR}/PVE/API2/Database
