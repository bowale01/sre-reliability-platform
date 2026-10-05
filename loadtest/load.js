// k6 load test for demo-service.
//
// Drives traffic in stages so you can watch the full scalability loop:
//   ramp up  -> HPA scales pods -> Karpenter adds nodes -> SLOs hold
//   ramp down -> pods scale in  -> Karpenter consolidates/removes nodes
//
// Usage:
//   BASE_URL=http://<alb-dns-name> k6 run loadtest/load.js
//
// Optionally tag requests by tenant to exercise per-tenant SLI tagging.

import http from "k6/http";
import { check, sleep } from "k6";
import { Rate } from "k6/metrics";

const errorRate = new Rate("errors");

const BASE_URL = __ENV.BASE_URL || "http://localhost:8080";
const TENANTS = ["acme", "globex", "initech", "umbrella"];

export const options = {
  scenarios: {
    scalability: {
      executor: "ramping-vus",
      startVUs: 5,
      stages: [
        { duration: "3m", target: 50 },   // ramp up — expect HPA + Karpenter to react
        { duration: "5m", target: 200 },  // sustained peak — SLOs should hold
        { duration: "3m", target: 50 },   // ramp down
        { duration: "4m", target: 0 },    // idle — expect Karpenter consolidation
      ],
    },
  },
  // Client-side SLO guardrails mirroring the server-side Datadog SLOs.
  thresholds: {
    http_req_duration: ["p(99)<300"], // 99% under 300ms (latency SLO)
    errors: ["rate<0.001"],           // < 0.1% errors (availability SLO)
  },
};

export default function () {
  const tenant = TENANTS[Math.floor(Math.random() * TENANTS.length)];
  const params = { headers: { "x-tenant-id": tenant } };

  // Weight the list endpoint higher than the detail endpoint.
  const url =
    Math.random() < 0.7
      ? `${BASE_URL}/api/courses`
      : `${BASE_URL}/api/courses/c-101`;

  const res = http.get(url, params);
  const ok = check(res, { "status is 200": (r) => r.status === 200 });
  errorRate.add(!ok);

  sleep(Math.random() * 0.5);
}
