# System-wide install / Debian package for Tsunyx Launcher (the original,
# fullscreen variant only) and Tsunyx Search (panel search box).
# install.sh remains the per-user dev install.
NAME    := tsunyx-launcher
VERSION := 1.13.3
PREFIX  ?= /usr
DESTDIR ?=

PLASMOIDS    := local.tsunyxlauncher local.tsunyxsearch
PLASMOID_DIR := $(PREFIX)/share/plasma/plasmoids
MO_DIR       := $(PREFIX)/share/locale/es/LC_MESSAGES
SCRIPT_ID    := tsunyxlauncherskiptaskbar
SCRIPT_DIR   := $(PREFIX)/share/kwin-wayland/scripts/$(SCRIPT_ID)

BUILD := build
DEB   := $(BUILD)/$(NAME)_$(VERSION)_all.deb

.PHONY: all install uninstall deb clean

all:
	@echo "Targets: install, uninstall, deb, clean"

install:
	install -d $(DESTDIR)$(MO_DIR)
	for p in $(PLASMOIDS); do \
		(cd $$p && find . -type f ! -name '*.po' -exec install -Dm644 {} $(DESTDIR)$(PLASMOID_DIR)/$$p/{} \;) && \
		msgfmt $$p/contents/locale/es/LC_MESSAGES/plasma_applet_$$p.po -o $(DESTDIR)$(MO_DIR)/plasma_applet_$$p.mo || exit 1; \
	done
	install -Dm644 kwin-script-skip-taskbar/metadata.json $(DESTDIR)$(SCRIPT_DIR)/metadata.json
	install -Dm644 kwin-script-skip-taskbar/contents/code/main.js $(DESTDIR)$(SCRIPT_DIR)/contents/code/main.js

uninstall:
	for p in $(PLASMOIDS); do rm -rf $(DESTDIR)$(PLASMOID_DIR)/$$p; rm -f $(DESTDIR)$(MO_DIR)/plasma_applet_$$p.mo; done
	rm -rf $(DESTDIR)$(SCRIPT_DIR)

deb: clean
	$(MAKE) install DESTDIR=$(CURDIR)/$(BUILD)/root PREFIX=/usr
	install -Dm644 debian/control $(BUILD)/root/DEBIAN/control
	sed -i 's/@VERSION@/$(VERSION)/' $(BUILD)/root/DEBIAN/control
	install -Dm644 debian/copyright $(BUILD)/root/usr/share/doc/$(NAME)/copyright
	dpkg-deb --root-owner-group --build $(BUILD)/root $(DEB)

clean:
	rm -rf $(BUILD)
