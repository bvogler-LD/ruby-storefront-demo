# Member Shop demo: infinite scroll vs pagination (LaunchDarkly experiment)

A standalone Rails storefront that shows offer cards on a Shop **subcategory results page**
(`/shop/laptops-and-tablets`) in one of two experiences chosen by a LaunchDarkly string flag:

| Flag value | Role | Experience |
|---|---|---|
| `pagination` | control | exactly 24 cards per page, previous/next/page links |
| `infinite_scroll` | treatment | 24 cards, more loaded as the shopper nears the end |

The app measures real card impressions, card clicks, and whether the shopper reached the final offer,
and sends them to LaunchDarkly server-side with the same context used for flag evaluation.

All offers, merchants, and the demo account are fictional. No real shopper identifiers or data are used.

## Versions and assumptions

- Ruby 4.0.9 (Homebrew, see `.ruby-version`), Rails 8.1.4, SQLite, Puma.
- `launchdarkly-server-sdk` 8.20 (official Ruby server-side SDK; needs Ruby 3.0+).
- JavaScript is plain ES modules served by importmap. No Node build step. Node is only used to run the JS unit tests.
- The machine this was built on only had system Ruby 2.6, so Ruby was installed with `brew install ruby`.
  Gems are installed into `vendor/bundle` (git-ignored).

## Run it

```bash
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"   # if Homebrew Ruby is not already first on PATH
bundle install
bin/rails db:prepare        # creates the SQLite database, runs migrations, seeds 60 offers + demo user
cp .env.example .env        # optional; leave LAUNCHDARKLY_SDK_KEY blank for fallback mode
bin/rails server
```

Open <http://localhost:3000>, choose **Laptops & Tablets**. Readiness page: <http://localhost:3000/status>.

With no SDK key the app runs in **fallback mode**: every shopper gets `infinite_scroll`, nothing is sent
to LaunchDarkly, and the reason is visible in the server log (`[feature_flags] ...`), on `/status`, and in
the developer panel.

## Tests and checks

```bash
bin/rails test                       # 41 tests: rendering, identity, events, rejection of bad requests
node --test test/javascript/*.mjs    # 10 tests: visibility rule and de-duplication
bundle exec rubocop
bundle exec brakeman -q
```

Tests never contact LaunchDarkly. They swap in a recording client at the adapter boundary
(`test/support/recording_flag_client.rb`); contexts are real `LaunchDarkly::LDContext` objects built by the app.

## Demo sign-in

The header has a **Demo sign in** / **Sign out** button. It signs in as the one seeded account
("Demo Shopper") with one click and no password. **This is not authentication** and must not be reused as such.

What to look for:

1. As a guest, note the list style. Reload: it does not change (same guest context).
2. Click **Demo sign in**. The app now evaluates the flag for the signed-in user's context, so the list
   style is that user's own assignment. It may or may not differ from the guest's.
3. Sign out. You are the same guest as before, with the guest's assignment.

Identities are not merged: events before sign-in belong to the guest context, events after to the user context.

In local development a collapsed **Developer: experiment context** panel (bottom right of the list page)
shows the context kind, identity state, a redacted key, the served variation, its source, and a live
impression count. It is not rendered outside `development`.

## LaunchDarkly

### Connect the app

Copy the **server-side SDK key** of the **Test** environment of your LaunchDarkly project
(LaunchDarkly: Project settings → Environments → Test → SDK key) into `.env`:

```
LAUNCHDARKLY_SDK_KEY=<Test environment server-side SDK key>
```

Restart the server. `/status` should report `mode: launchdarkly`. The key is read from the environment only;
it is never logged, rendered, or sent to the browser. Do not use the Production key, a mobile key, or a client-side ID.

### Resources already created through the LaunchDarkly MCP

Created and read back in the demo's LaunchDarkly project, environment `test` ("Test", non-production).
To run this against your own project, create the same resources there:

| Resource | Key | Configuration |
|---|---|---|
| Flag | `shop-offer-list-experience` | string; variation 0 `pagination` (control), 1 `infinite_scroll` (treatment); off variation `infinite_scroll`; targeting **on** in Test (since 2026-11-12), no rules |
| Metric (primary) | `offer-card-clicked` | custom conversion **binary**, event `offer_card_clicked`, higher is better |
| Metric (secondary) | `offer-card-impression` | custom conversion **count**, event `offer_card_impression`, summed per shopper |
| Metric (exploratory) | `offer-list-end-reached` | custom conversion **binary**, event `offer_list_end_reached` |
| Experiment | `shop-offer-list-infinite-scroll-vs-pagination` | on the flag's default rule, randomized by `user` context, 50/50, all three metrics, status **`running`** (started 2026-11-12) |

Notes:

- Flags and metrics are project-level, so the flag also appears in the Production environment, off and
  untouched. The experiment exists only in Test. Nothing was changed in Production.
- No targeting, segments, or audience attributes were added. Everyone who reaches the page is eligible.
- The experiment's hypothesis text is a neutral starting point. Edit it in the experiment design if you want different wording.

### Still manual

The flag is on in Test and the experiment iteration is running, so it is waiting for traffic. What is left:

1. Put the Test SDK key in `.env`, restart, and confirm `/status` shows `mode: launchdarkly`. Until then the
   app stays in fallback mode and the experiment receives nothing.
2. Browse as a guest and as the demo user; check events arrive under the three metrics.
3. To stop, end the iteration in LaunchDarkly (a winning treatment must be chosen) and turn the flag off.

