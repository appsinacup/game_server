import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

/**
 * k6 benchmark: compare different call patterns
 *
 * Scenarios tested (each runs independently):
 *  1) GET  /api/v1/me                — baseline authenticated request (JWT only, no DB query)
 *  2) POST /api/v1/hooks/call        — RPC noop (pure overhead: HTTP → plug → plugin manager → fn)
 *  3) POST /api/v1/hooks/call        — RPC KV read (HTTP → plugin → DB read)
 *  4) POST /api/v1/hooks/call        — RPC memory read (HTTP → plugin → ETS lookup)
 *  5) POST /api/v1/hooks/call        — RPC KV write + advisory lock (HTTP → plugin → lock → DB write)
 *  6) GET  /api/v1/kv/bench_key      — direct KV API read (no plugin layer)
 *
 * Prerequisites:
 *  - Server running with example_hook plugin loaded:
 *      GAME_SERVER_PLUGINS_DIR=modules/plugins_examples ./start.sh
 *  - Or against deployed instance with the plugin
 *
 * Usage:
 *      cd stress/
 *
 *      # Quick smoke test (5 VUs, 15s per scenario)
 *      k6 run benchmark.js
 *
 *      # Full benchmark (50 VUs, 60s)
 *      BASE_URL=http://localhost:4000 VUS=50 DURATION=60s k6 run benchmark.js
 *
 *      # Against production
 *      BASE_URL=https://gamend.appsinacup.com VUS=20 DURATION=30s k6 run benchmark.js
 *
 *      # Single scenario only (e.g. just KV read)
 *      k6 run benchmark.js --scenario rpc_kv_read
 */

// ── Configuration ──────────────────────────────────────────────────────

const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';
const VUS      = Number.parseInt(__ENV.VUS || '5', 10);
const DURATION = __ENV.DURATION || '15s';
const PLUGIN   = __ENV.PLUGIN || 'example_hook';
const BENCH_KEY = 'bench_test_key';

// ── Custom metrics (one trend per scenario for clean comparison) ──────

const meLatency         = new Trend('latency_me',         true);
const rpcNoopLatency    = new Trend('latency_rpc_noop',   true);
const rpcKvReadLatency  = new Trend('latency_rpc_kv_read', true);
const rpcMemLatency     = new Trend('latency_rpc_memory',  true);
const rpcLockLatency    = new Trend('latency_rpc_lock_write', true);
const kvApiLatency      = new Trend('latency_kv_api_read', true);

const errorRate = new Rate('errors');

// ── Scenarios ──────────────────────────────────────────────────────────

export let options = {
  scenarios: {
    // Warm-up: login + seed data, runs once before real scenarios
    setup_seed: {
      executor: 'shared-iterations',
      vus: 1,
      iterations: 1,
      maxDuration: '30s',
      exec: 'seedData',
      startTime: '0s',
    },
    me_baseline: {
      executor: 'constant-vus',
      vus: VUS,
      duration: DURATION,
      exec: 'scenarioMe',
      startTime: '5s',  // start after seed
    },
    rpc_noop: {
      executor: 'constant-vus',
      vus: VUS,
      duration: DURATION,
      exec: 'scenarioRpcNoop',
      startTime: `${5 + parseDurationSec(DURATION) + 2}s`,
    },
    rpc_kv_read: {
      executor: 'constant-vus',
      vus: VUS,
      duration: DURATION,
      exec: 'scenarioRpcKvRead',
      startTime: `${5 + (parseDurationSec(DURATION) + 2) * 2}s`,
    },
    rpc_memory: {
      executor: 'constant-vus',
      vus: VUS,
      duration: DURATION,
      exec: 'scenarioRpcMemory',
      startTime: `${5 + (parseDurationSec(DURATION) + 2) * 3}s`,
    },
    rpc_lock_write: {
      executor: 'constant-vus',
      vus: VUS,
      duration: DURATION,
      exec: 'scenarioRpcLockWrite',
      startTime: `${5 + (parseDurationSec(DURATION) + 2) * 4}s`,
    },
    kv_api_read: {
      executor: 'constant-vus',
      vus: VUS,
      duration: DURATION,
      exec: 'scenarioKvApiRead',
      startTime: `${5 + (parseDurationSec(DURATION) + 2) * 5}s`,
    },
  },
  thresholds: {
    'latency_me':              ['p(95)<500'],
    'latency_rpc_noop':        ['p(95)<500'],
    'latency_rpc_kv_read':     ['p(95)<500'],
    'latency_rpc_memory':      ['p(95)<500'],
    'latency_rpc_lock_write':  ['p(95)<1000'],
    'latency_kv_api_read':     ['p(95)<500'],
  },
};

