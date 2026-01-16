# Monetization Plan - The Fermi Game

This document outlines the monetization strategy for The Fermi Game, a mobile trivia app based on Fermi estimation questions.

## Table of Contents
- [Executive Summary](#executive-summary)
- [Recommended Model: Freemium with Limits](#recommended-model-freemium-with-limits)
- [Pricing Tiers](#pricing-tiers)
- [Feature Gates](#feature-gates)
- [Engagement Hooks](#engagement-hooks)
- [Implementation Recommendations](#implementation-recommendations)
- [Alternative Models Considered](#alternative-models-considered)
- [Revenue Projections](#revenue-projections)

---

## Executive Summary

Guesstimate is a unique educational trivia experience with no direct competitors on major app stores. This is an opportunity to establish the category while building a loyal user base. The recommended approach is a **generous freemium model** that prioritizes engagement and virality over aggressive monetization, converting engaged users to premium over time.

> [!IMPORTANT]
> Since the app hasn't launched yet, the strategy should prioritize **user acquisition and engagement** over immediate revenue. Aggressive paywalls early on will hurt growth in a category with no established demand.

---

## Recommended Model: Freemium with Limits

### Core Philosophy

- **Free tier should be fun and complete** - Users must experience the "aha!" moment of Fermi estimation
- **Premium adds convenience and depth** - Not essential, but makes the experience richer
- **Limits should feel natural** - Power users hit them, casual users don't

### Daily Question (DQ) Mode

| Feature | Free Tier | Premium |
|---------|-----------|---------|
| Daily Question participation | ✅ 1 per day | ✅ 1 per day (same) |
| View DQ results/leaderboard | ✅ Unlimited | ✅ Unlimited |
| **Re-attempt older DQs** | ❌ Cannot re-play | ✅ Unlimited past DQ access |
| DQ streak tracking | ✅ Yes | ✅ Yes |
| **Streak protection** | ❌ None | ✅ 1 free freeze per week |

### Party Mode (Private-Only)

> [!NOTE]
> Party mode is **private-only** (invite link required). Public matchmaking was retired.

| Feature | Free Tier | Premium |
|---------|-----------|---------|
| Host games | ⚠️ **2 per week** | ✅ Unlimited |
| Guests per game | ⚠️ **4 max** | ✅ Up to 100 |
| Join games (as guest) | ✅ Unlimited | ✅ Unlimited |
| Bot players | ✅ 2 bots | ✅ All 8 bots |
| **Custom categories** | ❌ Not available | ✅ Create/save custom |
| **Survival mode** | ⚠️ 10-round limit | ✅ Unlimited rounds |

### Profile & Stats

| Feature | Free Tier | Premium |
|---------|-----------|---------|
| XP and level progression | ✅ Yes | ✅ Yes |
| Basic percentile stats | ✅ Yes | ✅ Yes |
| **Detailed analytics** | ❌ Limited | ✅ Full history & insights |
| **Category badges** | Basic badges | Premium exclusive badges |

---

## Pricing Tiers

### Recommended Pricing

| Plan | Price | Billing |
|------|-------|---------|
| Free | $0 | - |
| **Fermi Pro (Monthly)** | $3.99/month | Monthly |
| **Fermi Pro (Annual)** | $29.99/year (~$2.50/mo) | Annual (save 37%) |
| **Lifetime** | $59.99 (one-time) | Lifetime access |

### Lifetime Plan Details

> [!IMPORTANT]
> "Lifetime" means the lifetime of the **service**, not the user. In Terms of Service:
> *"Lifetime access applies while The Fermi Game service remains operational."*

- Industry standard: 3-5+ years of service, or until acquisition
- If shutting down: offer refunds for recent purchasers (last 90 days)
- Provide 30+ days advance notice before any shutdown

### Why This Pricing?

- **$3.99/month** is the "coffee" price point - low commitment for casual users
- **Annual discount** encourages commitment and reduces churn
- **Lifetime option** attracts enthusiasts and early supporters
- Avoids the crowded $9.99+/month tier where users expect more

---

## Feature Gates

### What to Gate (Premium)

✅ **Good candidates for premium gates:**

1. **Re-attempt older DQs** - High value for engaged users, doesn't affect new user experience
2. **Custom category creation** - Power feature for enthusiasts
3. **Streak protection** - Emotional value for streak maintainers
4. **Full analytics/history** - Data nerds will pay for this
5. **Unlimited game hosting** - Active hosts are valuable users
6. **Large guest capacity (100)** - For classrooms, events, parties
7. **All bot personalities** - Fun expansion content

❌ **Do NOT gate these (keep free):**

- Daily Question participation
- Joining games hosted by others (as guest)
- Basic streak tracking
- Core gameplay mechanics
- Basic stats and percentile

### Gate Implementation Notes

| Feature | Recommendation |
|---------|----------------|
| Custom category in Party | Premium-only |
| Survival mode | Free with 10-round limit; Premium unlimited |
| Re-attempting older DQs | Premium-only (high value) |
| Streak freeze | Premium perk (1 per week) |
| Party hosting | Free: 2/week, 4 guests; Premium: unlimited, 100 guests |

---

## Engagement Hooks

To make the game "very attractive and rewarding" while still monetizing:

### 1. Streak System Enhancement

```
Current: Record login streak
Proposed additions:
- Daily streak rewards (XP bonus: +10% per day, max +70%)
- Weekly milestone rewards (badges, profile flair)
- Streak freeze for Premium (1 per week)
- "Streak at risk!" push notification
```

### 2. Competitive Leaderboards

```
- Daily: Top 100 DQ performers
- Weekly: Cumulative DQ performance
- Category-specific: Best in "Science", "Pop Culture", etc.
- Friends: Compare with connected players
```

### 3. Achievement System

```
- Category mastery badges
- Streak milestones (7, 30, 100, 365 days)
- Accuracy badges ("Order of Magnitude Master")
- Social badges ("Party Animal" - host 50 games)
```

### 4. Progressive Unlocks (Free)

```
- New categories unlock with XP/levels
- Bot characters unlock progressively
- Profile customization unlocks
```

### 5. Social Features

```
- Share DQ results (with app store link)
- Invite friends to Party games (referrals)
- Compare stats with friends
- "Challenge a friend" to specific categories
```

---

## RevenueCat Paywall Configuration

The paywall screen dynamically loads content from RevenueCat offering metadata. Configure the following JSON in your RevenueCat dashboard under **Products → Offerings → [Offering] → Metadata**.

### Benefits Schema

```json
{
  "benefits": [
    {
      "name": "Daily Guess",
      "free": {"exists": true, "full": true, "info": "Full Archive"},
      "pro": {"exists": true, "full": false, "info": "Only Today's"}
    },
    {
      "name": "Hosted Parties",
      "free": {"exists": true, "full": false, "info": "2 per Week"},
      "pro": {"exists": true, "full": true, "info": "Unlimited"}
    },
    {
      "name": "Party Guests",
      "free": {"exists": true, "full": false, "info": "Up to 4"},
      "pro": {"exists": true, "full": false, "info": "Up to 20"}
    },
    {
      "name": "No Ads",
      "free": {"exists": true, "full": true, "info": ""},
      "pro": {"exists": true, "full": true, "info": ""}
    }
  ],
  "popular_package": "$rc_annual",
  "promo_text": "Lifetime Offer Ending Soon!"
}
```

### Benefit Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Display name shown in center column |
| `exists` | bool | Whether this tier has the benefit |
| `full` | bool | Whether this tier has full access (true) or limited (false) |
| `info` | string | Optional text shown below the icon |

### Visual Indicators

- `exists=true, full=true` → Green checkmark ✓
- `exists=true, full=false` → Gray dash —
- `exists=false` → Red X ✗

---

## Implementation Recommendations

### Phase 1: Launch (Early Adopter Funding)

Focus on core experience, engagement, and building a passionate early user base:

```markdown
- [ ] Daily Question with streak tracking
- [ ] Party mode (private-only, unlimited during launch phase)
- [ ] Basic stats and leaderboard
- [ ] Share functionality for virality
- [ ] Push notifications for DQ reminder
```

**Monetization:** Early adopter purchases only:
- **Lifetime purchase** at discounted launch price ($39.99 for first 500 users)
- Optional **tip jar / donation** button
- No limits enforced during this phase

> [!TIP]
> Early adopter revenue helps validate demand and seeds positive reviews from committed users.

### Phase 2: Introduce Premium Tiers (4-8 weeks post-launch)

After establishing user base, introduce freemium limits:

```markdown
- [ ] Implement subscription tiers (RevenueCat recommended)
- [ ] Enforce Party limits: 2/week, 4 guests for free tier
- [ ] Gate: Re-attempt older DQs (Premium)
- [ ] Gate: Premium bots (5-8)
- [ ] Introduce streak freeze for Premium
```

### Phase 3: Feature Expansion

New Premium differentiators:

```markdown
- [ ] Custom categories (Premium)
- [ ] Survival mode (10-round free limit; unlimited Premium)
- [ ] Detailed analytics (Premium)
- [ ] Category leaderboards
```

### Authorization Bypass

As mentioned, implement email allowlist for bypass:

```python
# In backend settings
PREMIUM_BYPASS_EMAILS = [
    "*@company.com",  # Internal team
    "reviewer@apple.com",  # App review
    # Add testers, influencers as needed
]
```

---

## Alternative Models Considered

### 1. Ads-Supported Model ❌

**Not recommended** for this app because:
- Breaks the timer-based gameplay flow
- Degrades the "premium brain game" positioning
- Interstitial ads during results would be especially jarring
- Users expect ad-free in education/brain training category

### 2. Pay-to-Win Mechanics ❌

**Avoid entirely:**
- No "hints" or "skips" for purchase
- No boosted scores
- This preserves the integrity of leaderboards and percentiles

### 3. Consumable Purchases ⚠️

**Possible future addition:**
- "Question packs" (themed sets for Party mode)
- "DQ rewinds" (one-time purchase to replay a specific past DQ)

Consider this only after subscription revenue is established.

### 4. Full Paywall After Trial ❌

**Too aggressive** for a new category:
- No established demand for Fermi games
- Users need time to understand and appreciate the format
- Would severely limit viral growth

---

## Revenue Projections

### Conservative Scenario (Year 1)

| Metric | Estimate |
|--------|----------|
| DAU | 5,000 |
| Premium Conversion | 3% |
| Paying Users | 150 |
| Avg Revenue (monthly) | $3.50 |
| **Monthly Revenue** | ~$525 |
| **Annual Revenue** | ~$6,300 |

### Optimistic Scenario (Year 1)

| Metric | Estimate |
|--------|----------|
| DAU | 25,000 |
| Premium Conversion | 5% |
| Paying Users | 1,250 |
| Avg Revenue (monthly) | $3.75 |
| **Monthly Revenue** | ~$4,700 |
| **Annual Revenue** | ~$56,000 |

> [!NOTE]
> These projections assume organic growth only. Viral features (sharing, referrals) and featured placement could significantly accelerate growth.

---

## Key Decisions

### Resolved ✅

| Decision | Resolution |
|----------|------------|
| Party mode type | **Private-only** (invite link required) |
| Free hosting limit | **2 games/week, 4 guests max** |
| Survival mode | **Free: 10-round limit; Premium: unlimited** |
| Launch strategy | **Phase 1 free + early adopter lifetime purchases** |
| Lifetime option | **Yes**, at $59.99 ($39.99 launch discount) |

### Open Questions

> [!NOTE]
> The following may need revisiting based on user feedback post-launch:

1. **DQ re-attempt**: Premium-only, or offer 1 free re-attempt per month?
2. **Pricing validation**: Are users willing to pay $3.99/mo? May need A/B testing.
3. **Phase 2 timing**: 4-8 weeks - adjust based on user growth metrics?

---

## Related Documentation

- [Backend Architecture](apps/fermi-api/docs/ARCHITECTURE.md): Daily Question and Party mode implementation
- [Frontend Architecture](apps/fermi-frontend/docs/ARCHITECTURE.md): UI and state management
- [CI/CD Guide](docs/CICD.md): Deployment infrastructure

---

*Document created: 2024-12-29*
*Last updated: 2024-12-29*
*Status: Approved - Ready for Implementation*
