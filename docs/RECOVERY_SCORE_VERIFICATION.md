# Recovery Score Changes – Behaviour to Check and Verify

Use this list after implementing the recovery score improvements. Run the app on a device or simulator and confirm each item.

---

## 1. Dashboard & Today view

- [ ] **Dashboard loads** – Opening the app shows the main dashboard without crashing.
- [ ] **Recovery score displays** – The main recovery score ring shows a value 0–100 (or “Loading” then a value).
- [ ] **Metric cards show** – Heart rate (BPM), HRV, Sleep Duration (hours), Sleep Quality (/100), and Training Load (pts) appear when data exists.
- [ ] **Today view** – Today tab shows the same recovery score and metric breakdown; no crash.

---

## 2. Score calculation (fixed denominator & cooldown)

- [ ] **Score with full data** – With HealthKit (or simulated) data for HR, HRV, sleep, sleep quality, and some activities, the overall score is in a plausible range (e.g. 50–90).
- [ ] **Score with missing data** – Turn off one category (e.g. no sleep data) and confirm the score still computes (uses neutral 75 for that component) and doesn’t crash.
- [ ] **Post-activity cooldown** – Add a high-intensity activity (e.g. via Debug in Settings), then open the app: overall score should be **lower** than before. After the expected recovery time (or after “Reset processed activities” and not re-adding the activity), the score should return toward the previous level.

---

## 3. Training load & “insufficient data”

- [ ] **With activities** – After logging workouts in the last 28 days, Training Load card shows a score and the usual description (e.g. “optimal relative to your 28-day average” or “slightly off your optimal range”).
- [ ] **With no activities** – With zero activities in the last 28 days (or after “Reset processed activities” and no new activities), open the app and expand the Training Load card: description should say **“Insufficient activity data to assess training load. Add activities to get a more accurate recovery score.”** Score for that component should still be 75 (neutral).

---

## 4. Sleep duration (non-linear scoring)

- [ ] **7–9 hours** – If last night’s sleep is in the 7–9 hour range, Sleep Duration score should be 100 (or very high).
- [ ] **Short sleep** – With ~5–6 hours, score should be lower (e.g. 70–85 range).
- [ ] **Long sleep** – With 10+ hours, score should be slightly below 100 (e.g. 90–95), not higher than 7–9 h.

*(If using simulated data, adjust simulated sleep hours in code or via a debug control and re-check.)*

---

## 5. History & time-of-day sort

- [ ] **History chart** – Recovery trend (4 weeks) on Dashboard or Today shows points; no crash when tapping or scrolling.
- [ ] **Regenerate history** – In Settings → Developer (or Debug), use “Regenerate historical scores” (or equivalent). Generation completes without error; chart updates.
- [ ] **Same-day order** – If you have multiple scores for the same day (e.g. morning and evening), they appear in chronological order (early morning → late night) in the stored history. *(Optional: inspect in debugger or add a temporary log of `recoveryScoreHistory` after save.)*

---

## 6. Notifications & recommendations

- [ ] **Notification content** – If daily recovery notification is enabled, the body shows “Your recovery score is X. …” with the **current** (cooldown-adjusted) score. No crash when notification is presented.
- [ ] **Activity recommendations** – Today or activity screen shows recommended activities; lower recovery score shows easier options (e.g. Light Walk, Gentle Yoga); higher score shows harder options (e.g. Intervals, Long Run). No crash.
- [ ] **Recovery recommendations** – If stress or sleep is low, “Manage Stress” or “Prioritize Sleep” type recommendations can appear. No crash.

---

## 7. Simulated & poor recovery

- [ ] **Simulated data** – With “Use Simulated Data” on, dashboard shows a plausible score and all metric cards; no crash.
- [ ] **Poor recovery simulation** – With “Simulate Poor Recovery” (and simulated data) on, score is lower and descriptions mention higher RHR, lower HRV, or reduced sleep; no crash.
- [ ] **Toggle off** – Turning simulated/poor recovery off and refreshing shows real (or empty) data; no crash.

---

## 8. Persistence & refresh

- [ ] **After kill** – Force-quit the app and reopen: recovery score and history reload; no crash.
- [ ] **Refresh** – Using pull-to-refresh or “Refresh data” (if present) updates the score; no crash and no infinite loop (e.g. score shouldn’t keep climbing on repeated refresh without new data).
- [ ] **Settings changes** – Changing “Natural daily variations” or regenerating history doesn’t corrupt UserDefaults; app restarts and shows data correctly.

---

## 9. Edge cases

- [ ] **First launch (no history)** – Fresh install or cleared UserDefaults: app loads, may show “No historical data” or generate history; no crash.
- [ ] **No HealthKit permission** – With health data disabled, app still launches; score may use neutral values or simulated data depending on flow; no crash.
- [ ] **Heart rate in BPM** – Metric card for “Resting Heart Rate” shows a value in **BPM** (e.g. 62 BPM), not 0–100.

---

## 10. Quick regression checklist

| Area              | Expected behaviour |
|-------------------|--------------------|
| Dashboard         | Loads, score ring and cards visible |
| Today             | Same score and metrics |
| Notifications     | Body uses current overall score |
| Recommendations   | Activity and recovery lists work |
| History chart     | Displays and regenerates without error |
| Training load     | “Insufficient data” when no activities |
| Sleep             | 7–9 h best; >9 h slightly lower |
| Cooldown          | Score drops after hard workout, recovers over time |
| Simulated data    | Toggles work; poor recovery lowers score |
| Persistence       | Score and history survive app restart |

---

*If any item fails, note the step and the exact behaviour (and any crash log) so the implementation can be adjusted.*
