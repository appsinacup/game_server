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
        let json = r.json();
        return json && json.data && json.data.access_token;
      },
    });

    deviceLoginTrend.add(loginRes.timings.duration);

    if (loginRes.status === 200) {
      let access = loginRes.json().data.access_token;
      // Call a protected endpoint
      let r = http.get(`${base}/api/v1/me`, {
        headers: { Authorization: `Bearer ${access}` }
      });
      check(r, { 'me status 200': (r) => r.status === 200 });
    }
  });

  sleep(1); // pacing
}
