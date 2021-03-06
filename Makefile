# os deps: node yarn git jq docker
# npm deps: eslint eslint-plugin-unicorn stylelint uglify-js grunt npm-check-updates

X86 := $(shell uname -m | grep 86)
ifeq ($(X86),)
	IMAGE=silverwind/armhf-droppy
else
	IMAGE=silverwind/droppy
endif

JQUERY_FLAGS=-ajax,-css,-deprecated,-effects,-event/alias,-event/focusin,-event/trigger,-wrap,-core/ready,-deferred,-exports/amd,-sizzle,-offset,-dimensions,-serialize,-queue,-callbacks,-event/support,-event/ajax,-attributes/prop,-attributes/val,-attributes/attr,-attributes/support,-manipulation/setGlobalEval,-manipulation/support,-manipulation/var/rcheckableType,-manipulation/var/rscriptType

deps:
	yarn global add eslint@latest eslint-plugin-unicorn@latest stylelint@latest uglify-js@latest grunt@latest npm-check-updates@latest

lint:
	node_modules/eslint/bin/eslint.js --color --ignore-pattern *.min.js --plugin unicorn --rule 'unicorn/catch-error-name: [2, {name: err}]' --rule 'unicorn/throw-new-error: 2' server client *.js
	node_modules/stylelint/bin/stylelint.js client/*.css

build:
	touch client/client.js
	node droppy.js build

publish:
	if git ls-remote --exit-code origin &>/dev/null; then git push -u -f --tags origin master; fi
	if git ls-remote --exit-code git &>/dev/null; then git push -u -f --tags git master; fi
	npm publish

docker:
	@echo Preparing docker image $(IMAGE)...
	docker pull mhart/alpine-node:latest
	docker rm -f "$$(docker ps -a -f='ancestor=$(IMAGE)' -q)" 2>/dev/null || true
	docker rmi "$$(docker images -qa $(IMAGE))" 2>/dev/null || true
	docker build --no-cache=true --squash -t $(IMAGE) .
	docker tag "$$(docker images -qa $(IMAGE):latest)" $(IMAGE):"$$(cat package.json | jq -r .version)"

docker-push:
	docker push $(IMAGE):"$$(cat package.json | jq -r .version)"
	docker push $(IMAGE):latest

update:
	node_modules/npm-check-updates/bin/ncu --packageFile package.json -ua
	rm -rf node_modules
	yarn
	touch client/client.js

deploy:
	git commit --allow-empty --allow-empty-message -m ""
	if git ls-remote --exit-code demo &>/dev/null; then git push -f demo master; fi
	if git ls-remote --exit-code droppy &>/dev/null; then git push -f droppy master; fi
	git reset --hard HEAD~1

jquery:
	rm -rf /tmp/jquery
	git clone --depth 1 https://github.com/jquery/jquery /tmp/jquery
	cd /tmp/jquery; yarn; grunt; grunt custom:$(JQUERY_FLAGS); grunt remove_map_comment
	cat /tmp/jquery/dist/jquery.min.js | perl -pe 's|"3\..+?"|"3"|' > $(CURDIR)/client/jquery-custom.min.js
	rm -rf /tmp/jquery

version-patch:
	npm version patch

version-minor:
	npm version minor

version-major:
	npm version major

patch: lint build version-patch deploy publish docker docker-push
minor: lint build version-minor deploy publish docker docker-push
major: lint build version-major deploy publish docker docker-push

.PHONY: deps lint publish docker update deploy jquery version-patch version-minor version-major patch minor major
