# Recovery Score Improvements – Implementation Plan

This plan implements the improvements identified in the recovery score analysis. It is ordered to avoid breakage and keep the project consistent. Each phase is testable before moving on.

---

## Pre-Implementation: Consistency Check

### Current assumptions to preserve

| Area | Current behavior | Do not break |
|------|------------------|--------------|
| **MetricCard** | Heart rate: shows `metric.score` with "BPM" (expects raw BPM). Sleep duration: `metric.score` is 0–100, displayed as hours via `* 8/100`. HRV: shows `metric.score` with "ms" (today this is 0–100, so display is misleading; fix can be separate). | Keep heart rate metric’s `score` as BPM for display, or add a display path for BPM. |
| **RecoveryScore** | Persisted as `RecoveryScoreData` (no heartRateScore/trainingLoadScore; placeholders on decode). stressScore persisted and used in `getRecoveryRecommendations`. | Any new fields must be optional or have decode defaults. Don’t remove stressScore without replacing its use in recommendations. |
| **History** | `recoveryScoreHistory` sorted by date then time-of-day; chart uses `sortedHistory` (by date). `getAverageRecoveryScore(forDay:)` only needs same-day filter. | Fixing same-day sort order does not change API; chart and averages still work. |
| **PostActivityCooldown** | Computes adjustment 0–100; not read by `RecoveryMetrics`. UI shows cooldownPercentage/cooldownDescription but they are hardcoded to 100 / "Fully recovered". | Wiring cooldown into the score is additive; no removal of existing code required. |
| **Recommendations** | Use `overallScore`, `sleepScore`, `hrvScore`, `stressScore`. | Changes to how overall/sleep/hrv are computed are fine; stressScore must remain available (or be derived) for stress recommendation. |

### Files that touch recovery score (for regression testing)

- **Models:** `RecoveryMetrics.swift`, `PostActivityCooldown.swift`, `ActivityManager.swift`, `ActivityRecommendations.swift`
- **Views:** `DashboardView.swift`, `TodayView.swift`, `SettingsView.swift`
- **Components:** `MetricCard.swift`, `RecoveryHistoryChart.swift`, `ScoreRing.swift`
- **Persistence:** UserDefaults keys `recoveryScoreHistory`, `processedActivityIDs`
- **Notifications:** `AppDelegate.swift`, `NotificationManager.swift` (read `overallScore` and `scoreDescription`)

---

## Phase 1: Low-Risk Fixes (No Formula or Persistence Changes)

### 1.1 Fix time-of-day sort order

**Goal:** Same-day history entries sort correctly by all 12 `TimeOfDay` values.

**File:** `Mend/Models/RecoveryMetrics.swift`

**Changes:**

- Define a single ordered array of all 12 `RecoveryScoreData.TimeOfDay` cases (e.g. `earlyMorning` → `lateNight`) in chronological order.
- In `generateHistoricalRecoveryScores`, replace the sort’s `timeOrder: [.evening, .noon, .morning]` with this full array and compare by index.
- In `saveCurrentScoreToHistory`, use the same full order for same-day comparison.

**Consistency:** `recentHistory` in `RecoveryHistoryChart` sorts by `$0.date < $1.date` only; chart and `getAverageRecoveryScore(forDay:)` are unchanged. No persistence format change.

**Test:** Generate history with multiple times per day; confirm order is chronological within each day.

---

### 1.2 Document heart rate representation and centralize inversion

**Goal:** Single, clear place where “recovery score from heart rate” is computed; avoid future misuse of raw BPM as 0–100.

**File:** `Mend/Models/RecoveryMetrics.swift`

**Changes:**

- In `updateRecoveryScore()`, extract the heart-rate contribution into a private helper, e.g. `private func heartRateRecoveryScore(from metric: MetricScore) -> Int`, which returns `max(40, 100 - metric.score)` and add a one-line comment that `heartRateMetric.score` is stored in BPM.
- Add a short comment above `_heartRateMetric` assignment (real and simulated paths) that the stored value is BPM for display; recovery weighting uses the helper.

**Do not:** Change `MetricScore` or store heart rate as 0–100 in the metric (would break MetricCard which shows `score` as BPM).

**Test:** Existing behavior unchanged; unit test or manual check that overall score is identical before/after.

---

### 1.3 Stress: document and keep (no formula change)

**Goal:** Clarify that stress is not part of the overall score; avoid breaking recommendations.

