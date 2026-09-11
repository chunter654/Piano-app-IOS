# Minimalist Piano

A playable piano for iPhone. Portrait only, no instrument picker, no settings
screen. The keyboard gets almost the whole display and the few controls there
are sit on a walnut rail above it.

The app is called **Minimalist Piano** on the App Store and simply **Piano**
under the icon on the home screen. Those two names come from different places
and are meant to differ: the home screen label is `INFOPLIST_KEY_CFBundleDisplayName`
in the project, the store name is a field in App Store Connect.

## The two arrangements

A brass catch at the top right switches between them, and the choice is
remembered.

A first launch opens on the stacked rows. They ask nothing of a new user: the
phone is already in the right position and the heading names the range, where
the single column has to be worked out first. Since the choice is remembered,
anyone who prefers the column meets that default once.

**Single column.** The instrument is turned a quarter turn clockwise. Pitch
runs down the screen, the key fronts face left, and the accidentals reach in
from the right. The note names turn with it, so tilting the phone reads them
upright. A brass slider down the right scrolls a viewport across the whole
88-key piano. The viewport moves continuously rather than in steps, which is
what makes the travel feel smooth; the keys themselves never move relative to
one another. Pinching that same slider zooms, between eight and twenty-four
white keys on screen, holding the middle of the view still. The thumb is sized
from the fraction of the piano in view, so it shrinks as you zoom in and is a
true measure rather than a decorative handle.

The pinch lives on the slider rather than on the keys because the keyboard
tracks every finger separately to make chords and sliding work, and a pinch
there would be read as two notes.

**Stacked.** Two rows of a conventional keyboard, one octave each, with the
lower octave on top. The chevrons either side of the range move a whole octave
at a time, so the rows always start on a C.

Neither arrangement is drawn from a stored layout. Both are generated from a
starting MIDI note, so any range of the piano can be shown and nothing has to
be laid out by hand.

## Playing

The keyboard is a single UIKit view that tracks every finger itself rather than
letting each key handle its own touches. That is what allows a finger to slide
from one key to the next and retrigger cleanly. Held notes are reference
counted, so two fingers on one key release correctly and nothing sticks.

The audio session uses the `.playback` category with `.mixWithOthers`. The app
layers on top of whatever else is playing, so it will not interrupt music, a
video, or navigation.

## The sound

`Piano/Resources/GrandPiano.sf2` is a subset of the **Salamander Grand Piano**
by Alexander Holm, a recording of a Yamaha C5, cut down to a single velocity
layer to keep the app to a sensible size. It is played through an
`AVAudioUnitSampler`, bank 0, program 0.

It is licensed **Creative Commons Attribution 3.0**, which obliges us to credit
it. The full licence travels with the app in
`Piano/Resources/SoundFont-License.txt`, and the App Store description must
carry this line:

> Piano sound: Salamander Grand Piano by Alexander Holm, licensed under
> Creative Commons Attribution 3.0.

## Look

Everything is drawn, not photographed. The walnut grain is generated from a
seeded random source so it is identical on every launch, the keys are aged
ivory and a dark warm brown rather than white and black, and the lettering is
New York, the system serif, which means no font file ships with the app.

The app icon is rendered from those same values. `Tools/IconRenderer` compiles
against the app's own palette, grain generator and keyboard layout code, so the
icon cannot drift away from the instrument it stands for. It shows one octave
pushed down the case with a bar of brass above it, which is the range slider
laid on its side. Repaint it with any simulator booted:

```bash
Tools/IconRenderer/render.sh
```

The margins in it are not arbitrary. iOS masks an icon with a corner radius of
about 0.2237 of the side, and at the keyboard's own inset that arc reaches
0.065 of the side in from the bottom edge, so anything closer loses the corners
of the outer keys.

## Building

Requires Xcode and an iOS 17 device or simulator.

```bash
open Piano.xcodeproj
```

Pick a destination and press Run. To run the tests, press Command U, or:

```bash
xcodebuild -project Piano.xcodeproj -scheme Piano \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

There are 42 of them, covering the layout maths, the range controller, the zoom
limits, and note naming. They are pure model tests with no UI, so they are quick.

### Running on a real iPhone

Xcode must be new enough for the iOS version on the phone. This is stricter
than it sounds: Xcode cannot mount a developer disk image for an iOS release it
predates, and without that it can neither debug nor install. An Xcode two major
versions behind the phone will fail with
`kAMDMobileImageMounterPersonalizedBundleMissingVariantError`, which reads like
a signing problem and is not one.

On the phone, Developer Mode must be on, under Settings, Privacy and Security.

The project signs automatically against team `7YP7MZQN34`. On a new machine,
sign in to Xcode with the same Apple ID and it will issue its own certificate;
nothing needs copying across.

## Layout of the source

| Path | What is in it |
| --- | --- |
| `Piano/Model` | Notes, key geometry, and the controller that owns the visible range |
| `Piano/Keyboard` | The multi-touch surface and the layer that draws one key |
| `Piano/Audio` | The sampler and the audio session |
| `Piano/App` | Theme, wood grain, and the controls on the rail |
| `PianoTests` | Model tests |

The geometry lives in `KeyboardLayout`, which has one function per arrangement
and no knowledge of touches or sound. `KeyboardRangeController` owns both
position models, converts between them when the arrangement changes, and
persists them under `keyboard.viewportPosition`, `keyboard.layoutMode`, and
`keyboard.startNote`.

## The store listing

`StoreListing.md` holds the text of the App Store listing, because the sound's
licence obliges us to credit it wherever the app is distributed and a credit
that lives only in a web form is one nobody can check. `Tools/check-listing.sh`
measures every field against Apple's limits and fails if the credit goes
missing.

The app is priced at $1.99 with nothing to buy inside it.

## Distributing it

Builds ship through Xcode Cloud rather than from a laptop. The workflow
archives on every push to `main` and delivers to TestFlight. It runs on Apple
machines with a current Xcode, which is the only reason this project could be
shipped at all from a 2019 MacBook Air: App Store Connect refuses any upload
built against an SDK older than the current one, and that Mac cannot run an
Xcode new enough to produce it.

Distribution Preparation in the workflow must be set to **App Store Connect**,
not TestFlight Internal Testing Only. The narrower setting produces builds that
external testers cannot be given, whatever App Store Connect is told afterwards.

## Setting up a new machine

1. Install the current Xcode.
2. Clone this repository.
3. Sign in to Xcode under Settings, Accounts, with the Apple ID that owns team
   `7YP7MZQN34`. It issues its own certificate; nothing is copied between
   machines.
4. On the phone, turn on Developer Mode under Settings, Privacy and Security.

Pushing needs a key GitHub recognises. Migration Assistant carries the existing
one across in the keychain; a clean install does not, and needs a new one
generating and adding at github.com/settings/keys.

## Verified on hardware

Confirmed on an iPhone 17 running iOS 26:

- **Touch-to-sound latency.** No perceptible delay between finger and note.

## Not yet verified

Still only exercised in the simulator, where audio timing is not
representative:

- Polyphony under real multi-touch
- Sliding between keys without a note sticking
- Playing over another app's audio on a device
- Behaviour across calls, headphone changes, and interruptions
