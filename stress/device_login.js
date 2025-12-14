import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Trend } from 'k6/metrics';

//const base = __ENV.BASE_URL || 'http://localhost:4000';
const base = __ENV.BASE_URL || 'https://gamend.appsinacup.com';
const deviceLoginTrend = new Trend('device_login_latency');

export let options = {
  stages: [
    { duration: '30s', target: 5000 },
  ]
};

function randomDeviceId() {
  return `device-${Math.floor(Math.random() * 1e9)}-${__VU}-${__ITER}`;
}

export default function () {
  group('DeviceLoginAndCall', function () {
    let device_id = randomDeviceId();
    let loginRes = http.post(`${base}/api/v1/login/device`, JSON.stringify({ device_id }), {
      headers: { 'Content-Type': 'application/json' },
    });

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
      let access = null;
      try {
        let parsed = loginRes.json();
        access = parsed && parsed.data && parsed.data.access_token;
      } catch (e) {
        console.error('login parse error when extracting token', e, 'status', loginRes.status, 'body_len', loginRes.body ? loginRes.body.length : 0);
      }

      if (access) {
        // Call a protected endpoint
        let r = http.get(`${base}/api/v1/me`, {
          headers: { Authorization: `Bearer ${access}` }
        });
        check(r, { 'me status 200': (r) => r.status === 200 });
      } else {
        console.error('no access token in login response', loginRes.status);
      }
    }
  });

  sleep(1); // pacing
}