**Files:** `Mend/Models/RecoveryMetrics.swift`, optionally `Mend/Views/HelpCenterView.swift`

**Changes:**

- In `updateRecoveryScore()`, add a comment: “stressScore is not used in the weighted overall score; it is stored for recommendations and future use.”
- Optionally add a FAQ or in-app copy: “Stress is reflected in recommendations when relevant; the main score focuses on HR, HRV, sleep, and training load.”

**Do not:** Remove `stressScore` from `RecoveryScore` / `RecoveryScoreData` or from `getRecoveryRecommendations` (stressScore < 60).

**Test:** No behavior change; recommendations still show “Manage Stress” when stressScore < 60 (e.g. poor recovery simulation).

---

## Phase 2: Stable Denominator and Missing Data

### 2.1 Fixed weight set and neutral imputation

**Goal:** Overall score always uses the same five components (HR, HRV, sleep duration, sleep quality, training load) with fixed weights so the meaning of “recovery” doesn’t change when data is missing.

**File:** `Mend/Models/RecoveryMetrics.swift`

**Changes:**

- In `updateRecoveryScore()`:
  - Define a fixed `totalWeight = 5+4+3+2+2` (16) and always use it.
  - For each metric, if present use its (possibly inverted) score; if missing use a neutral value, e.g. `75`.
  - Compute `weightedTotal` for all five (using 75 where a metric is nil), then `overallScore = weightedTotal / 16`.

**Compatibility:** Same inputs produce the same score when all metrics exist. When some are missing, score will change (smoother, more comparable across days). No API or persistence changes.

**Test:** With all data, compare old vs new score (should match). With one metric turned off (e.g. no sleep), confirm score is in a sensible range and no crash.

---

### 2.2 Training load when no history

**Goal:** When there are no activities in the last 28 days, treat training load as “unknown” rather than “optimal.”

**File:** `Mend/Models/RecoveryMetrics.swift`

**Changes:**

- In `calculateTrainingLoadScore()`: when `avgWeeklyLoad == 0`, return a neutral value (e.g. 75) as today, but set the description via a new branch in `getTrainingLoadDescription(score:)` for this case, e.g. “Insufficient activity data to assess training load. Add activities to get a more accurate recovery score.”
- Optionally pass a flag or use a sentinel (e.g. score 75 with a specific description) so the UI could later show “Based on 4 of 5 metrics” if desired.

**Consistency:** `ActivityManager.calculateTrainingLoad(forDays: 28)` already returns 0 when there are no activities; we only change the description and keep score 75 so Phase 2.1’s denominator stays fixed.

**Test:** Clear or mock no activities; confirm description reflects “insufficient data” and score remains 75 for that component.

---

## Phase 3: Personal Baselines (HR and HRV)

### 3.1 Heart rate baseline (14–28 days)

**Goal:** Score resting HR relative to the user’s own baseline instead of a fixed “100 − BPM.”

**File:** `Mend/Models/RecoveryMetrics.swift`

**Changes:**

- In `loadHealthKitData()` (real-data path), after building `heartRateMetrics`, compute a baseline: e.g. 14- or 28-day average (excluding today), with valid range 40–120 BPM.
- When creating `_heartRateMetric`, compute a 0–100 score from current vs baseline: e.g. if current &lt; baseline → good (score &gt; 80); if current &gt; baseline → scale down. Keep storing **BPM** in `metric.score` for MetricCard display.
- In `updateRecoveryScore()`, use the new helper from 1.2: instead of `max(40, 100 - heartRateMetric.score)`, use a **baseline-based recovery score** stored elsewhere. So you need either:
  - A separate `heartRateRecoveryScore: Int` (0–100) on `RecoveryMetrics` (or inside a small state struct) set when building metrics and read in `updateRecoveryScore()`, or
  - Store the 0–100 value in a new optional property on `MetricScore` (e.g. `recoveryScore: Int?`) and use it in weighting while keeping `score` as BPM for display.

**Recommendation:** Add `recoveryScore: Int?` to `MetricScore`. When nil, `updateRecoveryScore()` falls back to current inversion. When set (for HR and optionally others), use it for weighting. MetricCard continues to use `score` and units for display.

**Compatibility:** MetricCard only uses `score` and title; adding optional `recoveryScore` does not break existing callers. Decoded history still uses placeholders for heartRateScore; no persistence change for RecoveryScoreData.

**Test:** With 2+ weeks of HR data, baseline should differ from 100−BPM; score should reflect “better/worse than your average.”

