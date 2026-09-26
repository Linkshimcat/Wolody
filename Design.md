# Wolody Design System

Figma source: `Wireframes/Wolody.fig`  
Reference exports: `Wireframes/*.png`  
Implementation scope: all exported product screens except `로그인.png`.

## Source of truth

The Figma frames and exported PNGs are the visual source of truth. This document records values measured from the supplied 402 px wide frame exports. If an earlier assistant proposal or an existing Flutter style conflicts with the Figma artwork, follow Figma. Record any implementation compromise here rather than silently changing the design.

Colors below are sampled from the exported frames. The designer confirmed BM Jua for the rounded typeface; the bundled Google Fonts Jua file supplies that typeface locally on device.

## Visual direction

- Dark, near-black blue-gray canvas with slightly lighter navy surfaces.
- Rounded Korean display typography and clear white-on-dark hierarchy.
- Wolody blue for active navigation, links, selection, and settings controls.
- Muted lavender-blue for large primary actions.
- Soft, individually colored emotion cards with 울디's matching face asset.
- Use the supplied transparent character illustrations and SVG icon assets; do not substitute emoji for the emotion portraits.

## Color tokens

| Token | Value | Use |
|---|---|---|
| `background` | `#0D1118` | Main screen background |
| `surface` | `#161E2A` | Home cards, banners, inputs, list rows |
| `surfaceRaised` | `#23262D` | Secondary settings rows and pressed areas |
| `selectorSurface` | `#242D3B` | Emotion carousel cards |
| `surfaceSelected` | `#060B12` | Selected bottom navigation item |
| `outline` | `#303844` | Subtle borders and navigation edge |
| `textPrimary` | `#FFFFFF` | Main labels and headings |
| `textSecondary` | `#858B96` | Supporting labels, dates, empty states |
| `brandBlue` | `#346AE6` | Selected tabs, links, toggles, calendar selection |
| `actionLavender` | `#96A1BF` | Primary CTA backgrounds |
| `emotionHappiness` | `#FFD58A` | 행복 selection and glow |
| `emotionGood` | `#F3A8C7` | 만족 |
| `emotionExcited` | `#FFC36D` | 설렘 |
| `emotionCalm` | `#9DD6C1` | 편안함 |
| `emotionNeutral` | `#FFD58A` | 보통 |
| `emotionSad` | `#91B8E8` | 슬픔 |
| `emotionLonely` | `#AAA6DB` | 외로움 |
| `emotionHurt` | `#C4A6D8` | 서운함 |
| `emotionAngry` | `#E88E8E` | 화남 |
| `emotionFrustrated` | `#E6AA7D` | 답답함 |
| `emotionAnxious` | `#B5A8E8` | 불안 |
| `emotionEmbarrassed` | `#F0A5B7` | 당황 |

Emotion colors tint the selected portrait card and its ambient glow. Keep the underlying screen dark and the card surface neutral navy; do not fill every card with saturated color.

## Typography

Use the platform system sans-serif for body copy, dates, descriptions, and controls. Use **BM Jua** (`Jua` family) selectively for the Wolody wordmark, prominent screen headings, and emotion names where the rounded display style supports the character. The font is bundled at `assets/fonts/Jua-Regular.ttf`; include its OFL license from `assets/fonts/OFL.txt` when distributing the app. Preserve the following visible hierarchy:

| Role | Approx. size | Weight |
|---|---:|---|
| Screen title / main prompt | 22–24 px | Bold |
| Section heading | 20–22 px | Bold |
| Card title | 15–16 px | Semibold |
| Body / button | 14–16 px | Medium |
| Supporting text / date | 11–13 px | Regular |
| Bottom navigation label | 9–10 px | Medium |

## Layout and shape

- Reference frame width: 402 px; primary portrait screens: 874 px high. One tall home-state export is 1194 px high.
- Main content side inset: approximately 24 px; use safe-area insets at the top and bottom.
- Home banner and journal cards: 24 px corner radius; primary buttons: 16–18 px; bottom bar: capsule, about 64 px high.
- Repeated content cards use consistent interior padding and spacing. Let longer notes and keyboard insets scroll rather than clipping.
- Preserve the Figma crop of 울디 art where it intentionally meets a banner edge.

