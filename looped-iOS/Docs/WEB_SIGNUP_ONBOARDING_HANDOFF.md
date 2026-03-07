# Web Signup + Onboarding Handoff

This handoff details how to add full **web signup + onboarding** parity with current iOS behavior, while enforcing a web-specific verification rule:

- Web supports **email verification only**.
- Web does **not** support photo ID verification in onboarding.

It includes routing/state machine logic, UI states, back navigation restrictions, API contracts, and the finish-profile setup step.

## 1) Product + Technical Scope

### What web needs to add

1. Add account creation (`sign up`) in auth flow (web currently only has sign-in).
2. Implement full onboarding-v2 flow after auth:
   - profile setup
   - verification info
   - org selection
   - verification choice/path
   - email verification
   - specialization selection (major/field)
   - completion/finalize
3. Add verification capability on web (email only).
4. Add post-onboarding “Finish setting up your profile” prompt (edit profile completion step).

### What web must not do

1. No photo-ID capture/upload flow in onboarding.
2. No camera/multipart photo verification path from onboarding.
3. No alternate onboarding logic that bypasses backend `onboarding-v2` contract.

## 2) Current iOS Truth (Use as Source of Truth)

Primary sources:

- `Views/AuthView.swift` (navigation stack + onboarding routing)
- `ViewModels/AuthViewModel.swift` (identity/bootstrap/gating/update calls)
- `Views/AuthViews/*` (screen-level UI/validation/controls)
- `ViewModels/CommunityEmailVerificationViewModel.swift` (email verification lifecycle)
- `Views/Shared/Profile/FinishProfileSetupView.swift`
- `ViewModels/FinishProfileSetupViewModel.swift`
- `Views/AuthView.swift` `OnboardingRoutingResolver`

### Top-level auth gating in app shell

The app behavior is:

1. Not authenticated -> auth/onboarding entry UI.
2. Authenticated + onboarding incomplete -> onboarding flow.
3. Authenticated + onboarding complete -> main app.
4. Authenticated + onboarding complete + profile completion prompt requested -> show finish-profile modal.

Equivalent web shell should follow the same gating order.

## 3) Backend Contract (Keep As-Is)

### Identity + gating

- `GET /v1/me` -> includes:
  - `provisioned`
  - `onboarding_complete`
  - `onboarding_step`
  - `onboarding_stage_v2`
  - `onboarding_context`
  - `profile_completion`

### Onboarding-v2 endpoints

- `POST /v1/users/me/onboarding-v2/info-screen/viewed`
- `PUT /v1/users/me/onboarding-v2/org`
- `PUT /v1/users/me/onboarding-v2/verification-choice`
- `POST /v1/users/me/onboarding-v2/email-verification/success`
- `POST /v1/users/me/onboarding-v2/specialization`
- `POST /v1/users/me/onboarding-v2/skip-explainer/ack`
- `POST /v1/users/me/onboarding-v2/photo-pending-explainer/ack`
- `POST /v1/users/me/onboarding-v2/finalize`
- `POST /v1/users/me/onboarding-v2/complete-after-community-request`

### Community + verification endpoints

- `GET /v1/communities/search`
- `GET /v1/communities/recommended`
- `GET /v1/communities/{id}/domains`
- `POST /v1/communities/{id}/verification/start`
- `POST /v1/communities/{id}/verification/finish`
- `POST /v1/communities/{id}/follow`
- `POST /v1/communities/{id}/join` (specialization join)

### Finish profile completion

- `PUT /v1/users/me` (save bio/photo/profile fields)
- `POST /v1/me/profile-completion/dismiss` (dismiss prompt now/after save)

## 4) Canonical Web State Machine

Use server stage/context as primary truth. Local persisted step is fallback only.

### Core states

1. `auth_entry`
2. `login`
3. `signup`
4. `mfa_challenge` (if required by auth provider)
5. `profile_setup`
6. `verification_info`
7. `org_selection`
8. `verification_intro`
9. `verification_choice` (web still has this state, but only one method: email)
10. `email_verification_enter_email`
11. `email_verification_enter_code`
12. `specialization_selection` (`major` for school, `field` for company)
13. `skip_explainer`
14. `verification_confirmation`
15. `completed`
16. `finish_profile_prompt` (post-onboarding modal)

### Stage mapping from backend (`onboarding_stage_v2`)

- `profile_setup` -> `profile_setup`
- `info_screen`, `verification_info` -> `verification_info`
- `org_selection`, `select_company` -> `org_selection`
- `org_selected` -> if allowed-next says more specific stage, route there; else `verification_intro`
- `verification_intro` -> `verification_intro`
- `verification_choice`, `ways_to_verify` -> `verification_choice`
- `email_verification` -> `email_verification_*` unless already approved + context indicates advancement
- `email_verified`, `specialization_selection`, `specialization_required` -> `specialization_selection` or `verification_confirmation`
- `skip_explainer` -> `skip_explainer`
- `ready_to_finalize`, `specialization_selected` -> `verification_confirmation`
- `completed`, `finalized` -> `completed`