// ── Helpers ────────────────────────────────────────────────────────────

function parseDurationSec(d) {
  let m = d.match(/^(\d+)(s|m|h)$/);
  if (!m) return 15;
  let val = parseInt(m[1]);
  if (m[2] === 'm') return val * 60;
  if (m[2] === 'h') return val * 3600;
  return val;
}

// Per-VU token cache
let _cachedToken = null;

function getToken() {
  if (_cachedToken) return _cachedToken;

  let deviceId = `bench-${__VU}-${Date.now()}`;
  let res = http.post(`${BASE_URL}/api/v1/login/device`,
    JSON.stringify({ device_id: deviceId }),
    { headers: { 'Content-Type': 'application/json' } }
  );

  if (res.status !== 200) {
    console.error(`Login failed: status=${res.status} body=${res.body}`);
    return null;
  }

  try {
    let json = res.json();
    _cachedToken = json.data.access_token;
    return _cachedToken;
  } catch (e) {
    console.error(`Login parse error: ${e}`);
    return null;
  }
}

function authHeaders(token) {
  return {
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
  };
}

function rpcCall(token, fn, args) {
  return http.post(
    `${BASE_URL}/api/v1/hooks/call`,
    JSON.stringify({ plugin: PLUGIN, fn: fn, args: args || [] }),
    authHeaders(token),
  );
}

// ── Seed scenario (runs once) ──────────────────────────────────────────

export function seedData() {
  let token = getToken();
  if (!token) {
    console.error('Cannot seed: no token');
    return;
  }

  // Call bench_setup to create ETS table + seed KV entry
  let res = rpcCall(token, 'bench_setup', [BENCH_KEY]);
  let ok = check(res, {
    'seed status 200': (r) => r.status === 200,
  });
  if (!ok) {
    console.warn(`Seed response: status=${res.status} body=${res.body}`);
  } else {
    console.log(`✓ Seed complete (KV key="${BENCH_KEY}", ETS table created)`);
  }
}

// ── Scenario: GET /api/v1/me ───────────────────────────────────────────

export function scenarioMe() {
  let token = getToken();
  if (!token) { errorRate.add(1); return; }

  let res = http.get(`${BASE_URL}/api/v1/me`, authHeaders(token));
  meLatency.add(res.timings.duration);
  let ok = check(res, { 'me 200': (r) => r.status === 200 });
  errorRate.add(!ok);
}

// ── Scenario: RPC noop ─────────────────────────────────────────────────

export function scenarioRpcNoop() {
  let token = getToken();
  if (!token) { errorRate.add(1); return; }

  let res = rpcCall(token, 'bench_noop', []);
  rpcNoopLatency.add(res.timings.duration);
  let ok = check(res, { 'rpc_noop 200': (r) => r.status === 200 });
  errorRate.add(!ok);
}

// ── Scenario: RPC KV read ──────────────────────────────────────────────

export function scenarioRpcKvRead() {
  let token = getToken();
  if (!token) { errorRate.add(1); return; }

  let res = rpcCall(token, 'bench_kv_read', [BENCH_KEY]);
  rpcKvReadLatency.add(res.timings.duration);
  let ok = check(res, { 'rpc_kv_read 200': (r) => r.status === 200 });
  errorRate.add(!ok);
}

// ── Scenario: RPC memory (ETS) read ────────────────────────────────────

export function scenarioRpcMemory() {
  let token = getToken();
  if (!token) { errorRate.add(1); return; }

  let res = rpcCall(token, 'bench_memory_read', [BENCH_KEY]);
  rpcMemLatency.add(res.timings.duration);
  let ok = check(res, { 'rpc_memory 200': (r) => r.status === 200 });
  errorRate.add(!ok);
}

// ── Scenario: RPC KV write with advisory lock ──────────────────────────

export function scenarioRpcLockWrite() {
  let token = getToken();
  if (!token) { errorRate.add(1); return; }

  let res = rpcCall(token, 'bench_kv_write_locked', [BENCH_KEY]);
  rpcLockLatency.add(res.timings.duration);
  let ok = check(res, { 'rpc_lock_write 200': (r) => r.status === 200 });
  errorRate.add(!ok);
}

// ── Scenario: direct KV API read (no RPC layer) ───────────────────────

export function scenarioKvApiRead() {
  let token = getToken();
  if (!token) { errorRate.add(1); return; }

  let res = http.get(`${BASE_URL}/api/v1/kv/${BENCH_KEY}`, authHeaders(token));
  kvApiLatency.add(res.timings.duration);
  let ok = check(res, { 'kv_api 200': (r) => r.status === 200 });
  errorRate.add(!ok);
}
