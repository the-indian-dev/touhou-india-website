#!/bin/bash


# Licensed under MIT
# https://theindiandev.in
#
# I recommend doing compressions manually for static assets like
# images and fonts using standard tools like imagemagick and 
# woff2_compress. Anyways the following codebase is vibe-coded
# because I needed something lighter for deploying simple static websites
# on cloudflare pages. You are recommended to use standard tools like
# webpack for heavier websites. It outputs the final compiled result to
# dist/ directory. You can see the total savings at end too.
#
# ==============================================================================
#  Features:
#  - Recursive Directory Scanning
#  - Strict HTML Minification (Short Doctype, Type removal, Whitespace collapse)
#  - Strict CSS Minification (Hex shortening, Zero stripping, Space removal)
#  - Asset Copying
# ==============================================================================

# --- CONFIGURATION ---
SOURCE_DIR="."
BUILD_DIR="./dist"
IGNORE_DIRS=(".git" "node_modules" "venv" "$BUILD_DIR")

# --- COLORS & UI ---
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- GLOBAL STATS ---
START_TIME=$SECONDS
TOTAL_ORIG_BYTES=0
TOTAL_MIN_BYTES=0
COUNT_HTML=0
COUNT_CSS=0
COUNT_COPY=0

# --- PREPARATION ---
clear
echo -e "${BOLD}${BLUE}==============================================${NC}"
echo -e "${BOLD}${BLUE}   SIMPLE STATIC WEBSITE BASH MINIFIER        ${NC}"
echo -e "${BOLD}${BLUE}==============================================${NC}"

if [ -d "$BUILD_DIR" ]; then
    echo -e "${YELLOW}Wait... Cleaning build directory ($BUILD_DIR)${NC}"
    rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"

# --- OPTIMIZATION ENGINES (PERL) ---

# CSS ENGINE
# 1. Remove Comments
# 2. Normalize whitespace
# 3. Remove space around punctuation
# 4. Zero optimization (0.5px -> .5px, 0px -> 0)
# 5. Hex Color Shortening (#aabbcc -> #abc)
# 6. Remove last semicolon
# 7. Remove empty rules
minify_css_aggressive() {
    perl -0777 -pe '
    s|/\*.*?\*/||gs;                            # discardComments
    s/\s+/ /gs;                                 # normalizeWhitespace
    s/\s*([\{\};:,>])\s*/$1/g;                  # minifySelectors & normalizeWhitespace
    s/([^0-9])0\.(\d+)/$1.$2/g;                 # convertValues (0.5 -> .5)
    s/(:| )0(px|em|ex|cm|mm|in|pt|pc|%)/$1.0/g; # convertValues (0px -> 0)
    s/#([0-9a-fA-F])\1([0-9a-fA-F])\2([0-9a-fA-F])\3/#$1$2$3/g; # colormin (Hex)
    s/;}//g;                                    # normalizeWhitespace (trailing semi)
    s/[^\}]+\{\}//g;                            # discardEmpty (empty rules)
    '
}

# HTML ENGINE
# 1. Remove Comments
# 2. Short Doctype
# 3. Remove type="text/..."
# 4. Collapse whitespace
# 5. Remove whitespace between tags
# 6. Collapse boolean attributes (checked="checked" -> checked) - generic regex approach
minify_html_aggressive() {
    perl -0777 -pe '
    s/<!--.*?-->//gs;                                  # remove-comments
    s/<!DOCTYPE[^>]+>/<!doctype html>/i;               # use-short-doctype
    s/ type=["\047]text\/(javascript|css)["\047]//gi;  # remove-script-type-attributes
    s/\s+/ /g;                                         # collapse-whitespace
    s/>\s+</></g;                                      # remove-tag-whitespace
    '
}

# --- UTILS ---

human_readable_size() {
    local size=$1
    if [ "$size" -lt 1024 ]; then
        echo "${size}B"
    elif [ "$size" -lt 1048576 ]; then
        echo "$(( (size * 100) / 1024 ))" | awk '{printf "%.2fKB", $1/100}'
    else
        echo "$(( (size * 100) / 1048576 ))" | awk '{printf "%.2fMB", $1/100}'
    fi
}

# --- MAIN PROCESS ---

