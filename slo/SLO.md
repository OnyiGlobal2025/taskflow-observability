# Service Levels: SLI, SLO, and SLA

This document defines the reliability targets for the Taskflow backend and explains how they are measured and enforced. The three terms are often conflated; this project keeps them distinct on purpose.

| Term | What it is | Status in this project |
|---|---|---|
| **SLI** | The *measurement* — a number describing how well the service is doing | Implemented (recording rules in Mimir) |
| **SLO** | The *internal target* the team commits to hitting | Implemented (burn-rate alert rules) |
| **SLA** | The *external contract* with customers, looser than the SLO | Illustrative only — no external customers |

---

## SLI — Service Level Indicator

The SLI is the thing we measure. For the Taskflow backend, the primary SLI is **availability**, expressed as the proportion of successful requests:

```
availability = successful requests / total requests
```

where a "failed" request is any HTTP `5xx` response. This is computed directly from the `http_server_request_duration_seconds_count` histogram emitted by the OpenTelemetry SDK, as a recording rule in Mimir:

```
job:http_request_error_rate:ratio_rate5m =
    sum(rate(http_server_request_duration_seconds_count{job="taskflow/taskflow-backend", http_response_status_code=~"5.."}[5m]))
    /
    sum(rate(http_server_request_duration_seconds_count{job="taskflow/taskflow-backend"}[5m]))
```

That ratio is the **error rate**; `1 - error_rate` is the availability SLI. It is evaluated continuously over multiple windows (5m and 1h) — see `taskflow-slo-rules.yaml`.

A latency SLI (proportion of requests served under a threshold, e.g. 300 ms) is available from the same histogram and is a natural next addition.

---

## SLO — Service Level Objective

The SLO is our **internal target** — the number we hold ourselves to.

> **99% of requests succeed, measured over a rolling 30-day window.**

That 99% implies a **1% error budget**: over 30 days, up to 1% of requests may fail before the objective is breached. The error budget is what makes the SLO actionable — instead of reacting to every blip, we react to how fast the budget is being consumed.

### How the SLO is enforced: multi-window, multi-burn-rate alerts

Rather than alerting on a raw error-rate threshold (which is noisy and slow), the SLO is enforced with **burn-rate alerting** — the Google SRE pattern. Burn rate is how fast the error budget is being spent relative to "normal." A burn rate of 1 exactly exhausts the budget over the SLO window; higher means faster.

Two alerts, at different sensitivities:

| Alert | Condition | Meaning | Severity |
|---|---|---|---|
| **Fast burn** | error rate > 14.4 × 1% over **both** 5m and 1h | Budget being spent ~14× too fast — page now | `critical` (Slack + email) |
| **Slow burn** | error rate > 3 × 1% over 1h | Gradual degradation — investigate | `warning` (Slack) |

The `0.01` in the rules (`14.4 * 0.01`, `3 * 0.01`) is the 1% error budget. The fast-burn alert requires the threshold to be crossed on **two windows at once** to avoid firing on brief spikes; the slow-burn alert uses a longer window to catch slow bleeds a fast alert would miss.

Rules live in `taskflow-slo-rules.yaml`, are evaluated by the Mimir ruler, and route through Alertmanager to Slack and email by severity.

---

## SLA — Service Level Agreement

An SLA is a **contractual commitment to external customers**, with real consequences (credits, penalties) if it is breached. It is deliberately **looser** than the internal SLO, so the team has a safety margin: you detect and fix problems against the tighter SLO *before* the customer-facing SLA is ever at risk.

**This project has no external customers, so there is no real SLA.** It is documented here only to make the distinction explicit and to show how the three levels relate.

If Taskflow *were* a customer-facing product, a representative arrangement would be:

| Level | Target | Audience | Consequence of breach |
|---|---|---|---|
| SLO (internal) | 99.9% availability | Engineering team | Alert, error-budget freeze on new releases |
| SLA (external) | 99.5% availability | Customers | Service credits / contractual penalty |

The **gap between them (99.9% vs 99.5%) is the safety margin**. Alerts fire against the tighter internal number, giving the team room to respond before the external promise is broken.

---

## Summary

- **SLI** = the metric (request success rate) — *measured* in Mimir.
- **SLO** = the internal target (99%, 1% error budget) — *enforced* by burn-rate alerts.
- **SLA** = the external contract (looser, illustrative here) — *not applicable*, no customers.

The distinction matters: an SLI without an SLO is just a graph; an SLO without an SLA is fine for an internal service; and an SLA should always be looser than the SLO it is backed by.
