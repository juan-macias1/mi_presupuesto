# BEHAVIOR_DESIGN.md

How Mi Presupuesto helps you close the gap between knowing what to do with money and actually doing it.

## What this document is

This is the product philosophy file. It defines the principles that guide every design decision in Mi Presupuesto — from button colors to notification timing to the conversational tone of the AI coach. It is meant to outlive any single feature or screen: when in doubt about how something should work, these principles answer first.

It is also the file we point to when explaining what makes Mi Presupuesto different from a generic budget tracker. A budget tracker shows you numbers. Mi Presupuesto is designed to change behavior.

## Behavior design vs. dark patterns

There is a real ethical line between behavior design and manipulation, and this project sits firmly on one side of it.

**Behavior design** means giving the user tools that help them act on the goals they have already set for themselves. The user is the one who decided they want to get out of debt, save for an emergency fund, stop buying things they later regret. The app's job is to make that easier. The user hires the app to defeat their own short-term impulses on behalf of their long-term self.

**Dark patterns** mean using psychological techniques against the user's stated interests, usually to extract money or attention for the product's benefit. Hidden subscriptions, fake urgency timers, social pressure to share, gamification that drives addiction.

The same psychological mechanisms can serve either purpose. Loss aversion can be used by an insurance company to scare you into a policy you don't need, or by Mi Presupuesto to make you feel the cost of an unnecessary purchase in terms of delayed debt freedom. The mechanism is identical. The direction is opposite.

This document is the commitment to direction. Every technique listed here is in service of helping the user do what they already want to do.

## The foundational principle: debt-first design

Before the eight specific principles, one principle frames all of them.

Mi Presupuesto is built assuming the user has debt and that getting out of debt is the central problem. This is the realistic situation for most users in Colombia and most of Latin America. Average consumer debt is significant; financial education is scarce; access to credit cards and "buy now, pay later" schemes is aggressive.

Debt-first design means:

- The debt screen is visually distinct from the rest of the app. Red FAB, red CTA, urgent color language. It does not blend in with the rest of the interface; it stands out.
- The dashboard, when in "attack mode" (debt present), should foreground the debt situation visually. Other information takes second place.
- Every income or expense entry, where possible, should also show its impact on the projected debt-freedom date. The user should not be able to look at their numbers without being reminded of when they will be free.
- The AI coach begins conversations by remembering the debt mode. Recommendations are biased toward debt acceleration when the situation calls for it.
- Notifications, when in debt mode, lean toward debt-related reminders rather than generic budgeting tips.
- The "payment velocity" section, when implemented, should let the user simulate different debt repayment scenarios visually. "If you add 100,000 COP per month, you save 6 months and 240,000 in interest."

The opposite of debt-first design is treating debt as one more category alongside groceries and entertainment. That is what most budgeting apps do. It does not work for the user who is drowning.

## The eight principles

### 1. Pre-commitment

People are more likely to do something they have committed to in advance. Asking yourself "do I want to spend on X?" in the moment is hard because the impulse is strong. Asking in advance, while calm, is easy.

**Application in Mi Presupuesto:**

- Goals are pre-commitments. When the user creates a savings goal with a deadline, they are committing the future version of themselves to a specific path. The app then enforces the commitment with reminders and progress visibility.
- When implemented, the "monthly plan" should let the user set spending limits per category at the start of the month. These are pre-commitments. Going over later requires conscious override.
- The "fixed expenses" classification (gastos fijos) is a soft pre-commitment: by tagging an expense as fixed, the user is saying "this is non-negotiable" and that label becomes part of the budgeting math.

**Status:** Partially implemented (goals exist; monthly category limits do not yet).

### 2. Loss framing

Humans hate losing what they have more than they enjoy gaining the equivalent. A loss of 100,000 COP hurts more than a gain of 100,000 COP feels good. This is well-documented (Kahneman, prospect theory).

**Application in Mi Presupuesto:**

- Every expense the user logs should be reframed in terms of what is being lost: not just "350,000 in restaurants this month" but "350,000 that is not paying down your card" or "350,000 = 11 days less to debt freedom."
- The dashboard should expose the cost of small recurring expenses projected over time. A daily coffee at 7,000 COP is 2,555,000 per year — that framing changes behavior more than the daily number.
- Avoid framing expenses purely as gains ("you saved X by buying on sale"); favor framing as net loss against the goal.

**Status:** Aspirational. The dashboard currently shows raw numbers. Loss framing must be designed into the visual language progressively.

### 3. Identity over goal

People sustain change better when they see it as part of who they are, not as a task they are doing. "I am a person who saves" is more durable than "I am trying to save."

**Application in Mi Presupuesto:**

- The AI coach (Fin) should address the user in terms of identity over time. Not "you saved 200,000 this month" but "you are becoming someone who keeps track of their money. Three months in a row now."
- Milestones should be framed as identity unlocks. Three months of consistent logging is not "consistency streak: 90 days"; it is "you are now in the top 10% of Colombians by financial awareness."
- Avoid streak counters that frame the user as "trying to maintain X." Frame them as evidence of who they already are.

**Status:** To be implemented when Fin becomes active. The visual app does not yet use identity language.

### 4. Asymmetric friction

Make the action you want easy. Make the action you do not want require deliberate effort. Default behavior wins because most people do not change defaults.

**Application in Mi Presupuesto:**

