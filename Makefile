# Makefile for Ruby driver docs

GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)

USER=$(shell whoami)
STAGING_URL="https://docs-mongodborg-staging.corp.mongodb.com"
PRODUCTION_URL="https://docs.mongodb.com"
	
STAGING_BUCKET=docs-mongodb-org-staging
PRODUCTION_BUCKET=docs-ruby-driver

PREFIX=ruby-driver
TARGET_DIR=source-${GIT_BRANCH}

.PHONY: help stage html publish-build-only publish migrate get-asset fake-deploy deploy check-redirects 

help:
	@echo 'Targets'
	@echo '  help         - Show this help message'
	@echo '  stage        - Host online for review'
	@echo '  fake-deploy-all  - Create a fake deployment in the staging bucket'
	@echo '  deploy       - Deploy to the production bucket'
	@echo ''
	@echo 'Variables'
	@echo '  ARGS         - Arguments to pass to mut-publish'

html: migrate
	giza make html

publish-build-only:
	giza make publish

publish: migrate
	giza make publish

stage:
	mut-publish build/${GIT_BRANCH}/html ${STAGING_BUCKET} --prefix=${PREFIX} --stage ${ARGS}
	@echo "Hosted at ${STAGING_URL}/${PREFIX}/${USER}/${GIT_BRANCH}/index.html"

fake-deploy: build/public/${GIT_BRANCH}
	mut-publish build/public/ ${STAGING_BUCKET} --prefix=${PREFIX} --deploy --verbose  --redirects build/public/.htaccess ${ARGS}
	@echo "Hosted at ${STAGING_URL}/${PREFIX}/${GIT_BRANCH}/index.html"

deploy: build/public/${GIT_BRANCH}
	@echo "Doing a dry-run"
	mut-publish build/public/ ${PRODUCTION_BUCKET} --prefix=${PREFIX} --deploy --verbose  --redirects build/public/.htaccess --dry-run ${ARGS}

	@echo ''
	read -p "Press any key to perform the previous upload to ${PRODUCTION_BUCKET}"
	mut-publish build/public/ ${PRODUCTION_BUCKET} --prefix=${PREFIX} --deploy --verbose  --redirects build/public/.htaccess ${ARGS}

	@echo "Hosted at ${PRODUCTION_URL}/${PREFIX}/${GIT_BRANCH}"

migrate: get-assets
	@echo "Making target source directory -- doing this explicitly instead of via cp"
	if [ -d ${TARGET_DIR} ]; then rm -rf ${TARGET_DIR} ; fi;
	mkdir ${TARGET_DIR}
	
	@echo "Copying over ruby-driver docs files"
	cp -R build/ruby-driver-${GIT_BRANCH}/docs/ ${TARGET_DIR}
	
	@echo "Copying over bson  docs files"
	cp -R build/bson-ruby/docs/ ${TARGET_DIR}


get-assets:
	giza generate assets

#This workaround is because the redirects for symlink version does not prefix with ruby-driver.
check-redirects:
	perl -pi -e  's/301 \/v/301 \/ruby-driver\/v/g' build/public/.htaccess
