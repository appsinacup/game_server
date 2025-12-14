import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Trend } from 'k6/metrics';

/**
 * k6 load test: device login + authenticated calls
 *
 * What it does per VU iteration:
 *  1) POST /api/v1/login/device with a randomized device_id
 *  2) Extract access_token from JSON response
 *  3) Perform N authenticated GETs to /api/v1/me using that token
 *  4) Sleep for pacing
 *
 * Notes:
 *  - `target` below is VUs (virtual users), NOT requests/second.
 *    Your effective request rate depends on iteration time + pacing.
 *  - Configure via environment variables (examples):
 *      BASE_URL=https://example.com TARGET_VUS=2000 STAGE_DURATION=30s ME_CALLS=10 SLEEP_SECONDS=1 REUSE_TOKEN=true k6 run device_login.js
 *
 *  - `REUSE_TOKEN=true` caches the token per VU and skips re-login on every iteration.
 *    This is more realistic for steady-state traffic. If the token expires (15m in prod
 *    by default), /api/v1/me will return 401 and the script will re-login next iteration.
 */

const BASE_URL = __ENV.BASE_URL || 'https://gamend.appsinacup.com';
// const BASE_URL = 'http://localhost:4000';
const TARGET_VUS = Number.parseInt(__ENV.TARGET_VUS || '2000', 10);
const STAGE_DURATION = __ENV.STAGE_DURATION || '180s';
const ME_CALLS = Number.parseInt(__ENV.ME_CALLS || '10', 10);
const SLEEP_SECONDS = Number.parseFloat(__ENV.SLEEP_SECONDS || '1');

const deviceLoginTrend = new Trend('device_login_latency');
const meTrend = new Trend('me_latency');

export let options = {
  stages: [
    { duration: STAGE_DURATION, target: TARGET_VUS },
  ]
};

function getOrCreateDeviceId() {
  return `device-${Math.floor(Math.random() * 1e9)}-${__VU}-${__ITER}`;
}

function loginDevice(device_id) {
  return http.post(`${BASE_URL}/api/v1/login/device`, JSON.stringify({ device_id }), {
    headers: { 'Content-Type': 'application/json' },
  });
}

export default function () {
  group('DeviceLoginAndCall', function () {
    let device_id = getOrCreateDeviceId();

    let access = null;
    let loginRes = null;

    if (!access) {
      loginRes = loginDevice(device_id);

      check(loginRes, {
        'login status 200': (r) => r.status === 200,
        'login returned access token': (r) => {
          try {
            let json = r.json();
            return !!(json && json.data && json.data.access_token);
          } catch (e) {
            console.error('login parse error', e, 'status', r.status, 'body_len', r.body ? r.body.length : 0);
            return false;
          }
        },
      });

      deviceLoginTrend.add(loginRes.timings.duration);

      if (loginRes.status === 200) {
        try {
          let parsed = loginRes.json();
          access = parsed && parsed.data && parsed.data.access_token;
        } catch (e) {
          console.error('login parse error when extracting token', e, 'status', loginRes.status, 'body_len', loginRes.body ? loginRes.body.length : 0);
        }
      }
    }

    if (access) {
      // Call a protected endpoint multiple times using the same token.
      for (let i = 0; i < ME_CALLS; i++) {
        let r = http.get(`${BASE_URL}/api/v1/me`, {
          headers: { Authorization: `Bearer ${access}` }
        });
        meTrend.add(r.timings.duration);

        let ok = check(r, { 'me status 200': (r) => r.status === 200 });
      }
    } else if (loginRes) {
      console.error('no access token in login response', loginRes.status);
    }
  });

  sleep(SLEEP_SECONDS); // pacing
}