- Logging an expense should take seconds. The "+" button is large and reachable; categories are auto-suggested from history; the keyboard opens directly to numeric input.
- Going over a self-set spending limit should require an explicit override, not a silent accept. "You said you would not spend over 500,000 in restaurants this month. You are about to. Are you sure? (Yes / Adjust limit / Cancel.)"
- Withdrawing from a savings goal should require a few seconds of friction — a confirmation screen explaining the impact. Adding to a savings goal should be one tap.

**Status:** Partially implemented. The "+" flow is fast. The override flow on spending limits does not yet exist because spending limits do not yet exist.

### 5. Immediate feedback

Behavior change is reinforced by feedback that arrives close to the action, not weeks later. Monthly bank statements are too slow to change behavior. Daily dashboards are better. Real-time impact estimates are best.

**Application in Mi Presupuesto:**

- Every logged expense should immediately update the dashboard score and the projected debt-freedom date. The user sees the consequence of the action seconds after taking it.
- Confirmation dialogs after expense entry should include a one-line summary of impact: "this expense costs you 2 days of debt freedom" or "this expense puts you over the restaurant category limit."
- Notifications should arrive on the same day as the behavior they refer to, not in a weekly summary.

**Status:** Foundation present (the dashboard recalculates instantly; the brain has caching to make this fast). The visual "impact statements" still need to be added.

### 6. Future-self visualization

People discount the future heavily by default. Showing the future user (the one who will benefit from saving now) closes the gap.

**Application in Mi Presupuesto:**

- The debt-freedom projection should be visible on every screen, not just in a deep menu. "Debt-free by March 2028" should feel like a person waiting on the other side, not an abstract number.
- Savings goals should show progress in terms of "you are now X% of the way to being able to do Y." The Y matters more than the percentage.
- Long-term simulations ("if you keep this rate for 5 years, you will have...") should be one tap away from the dashboard.

**Status:** Partially implemented. The debt module calculates a freedom date. The visualization of "future you" is not yet built.

### 7. Implementation intentions

A goal becomes more achievable when it is converted into "if X happens, then I will do Y." Specific triggers paired with specific responses. This is well-documented behavior science (Peter Gollwitzer).

**Application in Mi Presupuesto:**

- When a user creates a savings goal, the app should optionally ask "when would you like to add to this? At each paycheck? Every Sunday? When you finish a debt?" Then it sets up reminders aligned with the trigger.
- The notification engine, when expanded, should support condition-based triggers: "if I spend over 80,000 in restaurants this week, remind me of my goal."
- The chat with Fin can be used to set up implementation intentions verbally and have them encoded as rules.

**Status:** Aspirational. The notification engine currently only does daily reminders.

### 8. Closing rituals

Behavior changes that are reinforced by a closing moment — a small ritual that marks the end — stick better than open-ended ones. The "monthly close" of accounting is older than apps; it works because it forces reflection.

**Application in Mi Presupuesto:**

- A monthly closing screen, available on the last day of each month, should walk the user through: how did the month go vs. the plan, what worked, what slipped, what to commit to for next month. The user types or selects from prompts. The output is stored as a journal entry.
- Closing the day with a one-tap "movements logged" confirmation reinforces the habit of logging.
- When a goal is completed or a debt is paid off, the app should make a moment of it — not just a small toast, but a screen that says "you did this" and lets the user share it if they want.

**Status:** Not implemented yet. The "monthly close" is one of the most distinctive features the app could offer once data is flowing.

## What we deliberately avoid

This is as important as what we include.

### Shame and guilt

We do not use shame-based language. We do not write notifications like "you failed your budget again" or "you have been spending too much." Shame is a poor long-term motivator; it produces avoidance, not change. Users who feel shamed by their finance app delete the finance app.

### False urgency

We do not invent urgency that is not real. No countdown timers that pressure decisions. No "this is your last chance" framing. No artificial scarcity. If something is genuinely time-sensitive (a recurring expense is about to charge), we say so plainly. If it is not, we do not pretend it is.

### Easy override of self-set limits

When the user sets a spending limit on themselves and then tries to exceed it, the override should require deliberate action — not because we want to block them, but because we want to honor what they told us they wanted. A budget app that lets you exceed your limits silently is not helping you, it is just keeping a record.

### Comparison to other users

We do not show "users like you spend X on Y." Social comparison can be motivating in some contexts but in personal finance it tends to either shame people who are behind or encourage spending in people who see themselves as above average. The right comparison is always to yourself: your past, your goals, your trajectory.

### Gamification that drives addiction

We use light gamification (progress bars, milestones) but we do not design for compulsive checking. No daily streaks that punish missing a day. No leaderboards. No virtual currencies. The goal is not to make the user spend more time in the app; the goal is to make the user have better financial outcomes.

### Selling user data

This is not a behavior design decision, but it belongs here as the final commitment. We do not and will not monetize by selling user data. The user trusts us with their financial information. That trust is the product.

## Connection to the broader vision

Mi Presupuesto is the foundation for an eventual custom Colombian financial LLM. That LLM, when it exists, will be trained on real conversations between users and Fin, on real anonymized financial trajectories, on the actual patterns of how Colombians manage money.

The behavior design principles in this document determine what kind of LLM that will be. If we apply these principles well, the LLM will be a coach: someone who helps users do what they have already decided to do, with patience and personalized context. If we abandoned these principles, the LLM would just be another product trying to extract attention.

The bet of this project is that there is a market for the first kind. Users who want a coach, not a casino. Coaches are scarce. Casinos are everywhere.

This file is the commitment to building the first kind.

---

*This document is living. As Mi Presupuesto evolves and we learn what works and what does not from real users, principles may be revised, added, or refined. The version in `main` branch is the current canonical version. Historical versions are in git history.*