## Shared components

1. **SplashScreen** — centered blue BM Jua wordmark on the dark canvas; hold while local app services initialize, then fade into Home.
2. **WolodyBottomBar** — one capsule with Home, Calendar, My, and Add; selected icon and label turn blue. On iOS 26+ this is the system `UITabBar` (native Liquid Glass, selection platter and press lens, forced dark; My uses the circular profile photo). Older iOS and Android use the Flutter capsule whose selection animates between tabs on tap and tracks horizontal drags.
3. **PrimaryButton** — full-width lavender-blue action with rounded corners and white label.
4. **JournalCard** — mood portrait and labels, timestamp, record section, optional note and photos; tapping opens edit; swiping right reveals the blue edit action and swiping left reveals the red delete action.
5. **WooldyMoodPortrait** — crop one face from `assets/AssetsDesign/EmotionAssets.png` using a consistent head-only frame.
6. **EmotionCarouselCard** — neutral navy card, matching face, mood name, emotion-color outline/check and ambient glow when selected.
7. **ProfileStatCard** — compact metric tile inside the profile surface.
8. **SettingsRow / SettingsSection** — rounded dark rows with icon, label, and blue control/chevron.
9. **TopBar** — consistent back affordance and screen title for secondary flows.

## Implementation additions (no Figma frame yet)

- **Profile edit**: tapping the avatar/nickname row on My page (chevron added) opens a TopBar screen with a 112 px avatar, blue camera badge, "프로필 사진 변경" link, a `surface` nickname field (18 px radius, 10-character limit with counter) and the PrimaryButton "저장하기". The default 울디 avatar sits on a light `#E9ECF3` circle, matching the My page export.
- **Settings routine**: the Figma frame labels both mode buttons "하루 한 번"; the repeat button reads "여러 번". Below the mode buttons, the same `#202329` card holds the routine controls: time rows (label, blue value, blue chevron, opening a dark time-picker sheet), 30분/1시간/2시간/3시간 interval chips (repeat mode), 월–일 weekday chips (`brandBlue` when selected, `#34373D` otherwise, at least one day stays on), and a one-line summary under the card (`#E88E8E` for invalid ranges or more than iOS's 64 pending notifications).
- **Back buttons**: secondary-flow TopBar back buttons use the native Liquid Glass circle (`GlassBackButton`) instead of the flat `#24272F` circle.
- **Home widgets / Live Activity**: always dark, `surface` background, 울디 face crops from `EmotionAssets.png` (writing 울디 when nothing is recorded) with the first mood's color as an ambient glow, `brandBlue` for the recorded check and the "기록하기" capsule. BM Jua is not bundled in the widget extension, so widget headings use the system rounded design.

## Screen flow (from exported source names)

- **Home, empty**: optional record-reminder banner → empty-state journal card with writing 울디 → primary action.
- **Home, recorded**: record-complete banner → journal cards; the taller export represents the scrolled/detail state.
- **Create/edit record**: mood selection → memo/photo entry → save; editing preselects existing moods and content.
- **Calendar**: month navigation → date grid → selected day's journal cards or empty state.
- **My page**: profile/stats → Wolody memories; gear opens Settings.
- **Settings**: notification and lock-screen options → reminder routine controls → deleted records and account management.
- Login is intentionally excluded from this implementation pass.

## Assets

- Raster character art and emotion sprite sheet stay PNG with transparency.
- Use `EmotionAssets.png` for selector portraits; keep each mood's crop, scale, and alignment consistent.
- Use supplied SVGs for simple icons where they can be rendered without changing their paths.
- Photos attached to journal entries remain user content and use `BoxFit.cover` with rounded clipping.

## Fidelity checklist

- Match 402 px reference exports first, then keep layout responsive to other iPhone sizes.
- Compare background/surface values, typography, text wrapping, card geometry, artwork crop, and bottom-bar placement.
- Confirm normal, selected, empty, recorded, keyboard, and dismiss/gesture states.
- Do not force this document's earlier guessed recommendations over the Figma source; update this document when the designer changes a frame.
