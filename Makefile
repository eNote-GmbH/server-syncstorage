SYSTEMPYTHON = $(shell which python2 python | head -n 1)
VIRTUALENV = virtualenv --python=$(SYSTEMPYTHON)
VENV = local
VBIN = $(VENV)/bin
NOSE = $(VBIN)/nosetests -s
TESTS = syncstorage/tests
PYTHON = $(VBIN)/python
EASY_INSTALL = $(VBIN)/easy_install
PIP = $(VBIN)/pip
PIP_CACHE = /tmp/pip-cache.${USER}
BUILD_TMP = /tmp/syncstorage-build.${USER}
PYPI = https://pypi.org/simple
INSTALL_STAMP = $(VENV)/.install.stamp
INSTALL_DEV_STAMP = $(VENV)/.install-dev.stamp

EGG_INFO = $(shell ls -1d *.egg-info 2>/dev/null)
FILES_PYC = $(shell find . -iname "*.pyc")

export MOZSVC_SQLURI = sqlite:///:memory:

# Hackety-hack around OSX system python bustage.
# The need for this should go away with a future osx/xcode update.
ARCHFLAGS = -Wno-error=unused-command-line-argument-hard-error-in-future
CFLAGS = -Wno-error=write-strings

INSTALL = ARCHFLAGS=$(ARCHFLAGS) CFLAGS=$(CFLAGS) $(PIP) --no-cache-dir install -U -i $(PYPI)

.IGNORE: clean

.PHONY: all build flake8 nose-test wsgi-test test

all: build

$(VENV):
	# The latest `pip` doesn't work with pypy 2.7 on some platforms.
	# Pin to a working version; ref https://github.com/pypa/pip/issues/8653
	$(VIRTUALENV) --no-pip $(VENV)
	$(EASY_INSTALL) pip==20.1.1
	$(INSTALL) --upgrade "setuptools>=0.7"

$(INSTALL_STAMP): $(VENV) requirements.txt
	$(INSTALL) -r requirements.txt
	touch "$@"

build: $(INSTALL_STAMP)

$(INSTALL_DEV_STAMP): $(VENV) $(INSTALL_STAMP) setup.py requirements-dev.txt
	$(INSTALL) --upgrade -r requirements-dev.txt
	$(PYTHON) setup.py develop
	touch "$@"

install-dev: $(INSTALL_DEV_STAMP)

flake8: install-dev
	# Check that flake8 passes before bothering to run anything.
	# This can really cut down time wasted by typos etc.
	$(VBIN)/flake8 syncstorage

nose-test: install-dev flake8
	# Run the actual testcases.
	$(NOSE) $(TESTS)

wsgi-test: install-dev flake8
	# Test that live functional tests can run correctly, by actually
	# spinning up a server and running them against it.
	( \
	$(VBIN)/gunicorn \
		--config gunicorn.conf.cprofile.py \
		--paste $(TESTS)/tests.ini \
		--workers 1 \
		--worker-class mozsvc.gunicorn_worker.MozSvcGeventWorker & SERVER_PID=$$! ; \
	sleep 2 ;\
	$(PYTHON) $(TESTS)/functional/test_storage.py http://localhost:5000 ; \
	kill $$SERVER_PID \
	)

test: flake8 nose-test wsgi-test

safetycheck: install-dev
	# Check for any dependencies with security issues.
	# We ignore a known issue with gevent, because we can't update to it yet.
	$(VBIN)/safety check --full-report --ignore 25837

clean:
	[ -z "$(EGG_INFO)" ] || rm -rf "$(EGG_INFO)"
	find . -mindepth 1 -type f -iname "*.pyc" -delete
	rm -rf $(VENV)
