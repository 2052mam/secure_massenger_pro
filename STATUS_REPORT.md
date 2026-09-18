# Status Report — 5 Requested Changes

Branch: `arena/01a0b453-secure-massenger-pro` (pushed to GitHub)
Backend test suite: **189 passed** (baseline was 170 → 19 new tests added)

---

## 1. Telegram-style polls & quizzes for groups/channels — Done

**Backend**
- New models `Poll`, `PollOption`, `PollVote` (`backend/app/models/poll.py`), wired into
  `models/__init__.py`, `Message.poll_id` and `services/schema_upgrade.py` (auto-migrates
  existing databases, no manual step needed).
- New blueprint `backend/app/api/polls.py` mounted at `/api/v1/polls`:
  - `POST /polls/` create — question ≤300 chars, 2–10 options ≤100 chars each,
    `poll_type: regular|quiz`, `is_anonymous`, `allows_multiple_answers`,
    `explanation`, `close_at`, `reply_to_id`. Returns a normal message payload.
  - `POST /polls/<id>/vote` `{option_ids: [...]}` — multi-answer honoured.
  - `POST /polls/<id>/retract` — regular polls only.
  - `POST /polls/<id>/close` — author or chat owner/admin.
  - `GET /polls/<id>/voters` — who chose what (non-anonymous polls only; anonymous → 403).
- Quiz semantics match Telegram: exactly one correct option, single answer, the answer is
  **final** (re-vote/retract → 409), and results stay hidden until the viewer answers or
  the quiz closes. Regular polls always show a live tally and tapping your own option again
  retracts the vote.
- Poll payloads are embedded by `serialize_messages`, so polls arrive through the normal
  message stream, long-polling and forwarding (a forwarded poll copies with a zeroed tally).
- Permission checks go through `chat_permissions` — channel posting rules apply as usual.
- Tests: `backend/tests/test_polls.py` (12 tests).

**Flutter**
- `lib/data/models/poll_model.dart`, `lib/presentation/widgets/chat/poll_bubble.dart`
  (percent bars, chosen/correct markers, voter avatars, close/retract actions, voters sheet),
  `lib/presentation/screens/chat/create_poll_screen.dart` (composer with add/remove options,
  quiz toggle, anonymity, multi-answer, explanation).
- `message_bubble.dart` renders polls; `chat_screen.dart` has attach-menu entries for
  **Poll** and **Quiz**; the created poll merges into history immediately.
- Chat list, push notifications and media labels now show `📊 <question>` for poll messages.
- Tests: `test/models/poll_model_test.dart` (7 tests).

## 2. Unregistered phone numbers go to sign-up, no code sent — Done (critical)

**Backend** (`backend/app/api/auth.py`)
- `POST /auth/request-phone-code` now returns `200 {registration_required: true}` for an
  unknown or never-verified number — **no SMS is sent and no `verification_id` is issued**,
  so a code can never reach an unregistered number.
- Known numbers keep the previous behaviour: `202` with the challenge.
- New `POST /auth/check-phone` → `{registered, registration_required, mobile_number,
  masked_mobile_number}` so the client can pre-check a number.
- Note: this intentionally trades the old anti-enumeration uniform response for the
  requested Telegram behaviour.
- Tests: `backend/tests/test_phone_auth.py` (9 tests).

**Flutter**
- `login_screen.dart::_submitPhone` reads `registration_required` (and treats a missing
  `verification_id` as the same case) and pushes `RegisterScreen` with a snackbar instead of
  the code screen. Button relabelled `ادامه` ("Continue"), hint text updated.
- `RegisterScreen` accepts `initialMobileNumber` and pre-fills it, so the user never retypes.
- Tests: `test/auth/login_registration_redirect_test.dart` (3 widget tests covering
  redirect, missing-id fallback and the normal registered path).

## 3. Saving other users' profile pictures — Done

- `MediaDownloadService.downloadMedia` gained `mediaId`/`chatId`/`messageId`, a cache-first
  path and a `_writeToDownloads` helper (saves into the device Downloads/Pictures folder).