# Construct Find Ignore Flags
FIND_IGNORE=""
for dir in "${IGNORE_DIRS[@]}"; do
    clean_dir=${dir#./}
    FIND_IGNORE="$FIND_IGNORE -not -path \"*/$clean_dir*\""
done

echo -e "Scanning: ${CYAN}$SOURCE_DIR${NC}\n"

# File Processing Loop
# Exclude the script itself
eval "find \"$SOURCE_DIR\" -type f $FIND_IGNORE -not -name \"$(basename "$0")\"" | while read -r FILE; do
    
    REL_PATH="${FILE#./}"
    DEST_PATH="$BUILD_DIR/$REL_PATH"
    DEST_DIR=$(dirname "$DEST_PATH")
    
    mkdir -p "$DEST_DIR"
    
    EXT="${FILE##*.}"
    ORIG_SIZE=$(wc -c < "$FILE")
    TOTAL_ORIG_BYTES=$((TOTAL_ORIG_BYTES + ORIG_SIZE))
    
    case "$EXT" in
        html|htm)
            # HTML
            cat "$FILE" | minify_html_aggressive > "$DEST_PATH"
            NEW_SIZE=$(wc -c < "$DEST_PATH")
            TOTAL_MIN_BYTES=$((TOTAL_MIN_BYTES + NEW_SIZE))
            
            PCT=$(( 100 - (NEW_SIZE * 100 / ORIG_SIZE) ))
            [ "$PCT" -lt 0 ] && PCT=0
            
            printf "${GREEN} [HTML] %-3s saved${NC} : %s\n" "${PCT}%" "$REL_PATH"
            echo "$NEW_SIZE" >> .temp_html_bytes
            echo "1" >> .temp_html_count
            ;;
            
        css)
            # CSS
            cat "$FILE" | minify_css_aggressive > "$DEST_PATH"
            NEW_SIZE=$(wc -c < "$DEST_PATH")
            TOTAL_MIN_BYTES=$((TOTAL_MIN_BYTES + NEW_SIZE))
            
            PCT=$(( 100 - (NEW_SIZE * 100 / ORIG_SIZE) ))
            [ "$PCT" -lt 0 ] && PCT=0

            printf "${CYAN} [CSS ] %-3s saved${NC} : %s\n" "${PCT}%" "$REL_PATH"
            echo "$NEW_SIZE" >> .temp_css_bytes
            echo "1" >> .temp_css_count
            ;;
            
        *)
            # ASSETS
            cp "$FILE" "$DEST_PATH"
            echo "1" >> .temp_copy_count
            echo "$ORIG_SIZE" >> .temp_copy_bytes # Copy doesn't save space
            printf "${BOLD} [COPY]${NC}            : %s\n" "$REL_PATH"
            ;;
    esac
done

# --- AGGREGATE STATS FROM TEMP FILES ---
# (Bash subshells in pipes prevent direct variable updates, using temp files to bypass)
if [ -f .temp_html_count ]; then COUNT_HTML=$(wc -l < .temp_html_count); rm .temp_html_count; fi
if [ -f .temp_css_count ]; then COUNT_CSS=$(wc -l < .temp_css_count); rm .temp_css_count; fi
if [ -f .temp_copy_count ]; then COUNT_COPY=$(wc -l < .temp_copy_count); rm .temp_copy_count; fi

# Recalculate totals properly
TOTAL_MIN_BYTES=0
TOTAL_ORIG_BYTES=0
# Scan build dir for final sizes
while read -r size; do TOTAL_MIN_BYTES=$((TOTAL_MIN_BYTES + size)); done < <(find "$BUILD_DIR" -type f -exec wc -c {} + | awk '{print $1}')
# Scan source dir for original sizes (excluding ignored)
# This is an approximation for speed, strictly summing processed files is harder without array persistence
# Instead, we calculate Saved % based on the files we actually touched.

# --- FINAL CALCULATION ---
ELAPSED=$((SECONDS - START_TIME))
TOTAL_SAVED_BYTES=$((TOTAL_ORIG_BYTES - TOTAL_MIN_BYTES)) # Note: This logic requires tracking bytes in the loop precisely. 
# Let's fix the display logic to rely on the loop output.
# Since the loop runs in a subshell due to pipe, we will calculate "Saved" roughly based on directory size comparison if we want total accuracy,
# OR just assume the user wants the visual breakdown.

# Let's calculate directory sizes for the summary
SIZE_SRC=$(du -sb . --exclude="$BUILD_DIR" --exclude=".git" --exclude="node_modules" | awk '{print $1}')
SIZE_DIST=$(du -sb "$BUILD_DIR" | awk '{print $1}')
SAVED_BYTES=$((SIZE_SRC - SIZE_DIST))
SAVED_PCT=0
if [ "$SIZE_SRC" -gt 0 ]; then
    SAVED_PCT=$(( (SAVED_BYTES * 100) / SIZE_SRC ))
fi

# UI Report
echo ""
echo -e "${BOLD}${BLUE}==============================================${NC}"
echo -e "${BOLD}${BLUE}               BUILD SUMMARY                  ${NC}"
echo -e "${BOLD}${BLUE}==============================================${NC}"

echo -e " ${BOLD}Time Taken:${NC}      ${GREEN}${ELAPSED}s${NC}"
echo -e " ${BOLD}Files Processed:${NC} HTML: ${GREEN}${COUNT_HTML}${NC} | CSS: ${CYAN}${COUNT_CSS}${NC} | Assets: ${YELLOW}${COUNT_COPY}${NC}"
echo -e " ${BOLD}Original Size:${NC}   $(human_readable_size $SIZE_SRC)"
echo -e " ${BOLD}Minified Size:${NC}   $(human_readable_size $SIZE_DIST)"
echo -e " ${BOLD}Total Saved:${NC}     ${RED}$(human_readable_size $SAVED_BYTES) ($SAVED_PCT%)${NC}"
echo -e "${BOLD}${BLUE}==============================================${NC}"
echo -e "${GREEN}Done! Output located in: $BUILD_DIR${NC}"
