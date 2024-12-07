MAKEFLAGS += --silent

##-----------------------------------------------
## Building empties
##

MPTW_DIR=../tw5-mptw
MPTW_OUTPUT=$(MPTW_DIR)/output

TW5_DIR=../TiddlyWiki5
TW5_OUTPUT=$(TW5_DIR)/output/tw5-mptw

$(MPTW_OUTPUT):
	@mkdir -p $(MPTW_OUTPUT)

BUILD_VERSION=1.$(shell git rev-list --count HEAD)-$(shell git log -n1 --format=%h | head -c5 )
BUILD_TIMESTAMP=$(shell date -u +'%Y%m%d%H%M%S%N' | head -c 17 )

# Convert back to json so TiddlyWiki can use it when building
# and also apply some quick and dirty text replacement
$(MPTW_OUTPUT)/%.json: tiddlers/%.yaml $(MPTW_OUTPUT)
	@cat $< | yq -o json \
	  | sed 's/__MPTW5_VERSION__/$(BUILD_VERSION)/' \
	  | sed 's/__MPTW5_BUILD_TIMESTAMP__/$(BUILD_TIMESTAMP)/' \
	  > $@

TW_VER=5.3.6

$(MPTW_OUTPUT)/tiddlywikicore-$(TW_VER).js:
	@cd $(MPTW_OUTPUT) && \
	curl -sO https://tiddlyspot.com/tiddlywikicore-$(TW_VER).js

# Need this or the external core file won't work
core-file: $(MPTW_OUTPUT)/tiddlywikicore-$(TW_VER).js

# Creates two different empty files, one normal and one for external core.
# Assumes you have TiddlyWiki5 checked out in $(TW5_DIR).
#
rendertiddler_mptw5=$$:/core/save/all
rendertiddler_mptw5x=$$:/core/save/offline-external-js

build-%: $(MPTW_OUTPUT)/content.json $(MPTW_OUTPUT)/config.json $(MPTW_OUTPUT)/text.json $(MPTW_OUTPUT)/%.json core-file
	@cd $(TW5_DIR) && \
	git reset --hard --quiet && git checkout --quiet v$(TW_VER) && \
	node tiddlywiki.js editions/empty \
	  --load $(MPTW_OUTPUT)/content.json \
	  --load $(MPTW_OUTPUT)/config.json \
	  --load $(MPTW_OUTPUT)/text.json \
	  --load $(MPTW_OUTPUT)/$*.json \
	  --output $(TW5_OUTPUT) \
	  --rendertiddler '$(rendertiddler_$*)' '$*.html' 'text/plain' && \
	cp $(TW5_OUTPUT)/$*.html $(MPTW_OUTPUT)/$*.html && \
	cd $(MPTW_DIR) && ls -l output/$*.html

build: build-mptw5 build-mptw5x

clean:
	@rm -rf $(MPTW_OUTPUT)

# View in your browser to check they work
preview-%:
	@xdg-open $(MPTW_OUTPUT)/$*.html

preview: preview-mptw5 preview-mptw5x

build-preview: clean build preview

# Use the script in the tiddlyhost examples directory for uploading
TH_DIR=../tiddlyhost-com
UPLOADER=$(TH_DIR)/examples/thost-uploader
BACKUPS_DIR=$(MPTW_DIR)/backups
upload-%:
	@env DOWNLOAD_DIR=$(BACKUPS_DIR) $(UPLOADER) $* $(MPTW_OUTPUT)/$*.html $(TH_LOGIN) $$(cat $(TH_PASS_FILE))

# Example usage:
#   TH_LOGIN=simon.baird@gmail.com TH_PASS_FILE=../.thostpass make upload
upload: upload-mptw5 upload-mptw5x

build-upload: clean build upload