- `profile_photos_screen.dart`: appbar **download** button (`download-profile-photo`) saving
  the currently visible photo of the gallery, with progress and result snackbars.
- `user_profile_screen.dart`: appbar **save** button (`save-profile-photo`), shown only when
  the other user's privacy setting (`showProfilePhoto`) permits and an avatar exists.
- `photo_viewer_screen.dart` saves through the same path and now also feeds the local vault.

## 4. Chat-list search now finds groups — Done

**Backend** (`backend/app/api/users.py`, `/users/search`)
- The `chats[]` result now includes groups (not just channels) as
  `{id, chat_type, title, username, avatar_url, is_member}`; chats you belong to are listed
  first, then public suggestions. Private chats are hidden from non-members, deleted chats
  excluded. Tests: `backend/tests/test_search.py` (5 tests).

**Flutter**
- New `lib/core/utils/chat_search.dart` with `normalizeSearchText` / `chatMatchesQuery` /
  `filterChats`: Arabic→Persian letter folding (ي→ی, ك→ک, …), diacritic/ZWNJ/tatweel
  stripping and Persian/Arabic digit normalisation, so "کارگروه ۲" and "karگروه 2" both match.
- `chat_list_screen.dart` gained a real in-place search: an in-appbar text field, and while
  searching it hides the folder bar/banners/stories and **merges archived chats into the pool**
  and bypasses folder filtering — so a group is found no matter which folder or archive it
  sits in. The old magnifier that jumped to global search is kept as a separate button.
- `search_screen.dart` no longer blindly POSTs `add-member`: it respects `is_member`, opens
  chats you already belong to directly, shows a "Join" affordance otherwise, and uses the
  correct `chat_type` (group icon vs channel icon) when opening.
- Tests: `test/chat/chat_list_search_test.dart` (9 tests).

## 5. Local on-device media vault — Done (crucial)

- New `lib/data/services/media_cache_service.dart`: a singleton vault storing binaries as
  `<mediaId>__<fileName>` under `<appDocuments>/media_cache/`, with a persisted `index.json`
  that is automatically **rebuilt from the files on disk** if it is missing or corrupt.
  API: `init`, `entries`, `lookup`, `fileFor`, `hasCachedSync`, `storeOutgoing`, `storeBytes`,
  `bytesFor`, `totalBytes`, `remove`, `clear`, `formatBytes`.
- Initialised in `lib/main.dart` right after `StorageService.init()`.
- **Sending**: every upload in `chat_screen.dart` (photo/video, file, voice, video note,
  audio, GIF source) goes through `_uploadAndCache`, which copies the file into the vault the
  moment it is uploaded — independent of whether the recipient ever downloads it.
- **Receiving/viewing**: `MediaDownloadService` is cache-first and cache-filling, and
  `bytesFor` falls back to the API only when nothing is cached, storing whatever it fetched.
  So once seen, content stays viewable, savable, re-sendable and forwardable even if the
  server loses the file entirely.
- **User-visible control**: new *Offline media storage* screen
  (`settings/offline_media_screen.dart`, reachable from Settings) listing every stored item
  with its size, a total, per-item delete and a guarded "clear all". The vault is never
  cleared automatically — only the user can wipe it.
- Tests: `test/media/media_cache_test.dart` (8 tests, incl. survival of the source file being
  deleted, restart persistence, corrupt-index recovery, and "server lost the file" reads).

---

## Verification notes

- Backend: full `pytest` suite run after every step — **189 passed**, no regressions.
- Flutter: the sandbox has no network access to `storage.googleapis.com` or `pub.dev`, so the
  Flutter SDK could not be installed and `flutter analyze` / `flutter test` could not be run
  here. Dart changes were reviewed by hand and checked for structural/brace balance; 27 new
  Dart tests were written against the new code and the existing widget test was updated for
  the new login button label. Please run `flutter pub get && flutter analyze && flutter test`
  locally once to confirm.
