#!/usr/bin/env bash
# Smoke test for the milestone-1 vertical slice. Walks:
#   topic hub -> create user room with pins -> create post with attachments
#   -> reply (depth 2) -> reaction toggle -> patch/delete enforcement
#
# Run after `npm run db:seed && npm run api:dev`.

set -euo pipefail

API="${API:-http://localhost:3000/v1}"
MINSEO="11111111-1111-1111-1111-111111111111"
JOON="22222222-2222-2222-2222-222222222222"
HANEUL="33333333-3333-3333-3333-333333333333"

pass() { printf "  \033[32mPASS\033[0m %s\n" "$1"; }
fail() { printf "  \033[31mFAIL\033[0m %s\n" "$1"; exit 1; }
section() { printf "\n\033[1m== %s ==\033[0m\n" "$1"; }

curl_as() {
  local user="$1"; shift
  curl -sS -H "X-User-Id: $user" -H "Content-Type: application/json; charset=utf-8" "$@"
}

j() { node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(String(d$1))"; }

section "health & dev users"
[[ $(curl -sS "$API/health" | j ".ok") == "true" ]] && pass "/health ok" || fail "/health"

users_count=$(curl -sS "$API/dev/users" | j ".length")
[[ "$users_count" == "3" ]] && pass "/dev/users returns 3" || fail "dev/users"

section "topic hub bundle"
hub=$(curl_as "$MINSEO" "$API/categories/love-content/hub")
blocks=$(echo "$hub" | j ".blocks.length")
events=$(echo "$hub" | j ".related_events.length")
refs=$(echo "$hub" | j ".related_references.length")
rooms=$(echo "$hub" | j ".rooms.length")
[[ "$blocks" == "6" ]] && pass "hub blocks=6" || fail "hub blocks=$blocks"
[[ "$events" == "3" ]] && pass "hub events=3" || fail "hub events=$events"
[[ "$refs" == "3" ]] && pass "hub refs=3" || fail "hub refs=$refs"
[[ "$rooms" == "3" ]] && pass "hub rooms=3" || fail "hub rooms=$rooms"

section "events search and event-card upsert"
search=$(curl_as "$HANEUL" "$API/events/search?status=UPCOMING")
upcoming=$(echo "$search" | j ".items.length")
[[ "$upcoming" -ge 3 ]] && pass "search upcoming >=3 (got $upcoming)" || fail "search upcoming=$upcoming"

card1=$(curl_as "$HANEUL" -X POST -d '{"external_event_id":"evt-102"}' "$API/event-cards")
card_id=$(echo "$card1" | j ".id")
[[ -n "$card_id" ]] && pass "event-card upsert: $card_id" || fail "event-card upsert"

card2=$(curl_as "$HANEUL" -X POST -d '{"external_event_id":"evt-102"}' "$API/event-cards")
card_id_2=$(echo "$card2" | j ".id")
[[ "$card_id" == "$card_id_2" ]] && pass "upsert idempotent" || fail "idempotent: $card_id vs $card_id_2"

section "reference create"
ref=$(curl_as "$HANEUL" -X POST -d '{"url":"https://example.com/r1","title":"smoke ref","type":"ARTICLE"}' "$API/references")
ref_id=$(echo "$ref" | j ".id")
[[ -n "$ref_id" ]] && pass "reference created: $ref_id" || fail "reference"

section "user room creation with pins"
room=$(curl_as "$HANEUL" -X POST \
  -d "{\"name\":\"smoke room\",\"room_type\":\"DISCUSSION\",\"pinned_event_card_id\":\"$card_id\",\"pinned_reference_id\":\"$ref_id\"}" \
  "$API/categories/love-content/rooms")
room_slug=$(echo "$room" | j ".slug")
pin_count=$(echo "$room" | j ".pins.length")
[[ -n "$room_slug" ]] && pass "room created: $room_slug" || fail "room"
[[ "$pin_count" == "2" ]] && pass "room has 2 pins" || fail "pins=$pin_count"

section "post create with attachments"
post=$(curl_as "$HANEUL" -X POST \
  -d "{\"body\":\"smoke post\",\"attachments\":[{\"attachment_type\":\"EVENT_CARD\",\"target_id\":\"$card_id\"},{\"attachment_type\":\"REFERENCE\",\"target_id\":\"$ref_id\"}]}" \
  "$API/rooms/$room_slug/posts")
post_id=$(echo "$post" | j ".id")
att_count=$(echo "$post" | j ".attachments.length")
[[ -n "$post_id" ]] && pass "post created: $post_id" || fail "post"
[[ "$att_count" == "2" ]] && pass "post has 2 attachments" || fail "attachments=$att_count"

section "timeline shows new post"
timeline=$(curl_as "$HANEUL" "$API/rooms/$room_slug/timeline")
first_id=$(echo "$timeline" | j ".items[0].id")
[[ "$first_id" == "$post_id" ]] && pass "post is first in timeline" || fail "timeline head=$first_id"

section "replies (depth 2 OK, depth 3 rejected)"
r1=$(curl_as "$JOON" -X POST -d "{\"body\":\"r1\"}" "$API/posts/$post_id/replies")
r1_id=$(echo "$r1" | j ".id")
pass "depth-1 reply: $r1_id"

r2=$(curl_as "$JOON" -X POST -d "{\"body\":\"r2\",\"parent_reply_id\":\"$r1_id\"}" "$API/posts/$post_id/replies")
r2_id=$(echo "$r2" | j ".id")
pass "depth-2 reply: $r2_id"

depth3_code=$(curl_as "$JOON" -o /dev/null -w "%{http_code}" -X POST -d "{\"body\":\"r3\",\"parent_reply_id\":\"$r2_id\"}" "$API/posts/$post_id/replies")
[[ "$depth3_code" == "400" ]] && pass "depth-3 rejected with 400" || fail "depth-3 code=$depth3_code"

section "reaction toggle"
t1=$(curl_as "$JOON" -X POST -d "{\"target_type\":\"POST\",\"target_id\":\"$post_id\"}" "$API/reactions/toggle")
liked1=$(echo "$t1" | j ".liked")
count1=$(echo "$t1" | j ".like_count")
[[ "$liked1" == "true" && "$count1" == "1" ]] && pass "first toggle: liked=true count=1" || fail "first toggle: $t1"

t2=$(curl_as "$JOON" -X POST -d "{\"target_type\":\"POST\",\"target_id\":\"$post_id\"}" "$API/reactions/toggle")
liked2=$(echo "$t2" | j ".liked")
count2=$(echo "$t2" | j ".like_count")
[[ "$liked2" == "false" && "$count2" == "0" ]] && pass "second toggle: liked=false count=0" || fail "second toggle: $t2"

section "patch/delete enforcement"
patch_code=$(curl_as "$JOON" -o /dev/null -w "%{http_code}" -X PATCH -d '{"body":"hostile edit"}' "$API/posts/$post_id")
[[ "$patch_code" == "403" ]] && pass "non-author PATCH -> 403" || fail "patch as non-author: $patch_code"

delete_code=$(curl_as "$HANEUL" -o /dev/null -w "%{http_code}" -X DELETE "$API/posts/$post_id")
[[ "$delete_code" == "204" ]] && pass "author DELETE -> 204" || fail "delete: $delete_code"

after_get=$(curl_as "$HANEUL" -o /dev/null -w "%{http_code}" "$API/posts/$post_id")
[[ "$after_get" == "404" ]] && pass "after delete GET -> 404" || fail "after delete: $after_get"

printf "\n\033[1;32mAll smoke checks passed.\033[0m\n"
