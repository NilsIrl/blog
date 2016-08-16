#!/usr/bin/env bash

source internal/globals.sh

set_editor

TEMP="$(mktemp)"
NOW=$(date +'%s')

TITLE="My Newest Post"
[[ "$@" != "" ]] && TITLE="$@"

cat << EOF > ${TEMP}
${NOW}
${COMMENT_CODE} Create your post below. Lines beginning with "${COMMENT_CODE}" will be stripped
${COMMENT_CODE} out.
${COMMENT_CODE}
${COMMENT_CODE} The first line is the timestamp of when this most is made.
${COMMENT_CODE}
${COMMENT_CODE} The second line will be used as the title of the post.
${COMMENT_CODE}
${COMMENT_CODE} Any remaining lines are considered the body. Any word preceeded by
${COMMENT_CODE} "${TAG_CODE}" will be treated as a tag. In the final HTML page, tags will have
${COMMENT_CODE} the preceeding "${TAG_CODE} removed and hyperlinks added.
${COMMENT_CODE}
${COMMENT_CODE} Other than these additions, use markdown to format your post.
${TITLE}
EOF

"${ED}" "${TEMP}"

read -p "Would you like to save this post? " ANSWER
while [ 1 ]; 
do
	case $ANSWER in
		[Yy]* )
			POST_DATE=$(get_date ${TEMP})
			YEAR=$(date --date=@${POST_DATE} +'%Y')
			MONTH=$(date --date=@${POST_DATE} +'%m')
			mkdir -p "${POST_DIR}/${YEAR}/${MONTH}"
			TITLE=$(get_title "${TEMP}" | to_lower | strip_space)
			FILENAME="${POST_DIR}/${YEAR}/${MONTH}/${TITLE}${TITLE_SEPERATOR_CHAR}${RANDOM}.${POST_EXTENSION}"
			mv "${TEMP}" "${FILENAME}"
			make
			break;;
		[Nn]* )
			rm "${TEMP}"
			break;;
		* )
			echo "Please answer yes or no";;
	esac
done

