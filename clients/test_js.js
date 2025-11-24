const { ApiClient, HealthApi, AuthenticationApi, UsersApi } = require('./javascript/dist/index.js');
const { default: open } = require('open');

async function testSDK() {
  try {
    console.log('Testing SDK health check...');

    // Initialize the API client
    const apiClient = new ApiClient();
    apiClient.basePath = 'http://localhost:4000';

    // Create an instance of the Health API
    const healthApi = new HealthApi(apiClient);

    // Test the health endpoint
    const healthResponse = await healthApi.gameServerWebApiV1HealthControllerIndex();
    console.log('✅ Health check response:', healthResponse);

  } catch (error) {
    console.error('❌ Error testing SDK:', error);
  }
}

async function runOAuthFlow(provider) {
  try {
    console.log(`Testing ${provider} OAuth flow...`);

    // Initialize the API client
    const apiClient = new ApiClient();
    apiClient.basePath = 'http://localhost:4000';

    // Create an instance of the Authentication API
    const authApi = new AuthenticationApi(apiClient);

    // Step 1: Get the authorization URL with session_id
    console.log(`Step 1: Requesting ${provider} authorization URL...`);
    const authResponse = await authApi.gameServerWebAuthControllerApiRequest(provider);
    const authUrl = authResponse.authorization_url;
    const sessionId = authResponse.session_id;

    console.log(`✅ ${provider} authorization URL obtained:`);
    console.log(authUrl);
    console.log('Session ID:', sessionId);
    console.log('');

    // Step 2: Automatically open the URL in the default browser
    console.log(`Step 2: Opening ${provider} authorization URL in your default browser...`);
    await open(authUrl);
    console.log('✅ Browser opened! Please complete the login and authorization.');
    console.log('The success page will show when authentication is complete.');
    console.log('');

    // Step 3: Poll the session status until completion
    console.log('Step 3: Waiting for OAuth completion...');
    let sessionData = null;
    let attempts = 0;
    const maxAttempts = 60; // 60 seconds timeout

    while (attempts < maxAttempts) {
      try {
        // Poll the session status
        const statusResponse = await authApi.gameServerWebAuthControllerApiSessionStatus(sessionId);
        sessionData = statusResponse;

        console.log(`Polling session status... (${attempts + 1}/${maxAttempts}) - Status: ${sessionData.status}`);

        if (sessionData.status === 'completed') {
          console.log('✅ OAuth completed successfully!');
          break;
        } else if (sessionData.status === 'error') {
          console.error('❌ OAuth failed:', sessionData.details || sessionData.message);
          return null;
        } else if (sessionData.status === 'conflict') {
          console.error('❌ OAuth conflict:', sessionData.message || 'Account already linked to another user');
          return {status: 'conflict', data: sessionData.data || sessionData};
        }

        // Wait 1 second before next poll
        await new Promise(resolve => setTimeout(resolve, 1000));
        attempts++;

      } catch (error) {
        if (error.status === 404) {
          console.log(`Session not found, waiting... (${attempts + 1}/${maxAttempts})`);
        } else {
          console.error('Error polling session status:', error);
        }
        await new Promise(resolve => setTimeout(resolve, 1000));
        attempts++;
      }
    }

    if (!sessionData || sessionData.status !== 'completed') {
      console.error('❌ OAuth timed out or failed');
      return null;
    }

    // Extract token data from session. The server returns {status, data}
    // (preferred), but older shapes put tokens at the top level. Handle both.
    const payload = sessionData.data || sessionData;
    const tokenData = {
      accessToken: payload.access_token || payload.accessToken,
      refreshToken: payload.refresh_token || payload.refreshToken,
      tokenType: payload.token_type || payload.tokenType,
      expiresIn: payload.expires_in || payload.expiresIn,
      user: payload.user || null
    };

    console.log('');
    console.log(`🎉 ${provider} OAuth flow completed successfully!`);
    console.log('Access Token:', tokenData.accessToken);
    console.log('Refresh Token:', tokenData.refreshToken);
    console.log('Token Type:', tokenData.tokenType);
    console.log('Expires In:', tokenData.expiresIn, 'seconds');
    console.log('User:', tokenData.user);
    console.log('');

    return {provider, tokenData};

  } catch (error) {
    console.error(`Error testing ${provider} auth:`, error);
    return null;
  }
}

async function testAuthenticatedAPI(accessToken, refreshToken, provider) {
  try {
    console.log('Testing authenticated API calls...');

    // Initialize the API client with authentication
    const apiClient = new ApiClient();
    apiClient.basePath = 'http://localhost:4000';
    apiClient.defaultHeaders = {
      'Authorization': `Bearer ${accessToken}`
    };

    // Create instances of APIs that require authentication
    const authApi = new AuthenticationApi(apiClient);
    const usersApi = new UsersApi(apiClient);

    // Test getting user profile
    console.log('Getting user profile...');
    const userProfile = await usersApi.gameServerWebApiV1MeControllerShow(`Bearer ${accessToken}`);
    console.log('✅ User profile:', userProfile);

    // Test getting user metadata
    console.log('Getting user metadata...');
    const metadata = await usersApi.gameServerWebApiV1MetadataControllerShow(`Bearer ${accessToken}`);
    console.log('✅ User metadata:', metadata);

    // Test unlinking the provider (this will likely fail if it's the only auth method, but test anyway)
    console.log(`Testing unlink ${provider}...`);
    try {
      const unlinkResult = await authApi.gameServerWebApiV1ProviderControllerUnlink(provider);
      console.log(`✅ Unlinked ${provider}:`, unlinkResult);
    } catch (error) {
      console.log(`⚠️  Unlink ${provider} failed (expected if it's the only auth method):`, error.message);
    }

    // Test refreshing the token
    console.log('Testing token refresh...');
    const refreshRequest = { refresh_token: refreshToken };
    const refreshResponse = await authApi.gameServerWebApiV1SessionControllerRefresh({ gameServerWebApiV1SessionControllerRefreshRequest: refreshRequest });
    console.log('✅ Token refresh response:', refreshResponse);

    // Test logout
    console.log('Testing logout...');
    const logoutResponse = await authApi.gameServerWebApiV1SessionControllerDelete(`Bearer ${accessToken}`);
    console.log('✅ Logout response:', logoutResponse);

    console.log('✅ All authenticated API calls completed!');

  } catch (error) {
    console.error('❌ Error testing authenticated API:', error);
  }
}

// Run the tests
async function runAllTests() {
  console.log('🚀 Starting comprehensive OAuth and API tests...\n');

  await testSDK();
  console.log('');

  const providers = ['discord', 'google', 'facebook'];
  for (const provider of providers) {
    console.log(`\n--- Testing ${provider.toUpperCase()} ---\n`);
    const result = await runOAuthFlow(provider);
    if (result && result.tokenData && result.tokenData.accessToken) {
      await testAuthenticatedAPI(result.tokenData.accessToken, result.tokenData.refreshToken, provider);
    } else if (result && result.status === 'conflict') {
      console.log(`⚠️  ${provider} OAuth resulted in conflict. Skipping authenticated API tests.`);
    } else {
      console.log(`❌ ${provider} OAuth failed. Skipping authenticated API tests.`);
    }
    console.log('');
  }

  console.log('🎉 All tests completed!');
}

runAllTests();