---

### 3.2 HRV baseline (28 days)

**Goal:** Score HRV relative to the user’s 28-day distribution so “good” is personalized.

**File:** `Mend/Models/RecoveryMetrics.swift`

**Changes:**

- When building `_hrvMetric` from real data, compute 28-day baseline (average and optionally min/max or percentiles) from `taggedHRVMetrics` (excluding today).
- Derive a 0–100 score from current vs baseline (e.g. current &gt;= baseline → 70–100; current &lt; baseline → scale down to a floor of 30). Keep the same formula style as today but driven by 28-day baseline instead of 7-day average if desired, or keep 7-day and add 28-day for a smoother baseline.
- Store this in `_hrvMetric.score` (already 0–100). **Display:** MetricCard currently shows HRV `score` with "ms" suffix, which is wrong (score is 0–100). As part of this phase, either:
  - Add an optional `displayValue: Double?` to `MetricScore` and use it in MetricCard for HRV (and later for HR if needed), showing "ms" from raw data, or
  - Pass raw HRV (ms) in the metric’s `description` or `dailyData` and have MetricCard for HRV show "X/100" like sleep quality instead of "X ms".

**Recommendation:** Add `displayValue: Double?` to `MetricScore`. For HRV, set `score` = 0–100 (recovery score), `displayValue` = raw ms. MetricCard: if `displayValue != nil` for HRV, show `displayValue` with "ms"; else show `score` with "/100". This fixes the current HRV display bug and keeps scoring consistent.

**Compatibility:** All existing `MetricScore` initializers must set `displayValue = nil`. All creation sites remain valid. Sample metrics and RecoveryHistoryChart previews use nil and still display as today.

**Test:** Confirm HRV card shows ms when displayValue is set, and overall recovery score uses the baseline-based 0–100 score.

---

## Phase 4: Align Historical Generation With Live Score

**Goal:** Historical scores use the same weighting and, where possible, the same rules as the live score.

**File:** `Mend/Models/RecoveryMetrics.swift`

**Changes:**

- In `generateHistoricalRecoveryScores`:
  - Use the same weights (5,4,3,2,2) and the same total weight (16).
  - For each day, compute per-metric values from aggregates (already have heartRateByDate, hrvByDate, sleepByDate, sleepQualityByDate). For training load we don’t have historical activity load per day in this function; keep using a fixed neutral (75) for history, or optionally fetch activities and call the same training-load logic by date (larger change).
  - Use the same inversion for HR (max(40, 100 - hr)) and the same sleep formula (sleepHours*100/8, capped). For HRV, use the same normalization as live (e.g. 28-day or 7-day average for that point in time if available; otherwise min(100, max(30, hrv*100/80))).
  - Remove or gate random time-of-day variation behind the same developer flag; by default generate without random noise so history is comparable to live.
- When a metric is missing for a day, use 75 for that slot (consistent with Phase 2.1).

**Compatibility:** Only affects newly generated history (on empty history or “Regenerate” in Settings). Existing persisted history is not migrated; user can force regeneration to get new logic.

**Test:** Force regenerate history; compare a recent day’s historical score with the live score for that day (they should be close if data is the same).

---

## Phase 5: Post-Activity Cooldown in Score

**Goal:** After a workout, the displayed recovery score is reduced and then recovers over time.

**Files:** `Mend/Models/RecoveryMetrics.swift`, optionally `Mend/Models/PostActivityCooldown.swift`

**Changes:**

- In `RecoveryMetrics.updateRecoveryScore()`:
  - After computing `overallScore` from the weighted average, get `PostActivityCooldown.shared.updateCooldownAdjustment()` (and ensure it’s called so the adjustment is up to date).
  - Apply: `let adjustedScore = (overallScore * cooldownAdjustment) / 100` and use `adjustedScore` (clamped 0–100) when setting `currentRecoveryScore.overallScore`.
  - Store the **unadjusted** score somewhere if you want to show “Base: 72, after recent workout: 58” in the UI later; for now, storing only the adjusted score is enough.
- Ensure `processActivity` is called when activities are added (already done in ActivityManager or wherever activities are persisted). Ensure `updateCooldownAdjustment` is called when loading metrics (e.g. from `loadHealthKitData` or `updateRecoveryScore`).

**Compatibility:** Notifications and dashboard show `currentRecoveryScore.overallScore`, which will now reflect cooldown; no API change. History: when we append to history we save the adjusted score (current behavior), so past scores already reflect whatever was displayed; no migration.

