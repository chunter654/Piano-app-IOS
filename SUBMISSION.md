# Getting it submitted

A checklist, in the order the fields block you. Everything here is App Store
Connect unless it says otherwise; the project side is done.

## Before anything else

- [ ] **Paid Applications Agreement active**, under Business. Banking and tax
      details have to be filled in and accepted or the price field stays grey.
      This is the longest lead time on the list, so start it first.

## The build

- [ ] The version has a build attached, and that build was made from the commit
      you mean. Xcode Cloud names the commit on the build's page. Counting
      build numbers tells you nothing: the counter increments on reruns and
      failures too.

## Pages that have to exist

Both are served from this repository. Settings, Pages, source Deploy from a
branch, branch `main`, folder `/docs`. That publishes:

- Support URL: `https://chunter654.github.io/Piano-app-IOS/`
- Privacy Policy URL: `https://chunter654.github.io/Piano-app-IOS/privacy.html`

- [ ] GitHub Pages switched on and both URLs load.
- [ ] The support address in `docs/index.html` replaced with a real one. It
      ships as a placeholder on purpose: Apple needs a contact route that
      works, and this page is the one linked from the store.

## Fields

- [ ] **App Privacy.** Every answer is Data Not Collected. The app makes no
      network requests, has no third-party libraries and asks for no
      permissions, so this is accurate rather than optimistic.
- [ ] **Age rating.** All no.
- [ ] **Price** $1.99, no in-app purchases.
- [ ] **Category** Music.
- [ ] **Copyright**, content rights, and availability.
- [ ] **Name, subtitle, keywords, description** from `StoreListing.md`.
      `Tools/check-listing.sh` measures them against Apple's limits.
- [ ] **The description still ends with the Salamander credit.** That line is a
      condition of the sound's licence, not a courtesy, and a web form is an
      easy place to lose it.
- [ ] **Screenshots** in every size slot marked required. iPhone only: the app
      is `TARGETED_DEVICE_FAMILY = 1`, so no iPad set is needed.
- [ ] **App previews**, 15 to 30 seconds, 886 x 1920 or 1920 x 886.

## Review notes worth writing

Reviewers have to find their way around an app with no labels on its controls.
Something like:

> No account, no setup. The brass button in the top corner switches between the
> two keyboard arrangements. In the single-column view, drag the brass slider
> to move along the piano and pinch it to change the key size. Audio plays over
> other apps by design.

## Already true of the project

- Export compliance is declared in `Piano/Info.plist`, so there is no
  encryption question at upload.
- The icon is 1024 square with no alpha channel.
- The sound's full licence ships inside the app at
  `Piano/Resources/SoundFont-License.txt`.
- 42 tests pass.
