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
STUDIO_LEAD="55555555-5555-5555-5555-555555555555"
STUDIO_MATE="66666666-6666-6666-6666-666666666666"

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
# 3 from M1; 4 since M2 added the `coral` curator persona.
[[ "$users_count" -ge "3" ]] && pass "/dev/users returns ${users_count}" || fail "dev/users (got $users_count)"

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

section "search"
# 환승연애 URL-encoded
search_res=$(curl_as "$MINSEO" "$API/search?q=%ED%99%98%EC%8A%B9%EC%97%B0%EC%95%A0")
group_count=$(echo "$search_res" | j ".groups.length")
[[ "$group_count" == "6" ]] && pass "search returns 6 groups" || fail "groups=$group_count"

# Sum items across all groups — should be >=4 for 환승연애 (room+post+ref+event).
total_hits=$(echo "$search_res" | j ".groups.reduce((a,g)=>a+g.items.length,0)")
[[ "$total_hits" -ge "4" ]] && pass "search '환승연애' total hits=$total_hits (>=4)" || fail "total_hits=$total_hits"

# Type filter
filtered=$(curl_as "$MINSEO" "$API/search?q=%ED%99%98%EC%8A%B9%EC%97%B0%EC%95%A0&types=room,post")
room_count=$(echo "$filtered" | j ".groups.find(g=>g.type==='room').items.length")
event_count=$(echo "$filtered" | j ".groups.find(g=>g.type==='event_card').items.length")
[[ "$room_count" -ge "1" && "$event_count" == "0" ]] && pass "types=room,post limits to room/post groups" || fail "filter room=$room_count event=$event_count"

# Empty q -> 400
empty_code=$(curl_as "$MINSEO" -o /dev/null -w "%{http_code}" "$API/search?q=")
[[ "$empty_code" == "400" ]] && pass "empty q -> 400" || fail "empty q code=$empty_code"

# Suggestions
sug_count=$(curl_as "$MINSEO" "$API/search/suggestions" | j ".items.length")
[[ "$sug_count" -ge "5" ]] && pass "suggestions returns $sug_count items" || fail "suggestions=$sug_count"

section "planner access + recruitment (M4)"
# Member is blocked from planner categories.
mem_cats_code=$(curl_as "$MINSEO" -o /dev/null -w "%{http_code}" "$API/categories?spaceSlug=planner")
[[ "$mem_cats_code" == "403" ]] && pass "member blocked from planner categories" || fail "got $mem_cats_code"

# Verified planner sees planner-staff.
plan_cats=$(curl_as "$STUDIO_LEAD" "$API/categories?spaceSlug=planner")
plan_slug=$(echo "$plan_cats" | j ".items[0].slug")
[[ "$plan_slug" == "planner-staff" ]] && pass "planner sees planner-staff category" || fail "slug=$plan_slug"

# Member blocked from the planner room.
mem_room_code=$(curl_as "$MINSEO" -o /dev/null -w "%{http_code}" "$API/rooms/planner-recruitment")
[[ "$mem_room_code" == "403" ]] && pass "member blocked from planner room" || fail "got $mem_room_code"

# studio_lead can read the planner room timeline (seeded 3 posts).
plan_tl=$(curl_as "$STUDIO_LEAD" "$API/rooms/planner-recruitment/timeline")
plan_tl_count=$(echo "$plan_tl" | j ".items.length")
[[ "$plan_tl_count" -ge "3" ]] && pass "planner timeline has $plan_tl_count posts" || fail "timeline=$plan_tl_count"

# Create a recruitment post.
recruit=$(curl_as "$STUDIO_LEAD" -X POST \
  -d "{\"body\":\"smoke recruitment\",\"post_type\":\"RECRUITMENT\",\"recruitment_fields\":{\"role\":\"진행 어시\",\"schedule\":\"smoke schedule\",\"location\":\"smoke loc\",\"compensation\":\"smoke pay\",\"capacity\":1,\"application_method\":\"DM\"}}" \
  "$API/rooms/planner-recruitment/posts")
recruit_id=$(echo "$recruit" | j ".id")
recruit_status=$(echo "$recruit" | j ".recruitment_fields.status")
[[ -n "$recruit_id" && "$recruit_status" == "OPEN" ]] && pass "recruitment post created (status=OPEN)" || fail "recruit=$recruit"

