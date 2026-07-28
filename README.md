# taskflow-observability

Full observability platform for the Taskflow application: distributed tracing,
structured logs, and metrics via OpenTelemetry, shipped through an OTel Collector
to the Grafana LGTM stack (Loki, Tempo, Mimir), with SLO dashboards, multi-window
burn-rate alerts, and Alertmanager routing to Slack and email.

Running on Amazon EKS. Provisioned with Terraform. All tooling installed via Helm.

## Architecture
_TBD — diagram lands in Phase 7._

## Stack
- OpenTelemetry SDK + Collector
- Grafana Loki (logs), Tempo (traces), Mimir (metrics)
- Prometheus Alertmanager (routing to Slack + email)
- Grafana (visualisation, SLOs, alerting)
- Amazon EKS, S3 (object storage), Pod Identity
- Terraform, Helm

## Status
Phase 1 — foundation.
