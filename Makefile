PREFIX=/usr

install:
	install -d ${PREFIX}/lib/filer
	install -d ${PREFIX}/lib/filer/icons
	install -d ${PREFIX}/lib/filer/icons/mimetypes
	install -d ${PREFIX}/lib/filer/Filer
	install -m 644 ./Filer/*.pm ${PREFIX}/lib/filer/Filer
	install -m 644 ./icons/*.png ${PREFIX}/lib/filer/icons
	install -m 644 ./icons/mimetypes/*.png ${PREFIX}/lib/filer/icons/mimetypes
	install -d ${PREFIX}/bin
	install -m 755 filer.pl ${PREFIX}/bin/filer
	install -m 644 Filer.pm ${PREFIX}/lib/filer
	install -m 644 filer.ui ${PREFIX}/lib/filer

uninstall:
	rm -rf ${PREFIX}/lib/filer
	rm -rf ${PREFIX}/bin/filer