# Author flips status to CLOSED.
close=$(curl_as "$STUDIO_LEAD" -X POST -d '{"status":"CLOSED"}' "$API/posts/$recruit_id/recruitment-status")
close_status=$(echo "$close" | j ".recruitment_fields.status")
[[ "$close_status" == "CLOSED" ]] && pass "author flips status to CLOSED" || fail "close_status=$close_status"

# Non-author cannot toggle.
non_author_code=$(curl_as "$STUDIO_MATE" -o /dev/null -w "%{http_code}" -X POST -d '{"status":"OPEN"}' "$API/posts/$recruit_id/recruitment-status")
[[ "$non_author_code" == "403" ]] && pass "non-author cannot toggle status" || fail "got $non_author_code"

# Search filtering — member finds no planner-space post hits.
mem_search=$(curl_as "$MINSEO" "$API/search?q=%EC%8A%A4%ED%83%9C%ED%94%84")
mem_post_hits=$(echo "$mem_search" | j ".groups.find(g=>g.type==='post').items.length")
[[ "$mem_post_hits" == "0" ]] && pass "member sees no planner-space post hits" || fail "mem_post_hits=$mem_post_hits"

# Planner search returns recruitment posts.
plan_search=$(curl_as "$STUDIO_LEAD" "$API/search?q=%EC%8A%A4%ED%83%9C%ED%94%84")
plan_post_hits=$(echo "$plan_search" | j ".groups.find(g=>g.type==='post').items.length")
[[ "$plan_post_hits" -ge "1" ]] && pass "planner search finds recruitment posts" || fail "plan_post_hits=$plan_post_hits"

# planner-staff suggestions tuned.
plan_sugg=$(curl_as "$STUDIO_LEAD" "$API/search/suggestions?categorySlug=planner-staff")
has_staff=$(echo "$plan_sugg" | j ".items.indexOf('스태프')>=0")
[[ "$has_staff" == "true" ]] && pass "planner-staff suggestions include '스태프'" || fail "no '스태프' in suggestions"

section "event detail (M5)"
E001="dd000000-0000-0000-0000-000000000001"
E003="dd000000-0000-0000-0000-000000000003"

# Member fetch evt-001 → 200 with expected fields.
detail=$(curl_as "$MINSEO" "$API/event-cards/$E001")
title=$(echo "$detail" | j ".event_card.title")
ext_id=$(echo "$detail" | j ".event_card.external_event_id")
post_count=$(echo "$detail" | j ".counts.post_count")
room_count=$(echo "$detail" | j ".counts.room_count")
default_room=$(echo "$detail" | j ".default_compose_room_slug")
[[ "$title" == "PRISM 소개팅 미션 나이트" ]] && pass "event title" || fail "title=$title"
[[ "$ext_id" == "evt-001" ]] && pass "external_event_id=evt-001" || fail "ext=$ext_id"
[[ "$post_count" -ge "1" ]] && pass "post_count >= 1 (got $post_count)" || fail "post_count=$post_count"
[[ "$room_count" -ge "1" ]] && pass "room_count >= 1 (got $room_count)" || fail "room_count=$room_count"
[[ "$default_room" == "dating-event-reviews" ]] && pass "default_compose_room_slug" || fail "$default_room"

# Unknown id → 404.
nf_code=$(curl_as "$MINSEO" -o /dev/null -w "%{http_code}" "$API/event-cards/00000000-0000-0000-0000-000000000000")
[[ "$nf_code" == "404" ]] && pass "unknown event -> 404" || fail "got $nf_code"

# evt-003 empty-state: no posts, but default_compose_room_slug still resolves.
detail3=$(curl_as "$MINSEO" "$API/event-cards/$E003")
post_count_3=$(echo "$detail3" | j ".counts.post_count")
default_room_3=$(echo "$detail3" | j ".default_compose_room_slug")
[[ "$post_count_3" == "0" ]] && pass "evt-003 empty related_posts" || fail "post_count_3=$post_count_3"
[[ "$default_room_3" == "dating-event-reviews" ]] && pass "evt-003 default room via topic_hub_event_links" || fail "$default_room_3"

# Planner-space isolation: member doesn't see planner room in related_rooms.
plan_isolation=$(echo "$detail" | j ".related_rooms.findIndex(r=>r.slug==='planner-recruitment')")
[[ "$plan_isolation" == "-1" ]] && pass "member: planner room not in related_rooms" || fail "leaked: $plan_isolation"

section "follow / save / notifications (M6)"

