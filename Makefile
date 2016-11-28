CMD_BUILD_POST=./internal/build-post.sh
CMD_BUILD_POSTS_INDEX=./internal/build-posts-index.sh
CMD_BUILD_INDEX=./internal/build-index.sh
CMD_BUILD_TAGS=./internal/build-tags.sh

.PHONY: all clean
SHELL=/bin/bash

# These are the files that always exist
# AKA source files
POST_FILES := $(shell find $(POST_DIR) -name '*.bm')
CSS_FILES := $(shell find $(INCLUDE_DIR) -name '*.css.in')
USER_CONF_FILE := $(INCLUDE_DIR)/bm.conf
INCLUDE_FILES := $(shell find $(INCLUDE_DIR) -name '*.html' -or -name '*.m4' -or -name '*.conf.example') \
	$(USER_CONF_FILE)

# These are output dirs that need to exist before files start getting dropped in them
OUT_DIRS := $(METADATA_DIR) $(BUILT_POST_DIR) $(BUILT_STATIC_DIR) $(BUILT_TAG_DIR) $(BUILT_SHORT_POST_DIR)

# These are the targets. These files don't exist until after a successful build
BUILT_POSTS := $(POST_FILES:.bm=.html) # posts/year/month/post-title-123.{bm,html}
BUILT_POSTS := $(notdir $(BUILT_POSTS)) # post-title-123.html
BUILT_POSTS := $(addprefix $(BUILT_POST_DIR)/,$(BUILT_POSTS)) # build/posts/post-title-123.html
BUILT_STATICS := $(CSS_FILES:.css.in=.css)
BUILT_STATICS := $(notdir $(BUILT_STATICS))
BUILT_STATICS := $(addprefix $(BUILT_STATIC_DIR)/,$(BUILT_STATICS))
BUILT_META_FILES := \
	$(BUILD_DIR)/index.html \
	$(BUILT_POST_DIR)/index.html \
	$(BUILT_TAG_DIR)/index.html
BUILT_SHORT_POSTS := $(foreach file,$(POST_FILES),$(BUILT_SHORT_POST_DIR)/$(shell get_id $(file)).html)

METADATA_FILES := \
	$(METADATA_DIR)/pagehead \
	$(METADATA_DIR)/pagefoot \
	$(METADATA_DIR)/postsbydate

POST_METADATA_FILES := $(foreach file,$(POST_FILES),$(METADATA_DIR)/$(shell get_id $(file)))
POST_METADATA_FILES := $(foreach dir,$(POST_METADATA_FILES),\
	$(dir)/headers \
	$(dir)/head \
	$(dir)/body \
	$(dir)/foot \
	$(dir)/tags \
	$(dir)/options \
	$(dir)/toc \
	$(dir)/content \
	$(dir)/previewcontent)

all: $(OUT_DIRS) \
	$(METADATA_FILES) \
	$(POST_METADATA_FILES) \
	$(BUILT_SHORT_POSTS) \
	$(BUILT_POSTS) \
	$(BUILT_STATICS) \
	$(BUILT_META_FILES)

$(OUT_DIRS):
	$(MKDIR) $(MKDIR_FLAGS) $@

$(METADATA_DIR)/pagehead:


$(METADATA_DIR)/pagefoot:


$(METADATA_DIR)/postsbydate: $(POST_FILES) | $(OUT_DIRS)
	for POST in `sort_by_date $^`; do get_id $$POST; done > $@

$(METADATA_DIR)/%/headers: $(POST_DIR)/*/*/*-%.bm
	$(MKDIR) $(MKDIR_FLAGS) $(@D)
	@echo $@
	get_headers $< > $@

$(METADATA_DIR)/%/tags: $(POST_DIR)/*/*/*-%.bm
	$(MKDIR) $(MKDIR_FLAGS) $(@D)
	@echo $@
	get_tags $< > $@

$(METADATA_DIR)/%/options: $(POST_DIR)/*/*/*-%.bm
	$(MKDIR) $(MKDIR_FLAGS) $(@D)
	@echo $@
	mv $(shell parse_options $<) $@
	validate_options $< $@