### Context-driven overrides (`onboarding_context`)

Use these regardless of stage when stage is missing/stale:

1. `verification_path == "skip"` -> `skip_explainer`
2. `verification_path == "email"`:
   - status approved + specialization done -> `verification_confirmation`
   - status approved + specialization required -> `specialization_selection`
   - otherwise -> `email_verification_*`
3. approved status with no path + specialization required -> `specialization_selection`
4. approved status with no path + no specialization required -> `verification_confirmation`

### Allowed-next fallback

If `allowed_next_stages_v2` exists, use it to recover from unknown/lagged stage values. Priority:

1. completion/finalize
2. skip explainer
3. specialization
4. email verification
5. verification choice
6. verification intro
7. org selection

## 5) Web-Only Verification Rule (Email Only)

### UI behavior

In onboarding web:

1. Show one verification option only: **Company/Student Email**.
2. Hide photo ID option entirely.
3. Keep stage contract with backend by still setting choice with:
   - `verification_path = "email"`

### Defensive routing for incompatible stage

If backend returns `photo_id_verification` for web:

1. Immediately call `PUT /onboarding-v2/verification-choice` with `"email"` (best effort).
2. Reload identity.
3. Route to email verification state.
4. If still incompatible, show recoverable blocking state: “Verification method not available on web, continue in iOS or retry.”

### Reuse strategy (recommended)

Reuse a single verification flow model for both onboarding and settings/community verification:

- Same email verification component and API calls.
- Same code-entry + resend cooldown + error handling.
- Different mode flags:
  - `mode = onboarding` -> progresses onboarding state
  - `mode = settings` -> updates community verification only
- Capability flags:
  - `availableMethods = ["email"]` on web onboarding
  - can later add other methods without rewriting state machine.

## 6) Screen-by-Screen UX + Logic Contract

### Auth entry (`auth_entry`)

UI:

- `Get Started` -> signup
- Social sign-in options can remain if enabled
- `Already have an account? Log in`

States:

- idle
- loading (auth in progress)
- auth error banner

### Signup (`signup`)

Inputs:

- email
- password

Validation:

- min 8 chars
- at least 1 uppercase
- at least 1 number
- at least 1 special character

Action:

- create auth account
- then fetch identity
- route into onboarding resolver

### Login (`login`)

Inputs:

- email
- password

Actions:

- login
- forgot-password modal/action
- handle MFA challenge state if required

### Profile setup (`profile_setup`)

Inputs:

- username (lowercased; regex `^[a-z0-9_]{3,30}$`)
- first name
- last name
- DOB

Behavior:

- debounce username availability check
- persist local draft while typing
- submit via onboard/update identity endpoints

Back rule:

- No back navigation.

### Verification info (`verification_info`)

Purpose:

- explain posting restrictions by verification status.

Action:

- Continue -> mark info-screen viewed endpoint.

Back rule:

- Back to profile setup allowed.

### Org selection (`org_selection`)

Behavior:

- search + recommended communities (company/school)
- selection required to continue
- optional “request community” path; after success call complete-after-community-request endpoint

Actions:

- on select: persist draft org locally
- on continue: set onboarding org endpoint + follow community best effort

Back rule:

- Back to verification-info allowed.

### Verification intro (`verification_intro`)

Action:

- Continue -> verification choice
- optional skip -> set verification choice `skip`

Back rule:

- Back allowed to org selection.

### Verification choice (`verification_choice`)

Web variant:

- single option card for email verification
- Continue auto-advances to email screen and sends verification-choice `email`

Back rule:

- Back allowed to intro.

### Email verification (`email_verification_enter_email` + `enter_code`)

Enter-email state:

- fetch allowed domains
- local-part + domain picker compose full email
- send code

Enter-code state:

- 6-digit code
- verify code
- resend with cooldown and rate-limit handling
- keep keyboard focus behavior stable

Completion action:

1. finish verification API success
2. mark onboarding email verification success endpoint
3. reload identity and route forward

Retry logic (important):

- if mark-success fails, re-send verification-choice=email and retry mark-success once.

Back rule:

- Back to verification-choice allowed when not in verification-transition lock.
- While verifying/transitioning, disable back and skip controls.

### Specialization selection (`specialization_selection`)

Behavior:

- school -> major picker; company -> field picker
- up to 2 selections
- primary selection submitted via onboarding specialization endpoint
- additional selections joined best effort

Back rule:

- Restrict browser back/gesture pop to prevent looping users into incompatible prior state.
- Keep explicit controlled navigation only.

### Skip explainer (`skip_explainer`)

Behavior:

- explain consequences of skipping verification
- Continue -> ack skip explainer + finalize

Back rule:

- Back goes to verification intro (explicit button only).

### Verification confirmation (`verification_confirmation`)

Behavior:

- terminal onboarding confirmation
- Continue -> finalize onboarding-v2

Back rule:

- No back.

## 7) Back Navigation + Guardrails Summary

Implement these as route guards, not just UI button hiding:

1. `profile_setup`: block backward navigation.
2. `specialization_selection`: block browser back gesture/history pop.
3. `verification_confirmation`: block back.
4. During locked async transitions (`verifying`, `finalizing`, `completing after verification`):
   - disable back, skip, and route changes.
5. If user manually navigates to invalid state URL:
   - resolve using identity + onboarding resolver and redirect to valid screen.

## 8) Local Persistence + Resume

Persist per authenticated user:

1. latest local onboarding step
2. profile draft
3. selected org draft
4. verification method draft (`email` only for web onboarding)

Resume priority on app reload:

1. server `onboarding_stage_v2` + context
2. `allowed_next_stages_v2`
3. server legacy `onboarding_step`
4. sanitized local persisted step
5. default `profile_setup`

Never let local state override an explicit server stage/context.

## 9) Error + Recovery Matrix

### Auth gating responses

Handle these centrally and reroute onboarding:

- `user_not_provisioned`
- `onboarding_incomplete`
- `invalid_onboarding_step`
- `invalid_onboarding_stage`

### Email verification errors

Support explicit UI mapping for:

- `invalid_code`
- `email_mismatch`
- `too_many_attempts`
- `resend_cooldown`
- `email_start_rate_limited_hour/day`
- `email_domain_not_allowed`
- `domains_not_configured`
- `email_in_use`

For `too_many_attempts` or `email_mismatch`, reset to email-entry state and preserve cooldown messaging.

## 10) Styling Contract for Web (Parity Direction)

Use Looped token equivalents, matching auth/onboarding visual language:

### Typography tokens in auth/onboarding

- `loopedHeading`, `loopedHeadingMedium`, `loopedHeadingMedium28`, `loopedHeadingMedium32`
- `loopedSubheadMedium`
- `loopedBody`, `loopedBodyMedium`, `loopedBodyStrong`
- `loopedSubBodyRegular`, `loopedSubBodyMedium`, `loopedSubBodyBold`
- `loopedSmallText`

### Color tokens in auth/onboarding

- `loopedBackground`, `loopedMutedBackground`
- `loopedPrimary`, `loopedSecondary`, `loopedContrast`
- `loopedTextPrimary`, `loopedTextSecondary`
- `loopedError`, `loopedSuccess`
- `loopedWhite`, `loopedBlack`

### Component sizing patterns to mirror

- Primary CTA: height ~52
- Form cards: rounded corners (~14-18)
- Search pills: rounded (~22)
- Verification progress pills in header
- Disabled CTA opacity + non-interactive lock during async transitions

## 11) Finish Profile Setup (Post-Onboarding)

Show a full-screen/modal prompt when:

- `isAuthenticated == true`
- `onboardingComplete == true`
- `profileCompletion.shouldPrompt == true`

Prompt capabilities:

1. Add/change profile photo (optional)
2. Edit bio with character limit
3. Save and continue (update profile + dismiss prompt)
4. Skip for now (dismiss prompt only)

On dismiss action, call:

- `POST /v1/me/profile-completion/dismiss`

On save action, call:

1. media upload (if photo changed)
2. `PUT /v1/users/me`
3. `POST /v1/me/profile-completion/dismiss`

## 12) Suggested Implementation Order

1. Add signup page + validation + auth wiring.
2. Implement web onboarding resolver (port `OnboardingRoutingResolver` behavior).
3. Implement profile setup + org selection screens.
4. Implement email-only verification flow and transitions.
5. Implement specialization and finalization.
6. Add route guards/back restrictions.
7. Add finish-profile prompt and profile completion handling.
8. Add QA suite for resume/recovery/edge transitions.

## 13) QA Cases (Must Pass)

1. Signup -> full onboarding completion path (email verification approved).
2. Existing user with `onboarding_stage_v2` mid-flow resumes at exact state.
3. Email verification rate-limit cooldown shown and enforced.
4. Invalid code + retry behavior works.
5. Skip flow finalizes correctly.
6. Specialization required vs not-required routes correctly.
7. Browser refresh on every onboarding state restores correctly.
8. Browser back restrictions enforced where required.
9. Finish-profile prompt appears only post-onboarding and dismisses correctly.
10. Backend returns unexpected stage -> allowed-next fallback works.