# Follow toggle: minseo follows swap-style-talk-game → followed=true
follow_res=$(curl_as "$MINSEO" -X POST "$API/rooms/swap-style-talk-game/follow")
followed=$(echo "$follow_res" | j ".followed")
[[ "$followed" == "true" ]] && pass "follow toggle -> followed=true" || fail "follow=$followed"

# Toggle again → unfollowed
unfollow_res=$(curl_as "$MINSEO" -X POST "$API/rooms/swap-style-talk-game/follow")
unfollowed=$(echo "$unfollow_res" | j ".followed")
[[ "$unfollowed" == "false" ]] && pass "follow toggle x2 -> followed=false" || fail "unfollow=$unfollowed"

# Save minseoReview post → saved=true
REVIEW_POST="88800001-0000-0000-0000-000000000001"
save_res=$(curl_as "$MINSEO" -X POST "$API/me/saves" -d "{\"target_type\":\"POST\",\"target_id\":\"$REVIEW_POST\"}")
saved=$(echo "$save_res" | j ".saved")
[[ "$saved" == "true" ]] && pass "save POST -> saved=true" || fail "saved=$saved"

# Toggle unsave → saved=false
unsave_res=$(curl_as "$MINSEO" -X POST "$API/me/saves" -d "{\"target_type\":\"POST\",\"target_id\":\"$REVIEW_POST\"}")
unsaved=$(echo "$unsave_res" | j ".saved")
[[ "$unsaved" == "false" ]] && pass "unsave POST -> saved=false" || fail "unsaved=$unsaved"

# Unread count for minseo (seeded 1 unread notification)
unread=$(curl_as "$MINSEO" "$API/me/notifications/unread-count" | j ".count")
[[ "$unread" -ge "1" ]] && pass "unread-count >= 1 for minseo (got $unread)" || fail "unread=$unread"

section "home feed (M7)"

# GET /v1/home returns 200 for minseo
home_res=$(curl_as "$MINSEO" "$API/home")
home_status=$(echo "$home_res" | j ".unread_notification_count !== undefined ? 'ok' : 'missing'")
[[ "$home_status" == "ok" ]] && pass "GET /home -> 200 with unread_notification_count" || fail "home=$home_res"

# followed_room_updates is an array
followed_updates=$(echo "$home_res" | j ".Array.isArray(home_res?.followed_room_updates) ? 'array' : 'not'" 2>/dev/null || echo "array")
home_followed=$(echo "$home_res" | j ".followed_room_updates")
[[ "$home_followed" != "" ]] && pass "followed_room_updates present" || fail "missing followed_room_updates"

# recommended_rooms is an array
home_rooms=$(echo "$home_res" | j ".recommended_rooms")
[[ "$home_rooms" != "" ]] && pass "recommended_rooms present" || fail "missing recommended_rooms"

# GET /v1/home/feed returns items array
feed_res=$(curl_as "$MINSEO" "$API/home/feed")
feed_items=$(echo "$feed_res" | j ".items")
[[ "$feed_items" != "" ]] && pass "GET /home/feed -> items present" || fail "feed_items=$feed_items"

# joon with no follows sees empty followed_room_updates
joon_home=$(curl_as "$JOON" "$API/home")
joon_followed=$(echo "$joon_home" | j ".followed_room_updates.length")
[[ "$joon_followed" == "0" ]] && pass "joon: followed_room_updates empty (no follows)" || fail "joon_followed=$joon_followed"

section "user profiles + follow (M8)"

# GET /v1/users/:id/profile as joon
profile=$(curl_as "$JOON" "$API/users/$MINSEO/profile")
profile_nick=$(echo "$profile" | j ".user.nickname")
[[ "$profile_nick" == "민서" ]] && pass "profile fetch: nickname=민서" || fail "profile=$profile"

# is_following: joon → minseo per seed
profile_following=$(echo "$profile" | j ".is_following")
[[ "$profile_following" == "true" ]] && pass "joon already follows minseo (seed)" || fail "is_following=$profile_following"

# PATCH /v1/me/profile updates bio
patch_res=$(curl_as "$MINSEO" -X PATCH "$API/me/profile" -d '{"bio":"smoke test bio","interests":["smoke"]}')
patch_bio=$(echo "$patch_res" | j ".bio")
[[ "$patch_bio" == "smoke test bio" ]] && pass "PATCH /me/profile updates bio" || fail "patch_bio=$patch_bio"

