#!/usr/bin/env bash

source internal/globals.sh

OUT_FILE="$1"
shift

TEMP=$(mktemp)

cat << EOF > "${TEMP}"
m4_include(include/html.m4)
START_HTML([[${BLOG_TITLE} - Home]])
HEADER_HTML([[${BLOG_TITLE}]], [[${BLOG_SUBTITLE}]])
<h1>Posts</h1>
<ul>
EOF

while read FILE
do
	TITLE=$(get_title "$FILE")
	cat << EOF >> "${TEMP}"
<li><a href='/posts/$(basename "$FILE" .${POST_EXTENSION}).html'>${TITLE}</a></li>
EOF
	shift
done < <(sort_by_date "$@" | tac)

cat << EOF >> "${TEMP}"
</ul>
<a href='/tags/index.html'>Posts by tag</a>
FOOTER_HTML
END_HTML
EOF

"${M4}" ${M4_FLAGS} "${TEMP}" > "${OUT_FILE}"

rm "${TEMP}"