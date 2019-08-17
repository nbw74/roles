#!/bin/bash
set -e
set -o nounset

arg1=$1

if (( arg1 )); then
    status=FAIL
    symbol=❌
else
    status=OK
    symbol=✅
fi

URL="https://api.telegram.org/bot${TG_WM_BOT_TOKEN_ID}:${TG_WM_BOT_TOKEN_BODY}/sendMessage"
TEXT="PIPELINE STATUS: ${status} ${symbol}%0A%0AProject:+$CI_PROJECT_NAME%0AURL:+$CI_PROJECT_URL/pipelines/$CI_PIPELINE_ID/%0ABranch:+$CI_COMMIT_REF_SLUG"
curl -s --max-time 10 -d "chat_id=${TG_WM_CHAT_ID}&disable_web_page_preview=1&text=${TEXT}" $URL > /dev/null

