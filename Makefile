# Makefile for Ruby driver docs

GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
USER=$(shell whoami)
STAGING_URL="https://docs-mongodborg-staging.corp.mongodb.com"
PRODUCTION_URL="https://docs.mongodb.com"
	
STAGING_BUCKET=docs-mongodb-org-staging
PRODUCTION_BUCKET=docs-ruby-driver

PROJECT=ruby-driver
TARGET_SOURCE=source-${GIT_BRANCH}

# Parse our published-branches configuration file to get the name of
# the current "stable" branch. This is weird and dumb, yes.
STABLE_BRANCH=`grep 'manual' build/docs-tools/data/${PROJECT}-published-branches.yaml | cut -d ':' -f 2 | grep -Eo '[0-9a-z.]+'`

.PHONY: help stage fake-deploy deploy deploy-search-index check-redirects publish-build-only publish migrate clean

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo 'Variables'
	@printf "  \033[36m%-18s\033[0m %s\n" 'ARGS' 'Arguments to pass to mut-publish'

html: migrate ## Builds this branch's HTML under build/<branch>/html
	giza make html

publish-build-only: ## Builds this branch's publishable HTML and other artifacts under build/public
	giza make publish

publish: migrate ## Build publishable artifacts, and also migrates assets
	giza make publish

stage: ## Host online for review
	mut-publish build/${GIT_BRANCH}/html ${STAGING_BUCKET} --prefix=${PROJECT} --stage ${ARGS}
	@echo "Hosted at ${STAGING_URL}/${PROJECT}/${USER}/${GIT_BRANCH}/index.html"

fake-deploy: build/public/${GIT_BRANCH} ## Create a fake deployment in the staging bucket
	mut-publish build/public/ ${STAGING_BUCKET} --prefix=${PROJECT} --deploy --verbose  --redirects build/public/.htaccess ${ARGS}
	@echo "Hosted at ${STAGING_URL}/${PROJECT}/${GIT_BRANCH}/index.html"

deploy: build/public/${GIT_BRANCH} ## Deploy to the production bucket
	@echo "Doing a dry-run"
	mut-publish build/public/ ${PRODUCTION_BUCKET} --prefix=${PROJECT} --deploy --verbose  --redirects build/public/.htaccess --dry-run ${ARGS}

	@echo ''
	read -p "Press any key to perform the previous upload to ${PRODUCTION_BUCKET}"
	mut-publish build/public/ ${PRODUCTION_BUCKET} --prefix=${PROJECT} --deploy --verbose  --redirects build/public/.htaccess ${ARGS}

	@echo "Hosted at ${PRODUCTION_URL}/${PROJECT}/${GIT_BRANCH}"

	$(MAKE) deploy-search-index

deploy-search-index: ## Update the search index for this branch
	@echo "Building search index"
	if [ ${STABLE_BRANCH} = ${GIT_BRANCH} ]; then \
		mut-index upload build/public/${GIT_BRANCH} -o docs-ruby-${GIT_BRANCH}.json -u ${PRODUCTION_URL}/${PROJECT}/${GIT_BRANCH} -g -s; \
	else \
		mut-index upload build/public/${GIT_BRANCH} -o docs-ruby-${GIT_BRANCH}.json -u ${PRODUCTION_URL}/${PROJECT}/${GIT_BRANCH} -s; \
	fi


migrate: get-assets
	@echo "Making target source directory -- doing this explicitly instead of via cp"
	if [ -d ${TARGET_SOURCE} ]; then rm -rf ${TARGET_SOURCE} ; fi;
	mkdir ${TARGET_SOURCE}
	
	@echo "Copying over ruby-driver docs files"
	cp -R build/ruby-driver-${GIT_BRANCH}/docs/* ${TARGET_SOURCE}
	
	@echo "Copying over bson  docs files"
	cp -R build/bson-ruby/docs/* ${TARGET_SOURCE}	

get-assets:
	giza generate assets

#This workaround is because the redirects for symlink version does not prefix with ruby-driver.
check-redirects:
	perl -pi -e  's/301 \/v/301 \/ruby-driver\/v/g' build/public/.htaccess

clean:
	rm -rf build
