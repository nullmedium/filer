
install:
	install -d /usr/lib/filer
	install -d /usr/lib/filer/icons
	install -d /usr/lib/filer/icons/mimetypes
	install -d /usr/lib/filer/Filer
	install -m 644 ./Filer/*.pm /usr/lib/filer/Filer
	install -m 644 ./icons/*.png /usr/lib/filer/icons
	install -m 644 ./icons/mimetypes/*.png /usr/lib/filer/icons/mimetypes
	install -m 755 filer.pl /usr/bin/filer
	install -m 644 lib.pl /usr/lib/filer

uninstall:
	rm -rf /usr/lib/filer
	rm -rf /usr/bin/filer
