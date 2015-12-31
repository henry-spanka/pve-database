include ../defines.mk

SUBDIRS = init.d

SCRIPTS =			\
	pvedatabased

MANS = 				\
	pvedatabased.1

all: ${MANS}

%.1: %.1.pod
	rm -f $@
	cat $<|pod2man -n $* -s 1 -r ${VERSION} -c "Proxmox Documentation" >$@

%.1.pod: %
	podselect $*>$@

.PHONY: install 
install: ${SCRIPTS} ${MANS}
	install -d ${BINDIR}
	install -m 0755 ${SCRIPTS} ${BINDIR}
	install -d ${MAN1DIR}
	install -m 0644 ${MANS} ${MAN1DIR}
	install -d ${PODDIR}
	set -e && for i in ${SUBDIRS}; do ${MAKE} -C $$i $@; done

.PHONY: distclean
distclean: clean
	set -e && for i in ${SUBDIRS}; do ${MAKE} -C $$i $@; done

.PHONY: clean
clean:
	rm -rf *~ ${MANS} *.1.pod
	set -e && for i in ${SUBDIRS}; do ${MAKE} -C $$i $@; done
