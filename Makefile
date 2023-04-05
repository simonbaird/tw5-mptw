MAKEFLAGS += --silent

##-----------------------------------------------
## Exporting from Tiddlyhost
##

# Lists of tiddlers that are considered relevant.
#
# The foreach uses space as the delimiter so for tiddlers with
# a space so the + char is a clunky workaround for tiddlers with
# a space in their name. See the jq 'sub' below.
#
define content_tiddlers
  About+MPTW5
  $$:/Mptw5/StatelessSidebar
  $$:/Mptw5/StyleSheet
  $$:/Mptw5/TaggingList
  $$:/Mptw5/TagLinks
endef

define config_tiddlers
  $$:/DefaultTiddlers
  $$:/SiteTitle
  $$:/palette
  $$:/themes/tiddlywiki/vanilla/options/codewrapping

  $$:/config/DefaultSidebarTab
  $$:/config/WikiParserRules/Inline/wikilink
  $$:/config/RelinkOnRename

  $$:/config/PageControlButtons/Visibility/$$:/core/ui/Buttons/home
  $$:/config/PageControlButtons/Visibility/$$:/core/ui/Buttons/manager
  $$:/config/PageControlButtons/Visibility/$$:/core/ui/Buttons/more-page-actions
  $$:/config/ViewToolbarButtons/Visibility/$$:/core/ui/Buttons/close-others
  $$:/config/ViewToolbarButtons/Visibility/$$:/core/ui/Buttons/new-here
endef

SOURCE_SITE=mptw5
SOURCE_URL=https://$(SOURCE_SITE).tiddlyhost.com/tiddlers.json?include_system=1

# I don't want to keep these fields
JQ_DEL_FIELDS=del(.modified,.modifier,.created,.creator)

# Some fun Makefile and jq tricks here
JQ_SELECT=$(foreach title,$($1),or (.title|sub(" "; "+"))=="$(title)")

# Fetch from the existing site and dump the listed tiddlers into a yaml file
# which should be nicer than json to maintain, though .tid and .multids files
# would probably be better (todo).
#
extract-%:
	@curl -s $(SOURCE_URL) | \
	  jq '[ .[] | select(false $(call JQ_SELECT,$*_tiddlers)) | $(JQ_DEL_FIELDS) ]' | \
	  yq -P > tiddlers/$*.yaml && \
	echo Wrote tiddlers from $(SOURCE_SITE) to tiddlers/$*.yaml

extract: extract-config extract-content

##-----------------------------------------------
## Building empties
##

MPTW_DIR=../tw5-mptw
MPTW_OUTPUT=$(MPTW_DIR)/output

TW5_DIR=../TiddlyWiki5
TW5_OUTPUT=$(TW5_DIR)/output/tw5-mptw

$(MPTW_OUTPUT):
	@mkdir -p $(MPTW_OUTPUT)

# Convert back to json so TiddlyWiki can use it when building
$(MPTW_OUTPUT)/%.json: tiddlers/%.yaml $(MPTW_OUTPUT)
	@yq -o json < $< > $@

TW_VER=5.2.7

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

build-%: $(MPTW_OUTPUT)/content.json $(MPTW_OUTPUT)/config.json $(MPTW_OUTPUT)/%.json core-file
	@cd $(TW5_DIR) && \
	git reset --hard --quiet && git checkout --quiet v$(TW_VER) && \
	node tiddlywiki.js editions/empty \
	  --load $(MPTW_OUTPUT)/content.json \
	  --load $(MPTW_OUTPUT)/config.json \
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
TH_DIR=../tiddlyhost
UPLOADER=$(TH_DIR)/examples/thost-uploader
BACKUPS_DIR=$(MPTW_DIR)/backups
upload-%:
	@env DOWNLOAD_DIR=$(BACKUPS_DIR) $(UPLOADER) $* $(MPTW_OUTPUT)/$*.html $(TH_LOGIN) $$(cat $(TH_PASS_FILE))

# Example usage:
#   TH_LOGIN=simon.baird@gmail.com TH_PASS_FILE=~/.thostpass make upload
upload: upload-mptw5 upload-mptw5x

build-upload: clean build upload
