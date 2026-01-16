# Daily Question Frontend Contract

This document defines how the frontend should interact with the Daily Question (DQ) feature.

## Overview

The DQ feature uses a hybrid approach:
- **Firestore**: Real-time status updates (NOT_STARTED/ACTIVE/CLOSED)
- **REST API**: Actions (start, submit) and data fetching (results, archives)

## Timing (UTC)

For any DQ date X:
| Status | Time Range | User Action |
|--------|------------|-------------|
| NOT_STARTED | 2AM → 12PM UTC | Cannot participate |
| ACTIVE | 12PM → 2AM+1 UTC | Can start and submit |
| CLOSED | After 2AM+1 UTC | View results only |

---

## Frontend Workflow

### 1. App Entry / Main Screen

```
1. Call GET /daily_question/archive/week
   → Returns: { items: {"2024-12-15": true, ...}, today: "2024-12-17" }
   
2. Build DQ carousel using items (8 cards: today + past 7 days)
   - Mark cards based on participation (items[date])
   - Today's card shows live status

3. Subscribe to Firestore: daily_questions/{today}
   → Listen for status and results_ready changes
```

### 2. When Status Changes to ACTIVE

User can now press "Start" on today's DQ card.

### 3. User Starts DQ

```
POST /daily_question/start
→ Returns:
  {
    question: { question_uid, text, category, difficulty, unit_hint },
    answer_deadline_utc: "2024-12-17T14:30:30",
    seconds_to_answer: 30
  }
```

Frontend starts a local timer (`seconds_to_answer`).

### 4. User Submits Answer

```
POST /daily_question/answer
Body: { answer: { number: 42.5, unit: "meters" } }
→ Returns: { submitted: true, score: 85.5, message: "..." }
```

**Important**: The frontend MUST submit before the timer expires. The backend provides some grace period but frontend should treat the deadline as firm.

### 5. After Submission

1. Return to main screen
2. Re-fetch `GET /archive/week` to update participation status
3. Today's card shows "Submitted" state

### 6. When results_ready Becomes True

When the Firestore document's `results_ready` changes to `true`:

1. End subscription to old "today" document
2. Re-fetch `GET /archive/week` (the `today` field will be the new date)
3. Subscribe to the new "today" document
4. If user participated in the old date, add old date to local `unseen_results` set (show indicator on card)

### 7. Viewing Results

```
GET /daily_question/results/{date}
→ Returns: question, correct_answer, user_answer, user_score, user_rank, leaderboard
```

Call this when user taps on a DQ card to view detailed results.

### 8. Archive Calendar View

```
GET /daily_question/archive/month?year=2024&month=12
→ Returns: { items: {"2024-12-01": false, "2024-12-02": true, ...}, today: "2024-12-17" }
```

---

## Firestore Document Schema

### Document: `daily_questions/{YYYY-MM-DD}`

```typescript
interface DQDocument {
  question_uid: string;
  status: "NOT_STARTED" | "ACTIVE" | "CLOSED";
  window_start: Timestamp;  // When ACTIVE phase starts
  window_end: Timestamp;    // When CLOSED phase starts
  results_ready: boolean;   // True when ranks are computed
}
```

Frontend should subscribe to this document and react to:
- `status` changes → Update UI state
- `results_ready` → Trigger archive refresh

---

## API Endpoints Summary

| Endpoint | When to Call |
|----------|--------------|
| `GET /archive/week` | App launch, after submission, when results_ready |
| `GET /archive/month?year=&month=` | Opening calendar view |
| `POST /start` | User taps "Start" (only when ACTIVE) |
| `POST /answer` | User submits answer |
| `GET /results/{date}` | User taps card to view results |

---

## Error Handling

| HTTP Code | Meaning | Frontend Action |
|-----------|---------|-----------------|
| 404 | No DQ for date | Show "No question" UI |
| 409 | Already started/submitted/closed | Show appropriate message |
| 409 | "Not yet active" | Wait for ACTIVE status |
| 409 | "Deadline passed" | Show timeout message |

---

## State Management Tips

1. **Maintain `unseen_results` set**: Dates where user hasn't seen results yet. Clear when user views.

2. **Carousel function**: Consider a single function that:
   - Fetches `archive/week`
   - Subscribes to `today` document
   - Ends other subscriptions

3. **Timer management**: Start timer on `/start` response, submit automatically if timer expires.

4. **Offline handling**: Cache last known archive state, show stale indicators.

---

## Unified DQ Screen with Results Bottom Sheet

The DQ screen (`DailyQuestionScreen`) serves both question-taking and results viewing:

### Screen States

| State | Input Widgets | Bottom Sheet | Handle Text |
|-------|--------------|--------------|-------------|
| Taking question | Enabled | Hidden | - |
| Submitted (pending) | Disabled | Visible, collapsed | "Results in Xh Xm" (muted) |
| Results ready | Disabled | Visible, can drag | "Results ready!" (success) |
| Results seen | Disabled | Visible, can drag | "Results seen" (muted) |

### Navigation

All DQ card taps navigate to `DailyQuestionScreen`:
- **Active + not participated**: Start question flow
- **Active + participated**: Show submitted state with pending results. **Important**: Navigation should NOT pass `questionDate` so the screen can detect participation via `hasParticipatedToday` and show the submitted view without needing to load question data.
- **Closed/Past**: Show results view with expanded sheet

### Results Seen Tracking

The `unseen_results` set is stored in the controller. Call `markResultsSeen(date)` when:
1. User expands the results bottom sheet
2. User navigates to a past DQ

### Countdown Timer

For "Results in X" display:
- Read `window_end` from Firestore once (via `DQDocument`)
- Use local timer to update countdown every minute
- No continuous Firestore polling required