**Test:** Add a high-intensity activity; open app and confirm score drops; wait or mock time passage and confirm score moves back toward base.

---

## Phase 6: Sleep and Training Load Refinements

### 6.1 Non-linear sleep duration scoring

**Goal:** Best score in 7–9 h; slight penalty for &gt;9 h.

**File:** `Mend/Models/RecoveryMetrics.swift`

**Changes:**

- Add a private helper, e.g. `private func sleepDurationScore(hours: Double) -> Int`, returning 0–100:
  - &lt; 4 h: low score (e.g. linear 0–50);
  - 4–7: ramp up;
  - 7–9: peak at 100;
  - &gt; 9: slight taper (e.g. 95 at 10 h, 90 at 11 h).
- Use this helper everywhere we currently set sleep metric score or use sleep in the overall score: real-data path, simulated paths, poor-recovery path, and historical generation (sleep duration component).

**Compatibility:** `_sleepMetric.score` and `recoveryScore.sleepScore` remain 0–100; MetricCard and recommendations still use sleepScore. No persistence format change.

**Test:** Simulate 6 h, 8 h, 10 h; confirm 8 h is best and 10 h is slightly lower.

---

### 6.2 Training load “insufficient data” (optional UI)

**Goal:** If desired, show “Based on 4 of 5 metrics” when training load is neutral due to no activities.

**Files:** `Mend/Models/RecoveryMetrics.swift`, `Mend/Views/DashboardView.swift` or `TodayView.swift`

**Changes:**

- In `RecoveryMetrics`, add a computed property or method, e.g. `metricReadiness() -> (included: Int, total: Int)` or `missingMetricNames() -> [String]`, that reports which components had real data vs neutral imputation.
- In the view that shows the recovery score, optionally display a footnote like “Based on 5 of 5 metrics” or “Based on 4 of 5 metrics (training load unknown).”

**Compatibility:** Additive; no change to score calculation or persistence.

---

## Phase 7: Optional and Future Work

- **Stress in formula:** If a stress signal is added later (e.g. from HRV trend or questionnaire), add a weight and include it in the fixed denominator (and adjust totalWeight).
- **HRV display bug (no baseline):** If Phase 3.2 is deferred, still fix MetricCard so HRV shows “X/100” when `displayValue` is nil and score is 0–100.
- **Migration:** No automatic migration of old history is planned; users can use “Regenerate historical scores” in Settings to get new logic.

---

## Implementation Order and Risk Summary

| Phase | Description | Risk | Breaks if skipped |
|-------|-------------|-----|--------------------|
| 1.1 | Time-of-day sort | Low | No |
| 1.2 | HR inversion helper + docs | Low | No |
| 1.3 | Stress docs | None | No |
| 2.1 | Fixed denominator + neutral imputation | Low | No |
| 2.2 | Training load “insufficient data” description | Low | No |
| 3.1 | HR baseline | Medium (new logic) | No |
| 3.2 | HRV baseline + displayValue | Medium (MetricScore API) | No |
| 4 | Historical alignment | Low | No |
| 5 | Cooldown in score | Low | No |
| 6.1 | Non-linear sleep | Low | No |
| 6.2 | Readiness UI | None | No |

Recommended sequence: 1 → 2 → 4 → 6.1 → 5, then 3.1 and 3.2 (with MetricScore `displayValue` and MetricCard updates), then 6.2. This keeps formula and display consistent and avoids doing baseline work before the denominator and history are stable.

---

## Regression Checklist (Before Release)

- [ ] Dashboard and Today show a single recovery score and metric cards; no crashes.
- [ ] MetricCard: heart rate shows BPM; sleep duration shows hours; sleep quality and training load show 0–100 or pts; HRV shows ms or /100 per Phase 3.2.
- [ ] Notifications and AppDelegate still use `overallScore` and `scoreDescription(for:)`.
- [ ] Recommendations (activity and recovery) still run and use overallScore, sleepScore, hrvScore, stressScore as expected.
- [ ] Recovery history chart loads and displays; “Regenerate historical scores” runs without error.
- [ ] With simulated data (normal and poor recovery), scores and descriptions remain plausible.
- [ ] Post-activity cooldown (if Phase 5 done): adding an activity and reopening app shows a reduced score that recovers over time.
- [ ] UserDefaults: `recoveryScoreHistory` still encodes/decodes; no new required keys for existing users (optional keys are fine).