Changing the flag in LaunchDarkly changes the served experience on the next page load. No code change or redeploy.

### Human verification before a real experiment

- **Desktop, mobile, or both?** Which surface a real experiment should target is still to be confirmed.
  This demo is responsive and treats all surfaces the same; no device targeting is configured. Confirm before narrowing.
- Confirm the 50/50 split, the primary metric, and the impression rule below with the experiment owner.
- Confirm how your application's anonymous UID and signed-in visitor ID map onto `ShopperContext` (see below).

## Contexts

All context building is in `app/services/shopper_context.rb`.

| Shopper | Context kind | Key | Other attributes |
|---|---|---|---|
| Signed in | `user` | `User#public_id`, a stable opaque application ID | none |
| Anonymous | `user` | `guest-<uuid>`, random, stored in a signed, HTTP-only, SameSite=Lax cookie (Secure in production) | `anonymous: true` |

- The key is derived on the server on every request. Nothing in a request body or query string can choose it.
- No name, email, phone, or other personal data is sent to LaunchDarkly.
- To adapt for a real storefront, pass the application's anonymous UID as `guest_uid` and the signed-in visitor ID as the
  user's stable ID in `ShopperContext.for`. Nothing else needs to change.

## Events and metrics

| Event key | Sent when | Data | Metric type |
|---|---|---|---|
| `offer_card_impression` | a card was actually seen (rule below); once per offer per shopper session | `{ position }` | conversion count |
| `offer_card_clicked` | shopper pressed **View offer**; recorded in `POST /offers/:id/click` before the redirect | `{ position }` | conversion binary (primary). For total clicks, add a separate count metric on the same event |
| `offer_list_end_reached` | the final available offer in the subcategory got an impression; once per context per session | `{ position }` | conversion binary (exploratory) |

`position` is the card's 1-based ordinal in the list. It is the only event data.

**Impression rule** (`app/javascript/impression_tracker.js`): a card counts when at least 50% of it has been in the
viewport continuously for 1 second while the tab is visible, detected with `IntersectionObserver`. Scrolling away
restarts the timer. Each offer is reported once per page; the server de-duplicates again per shopper session, and
cards already counted are rendered with `data-seen` and not observed. The rule is identical in both experiences.
Tune with `IMPRESSION_VISIBLE_RATIO` and `IMPRESSION_DWELL_MS`.

**End of list** means the same thing in both experiences: the shopper saw the last offer of the subcategory
(position 60 here). In pagination that is the last card of the last page; reaching the bottom of page 1 does not count.

**Correlation.** The list page evaluates the flag first and records, in the server session, which context it was
evaluated for. Event endpoints reject events (HTTP 409) unless that record matches the current context, then track
with that same context. After sign-in, events are refused until the flag has been evaluated for the signed-in context.

**Request protection.** `POST /events/impressions` requires a CSRF token, accepts only an array of 1 to 50 existing
offer IDs, ignores any identity, event name, or position sent by the browser, and is rate-limited to 60 requests
per minute per shopper. The click route redirects only to the app's own offer page.

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `LAUNCHDARKLY_SDK_KEY` | blank | Test environment server-side SDK key. Blank means fallback mode |
| `LAUNCHDARKLY_FLAG_KEY` | `shop-offer-list-experience` | flag key |
| `SHOP_PAGE_SIZE` | `24` | cards per page and per infinite-scroll batch |
| `IMPRESSION_VISIBLE_RATIO` | `0.5` | share of a card that must be visible |
| `IMPRESSION_DWELL_MS` | `1000` | how long it must stay visible |
| `WEB_CONCURRENCY` | `0` | Puma workers. Above 0, each worker re-initializes the SDK (`postfork`) |

## Fallback behavior

| Situation | Served | Events |
|---|---|---|
| No SDK key, or SDK failed to start | `infinite_scroll` | dropped (debug log line) |
| SDK key set but LaunchDarkly unreachable or flag missing | `infinite_scroll` | queued by the SDK |
| Flag returns a value other than the two variations | `infinite_scroll` | sent |
| Flag targeting off | off variation, `infinite_scroll` | sent, not attributed to an experiment |

The app never assigns a variation itself. One SDK client is created per process in
`config/initializers/launchdarkly.rb` and closed at exit.

## Where things are

- `lib/feature_flags*` SDK adapter (`SdkClient`, `NullClient`)
- `app/services/` `ShopperContext`, `OfferListExperience`, `ExperimentEvents`
- `app/controllers/concerns/current_shopper.rb` server-derived identity and session bookkeeping
- `app/controllers/offers_controller.rb`, `events/impressions_controller.rb`, `demo_sessions_controller.rb`, `status_controller.rb`
- `app/javascript/` `impression_tracker.js`, `infinite_scroll.js`, `offer_list.js`
- `db/seeds.rb` 60 offers and the demo user

## Demo-only limitations

- Sign-in is a one-click mock for one seeded user. No passwords, no real authentication.
- Per-session impression de-duplication lives in the cookie session (capped at 500 offers). A real shop would use a server-side store.
- The rate limiter is in-process memory, so limits are per server process.
- The impression endpoint checks that offers exist, not that each one was rendered to this shopper.
- One subcategory, static catalogue, placeholder SVG images, and offer pages that do not lead to a merchant.
- Browsers without `IntersectionObserver` or with JavaScript disabled see the first 24 cards and send no impressions.