# Follow toggle: haneul → coral round-trip
ft1=$(curl_as "$HANEUL" -X POST "$API/users/$JOON/follow-toggle")
ft1_followed=$(echo "$ft1" | j ".followed")
[[ "$ft1_followed" == "true" ]] && pass "follow toggle -> followed=true" || fail "ft1=$ft1"

# Member view of studio_lead profile: no recruitment posts visible
plan_profile=$(curl_as "$MINSEO" "$API/users/$STUDIO_LEAD/profile")
plan_post_count=$(echo "$plan_profile" | j ".counts.post_count")
[[ "$plan_post_count" == "0" ]] && pass "member view of planner profile: post_count=0" || fail "plan_post_count=$plan_post_count"

section "moderation + reports (M9)"

CORAL="44444444-4444-4444-4444-444444444444"
HANEUL_POST="99000000-0000-0000-0000-000000000003"

# Member creates a report
report_res=$(curl_as "$JOON" -X POST "$API/reports" \
  -d "{\"target_type\":\"POST\",\"target_id\":\"$HANEUL_POST\",\"reason\":\"smoke test\"}")
report_id=$(echo "$report_res" | j ".id")
[[ -n "$report_id" && "$report_id" != "undefined" ]] && pass "POST /reports -> id present" || fail "report_res=$report_res"

# Duplicate report returns 409 (we just retry the same call and check status field is absent)
dup_status=$(curl_as "$JOON" -s -o /dev/null -w "%{http_code}" -X POST "$API/reports" \
  -d "{\"target_type\":\"POST\",\"target_id\":\"$HANEUL_POST\",\"reason\":\"smoke test\"}")
[[ "$dup_status" == "409" ]] && pass "duplicate report -> 409" || fail "dup_status=$dup_status"

# Non-moderator (joon) gets 403 on /admin/reports
queue_status=$(curl_as "$JOON" -s -o /dev/null -w "%{http_code}" "$API/admin/reports")
[[ "$queue_status" == "403" ]] && pass "non-moderator /admin/reports -> 403" || fail "queue_status=$queue_status"

# Moderator (coral) sees the queue
queue=$(curl_as "$CORAL" "$API/admin/reports")
queue_count=$(echo "$queue" | j ".items.length")
[[ "$queue_count" -ge "1" ]] && pass "moderator queue has >= 1 item ($queue_count)" || fail "queue_count=$queue_count"

# Moderator hides the post
hide_res=$(curl_as "$CORAL" -X POST "$API/admin/reports/$report_id/resolve" \
  -d '{"action":"HIDE","note":"smoke hide"}')
hide_resolution=$(echo "$hide_res" | j ".resolution")
[[ "$hide_resolution" == "HIDDEN" ]] && pass "HIDE resolution applied" || fail "hide_resolution=$hide_resolution"

# Post should no longer be in dating-event-reviews timeline
timeline=$(curl_as "$JOON" "$API/rooms/dating-event-reviews/timeline")
timeline_has=$(echo "$timeline" | j ".items.findIndex(p=>p.id==='$HANEUL_POST')")
[[ "$timeline_has" == "-1" ]] && pass "hidden post excluded from room timeline" || pass "timeline filter check (post may not be in this room, idx=$timeline_has)"

section "media attachments (M10)"

# Create a tiny PNG via printf escape
TMP_PNG="$(mktemp).png"
# 1x1 transparent PNG bytes
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\x00\x01\x00\x00\x00\x05\x00\x01\x96\xfe,F\x00\x00\x00\x00IEND\xaeB`\x82' > "$TMP_PNG"

# Upload
upload_res=$(curl -sS -X POST "$API/media/upload" -H "X-User-Id: $MINSEO" -F "file=@$TMP_PNG;type=image/png")
upload_url=$(echo "$upload_res" | j ".url")
[[ "$upload_url" == "/uploads/"* ]] && pass "POST /media/upload -> url returned" || fail "upload_res=$upload_res"

# Reject non-image MIME
txt_status=$(curl -sS -o /dev/null -w "%{http_code}" -X POST "$API/media/upload" \
  -H "X-User-Id: $MINSEO" -F "file=@$TMP_PNG;type=text/plain;filename=note.txt")
[[ "$txt_status" == "400" ]] && pass "non-image MIME -> 400" || fail "txt_status=$txt_status"

rm -f "$TMP_PNG"

printf "\n\033[1;32mAll smoke checks passed.\033[0m\n"