$(METADATA_DIR)/%/toc: $(METADATA_DIR)/%/content
	#@echo $@
	get_toc $< > $@

$(METADATA_DIR)/%/content: $(POST_DIR)/*/*/*-%.bm
	$(MKDIR) $(MKDIR_FLAGS) $(@D)
	@echo $@
	get_content $< > $@

$(METADATA_DIR)/%/previewcontent: $(METADATA_DIR)/%/content $(METADATA_DIR)/%/options
	#@echo $@
	get_preview_content $(@D)/content $(@D)/options > $@

# Target for per-post header. Completely HTML formatted
$(METADATA_DIR)/%/head: $(METADATA_DIR)/%/headers
	@echo $@
	build_content_header $* | $(M4) $(M4_FLAGS) > $@

# Target for per-post footer. Completely HTML formatted
$(METADATA_DIR)/%/foot:
	@echo $@
	build_content_footer $* | $(M4) $(M4_FLAGS) > $@

# Target for per-post body. Completely HTML formatted.
$(METADATA_DIR)/%/body: $(METADATA_DIR)/%/headers $(METADATA_DIR)/%/content $(METADATA_DIR)/%/toc
	@echo $@
	$(eval METADATA := $(METADATA_DIR)/$(shell get_id $<))
	< $(METADATA)/content \
	pre_markdown $(shell get_id $<) |\
	$(MARKDOWN) |\
	post_markdown $(shell get_id $<) > $@

# Target for short posts
$(BUILT_SHORT_POST_DIR)/%.html: $(METADATA_DIR)/%/head $(METADATA_DIR)/%/body $(METADATA_DIR)/%/foot
	@echo $@
	cat $^ | awk 'NF' > $@

# Target for posts
$(BUILT_POSTS): $(BUILT_SHORT_POSTS)
	@echo $@
	$(eval ID := $(shell echo $@ | sed -E 's|.*-(.*).html|\1|'))
ifeq ($(MAKE_SHORT_POSTS),yes)
	cp $(BUILT_SHORT_POST_DIR)/$(ID).html $@
else
	mv $(BUILT_SHORT_POST_DIR)/$(ID).html $@
endif

# Target for homepage
$(BUILD_DIR)/index.html: $(POST_FILES) $(INCLUDE_FILES) $(CSS_FILES) | $(OUT_DIRS)
	@echo $@
	$(CMD_BUILD_INDEX) $@ $(POST_FILES)

# Target for posts index
$(BUILT_POST_DIR)/index.html: $(POST_FILES) $(INCLUDE_FILES) $(CSS_FILES) | $(OUT_DIRS)
	@echo $@
	$(CMD_BUILD_POSTS_INDEX) $@ $(POST_FILES)

# Target for tags index
$(BUILT_TAG_DIR)/index.html: $(POST_FILES) $(INCLUDE_FILES) $(CSS_FILES) | $(OUT_DIRS)
	@echo $@
	$(CMD_BUILD_TAGS) $@ $(POST_FILES)

# Target for all CSS
$(BUILT_STATIC_DIR)/%.css: $(INCLUDE_DIR)/%.css.in $(INCLUDE_FILES) | $(OUT_DIRS)
	@echo $@
	$(MKDIR) $(MKDIR_FLAGS) $(BUILT_STATIC_DIR)
	$(M4) $(M4_FLAGS) $< > $@

# Target to automatically make the config file if necessary
$(USER_CONF_FILE): $(INCLUDE_DIR)/bm.conf.example
	[ ! -f $@ ] && grep -vE '^#' $< > $@ || touch $@

clean:
	$(RM) $(RM_FLAGS) -- $(BUILD_DIR)/* $(METADATA_DIR)/*
	[ -d $(BUILD_DIR) ] && [ ! -L $(BUILD_DIR) ] && rmdir $(BUILD_DIR) || exit 0
	[ -d $(METADATA_DIR) ] && [ ! -L $(METADATA_DIR) ] && rmdir $(METADATA_DIR) || exit 0
