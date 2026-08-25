# SALES EFFECT LIBRARY — INTERNAL ONLY

Status: CANONICAL RESEARCH + EXPERIMENT LIBRARY
Effective: 2026-08-26 JST
Audience: Owner / Zero / AI5 only
Customer-facing: NO — never copy this file wholesale into LP, CM, Store Listing, captions, or customer documentation.

## 1. Objective

Continuously research behavioral-science mechanisms that may improve attention, comprehension, trust, activation, conversion, purchase, use and retention; then test them against actual product/CM/funnel data.

There is no scientifically honest “psychology that guarantees sales.” Therefore the operational target is:

`FIND HIGH-EVIDENCE CANDIDATES -> FORM HYPOTHESIS -> ETHICAL IMPLEMENTATION -> CONTROLLED TEST -> MEASURE -> KEEP/REJECT -> UPDATE LIBRARY`

Never label a mechanism “guaranteed” or “always works.” Context, audience, offer, product quality, channel and implementation can change effects.

## 2. Research priority

Prioritize systematic reviews, meta-analyses, randomized experiments, preregistered studies and high-quality field evidence. Prefer evidence that matches digital products/e-commerce/advertising rather than importing effects from unrelated domains without qualification.

Candidate families to continually investigate include:
- defaults / choice architecture
- salience and attention
- cognitive fluency / processing ease
- choice overload / option complexity
- framing and reference points
- anchoring where honest and relevant
- loss/gain framing where supported
- social proof only when real and verifiable
- trust/uncertainty reduction
- friction / activation energy
- implementation intentions
- goal gradients/progress
- commitment/precommitment
- feedback/reward
- memory/repetition/spacing
- mere exposure / brand familiarity where applicable
- self-efficacy and identity-consistent motivation
- temporal discounting / immediacy
- endowment/ownership effects where legitimately applicable
- price presentation/value framing without deception
- scarcity only when factually real; never fake scarcity

## 3. Initial evidence baseline

The starting literature scan indicates that behavioral interventions are context-dependent rather than guaranteed. A quantitative review of nudging studies reported statistically significant effects in only a subset of interventions and meaningful heterogeneity by category/context; systematic reviews likewise show variable effectiveness and limitations. Choice-overload meta-analysis identifies complexity, task difficulty, preference uncertainty and decision goals as moderators rather than a universal “fewer choices always sells” rule. Digital nudging reviews show that combined strategies can outperform single interventions in some settings, but effects vary by context and user characteristics.

This baseline is deliberately conservative: the library must learn from our own real funnel data rather than converting published averages into promises.

## 4. Experiment record schema

Every tested mechanism gets one record:

```yaml
experiment_id: "EXP-YYYYMMDD-NNN"
product: "<PRODUCT>"
asset_or_surface: "<CM/LP/APP/STORE/etc>"
funnel_stage: "<ATTENTION/COMPREHENSION/PROFILE/LP/CHECKOUT/PURCHASE/RETENTION>"
mechanism:
  domain: "<psychology/behavioral_economics/etc>"
  name: "<mechanism>"
  evidence_strength: "A/B/C"
  source_refs: []
hypothesis: "<IF ... THEN ... BECAUSE ...>"
implementation_a: "<control>"
implementation_b: "<variant>"
primary_metric: "<metric>"
secondary_metrics: []
guardrail_metrics: []
sample_or_exposure: null
start_jst: null
end_jst: null
result:
  status: "NOT_STARTED/RUNNING/WIN/LOSS/INCONCLUSIVE"
  effect_absolute: null
  effect_relative: null
  uncertainty: null
  notes: null
decision: "KEEP/REJECT/RETEST/SEGMENT"
```

## 5. Required funnel data

When technically available, collect per platform + post/creative + variant:
- impressions/views
- 2/3-second hold
- completion/retention
- profile visits
- profile visit rate
- sales-link clicks
- click-through rate
- LP sessions
- checkout starts
- checkout-start rate
- purchases
- purchase conversion rate
- revenue
- refunds
- install/delivery success
- repeat use/retention where applicable

Never convert unavailable data to zero.

## 6. Decision rules

- Do not declare a “winning psychology” from one anecdote or tiny exposure.
- Separate creative quality from mechanism effects where possible.
- Prefer controlled A/B or sequential tests with one major variable changed at a time.
- Record confounds: platform algorithm, time/day, audience changes, organic reach, concurrent edits, price changes, account age, novelty.
- A mechanism that improves views but harms qualified clicks/purchases is not automatically a sales win.
- Optimize toward durable customer value and paid conversion, not vanity metrics alone.
- Re-test winners across products/channels before promoting them to reusable defaults.

## 7. Promotion levels

`CANDIDATE` — research-supported idea, not tested by us.

`DAIMON_TESTED` — tested at least once in a DAIMON funnel; effect may still be context-specific.

`REPLICATED` — positive result replicated across multiple campaigns/surfaces with adequate evidence.

`DEFAULT_PATTERN` — strong enough internally to become the starting design pattern, still subject to measurement and ethical constraints.

No level is called `GUARANTEED`.

## 8. Internal explanation requirement

For every app/CM/LP/Store creative, Owner-facing internal explanation must state:
- mechanisms used
- why selected
- expected customer behavior
- intended funnel movement
- metrics that validate/falsify the hypothesis
- current library promotion level

This explanation is INTERNAL ONLY and must not be automatically exposed to customers.

## 9. Customer-facing rule

Customers receive clear product value, truthful benefits, transparent pricing and necessary evidence-backed explanations. They do not receive internal persuasion strategy, experiment logic, conversion tactics or psychological targeting notes unless a specific transparent explanation is genuinely useful and appropriate.

## 10. Continuous learning loop

After each meaningful campaign/release:
1. Import actual metrics.
2. Join metrics to CM/content ID, platform, post ID and variant.
3. Compare expected vs observed behavioral path.
4. Update experiment result.
5. Promote/demote/reject mechanism.
6. Feed winners into the next app/CM design baseline.
7. Preserve failed tests so AI5 does not repeat them blindly.

The purpose of this library is compounding evidence: each release should make the next release more precise.
