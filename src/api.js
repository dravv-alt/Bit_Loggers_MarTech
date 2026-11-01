const BASE_URL = '';

export async function apiRequest(endpoint, { method = 'GET', body = null, headers = {}, user = null, idempotencyKey = null, expectedVersion = null } = {}) {
  const reqHeaders = {
    'Content-Type': 'application/json',
    ...headers
  };

  if (user && user.id) {
    reqHeaders['x-user-id'] = user.id;
  }
  if (idempotencyKey) {
    reqHeaders['idempotency-key'] = idempotencyKey;
  }
  if (expectedVersion !== null && expectedVersion !== undefined) {
    reqHeaders['x-expected-version'] = String(expectedVersion);
  }

  const options = {
    method,
    headers: reqHeaders
  };

  if (body && ['POST', 'PUT', 'PATCH'].includes(method)) {
    options.body = JSON.stringify(body);
  }

  const res = await fetch(`${BASE_URL}${endpoint}`, options);
  const data = await res.json().catch(() => ({}));

  if (!res.ok) {
    const errorMsg = data.error?.message || data.error?.code || data.message || `Request failed with status ${res.status}`;
    const error = new Error(errorMsg);
    error.status = res.status;
    error.code = data.error?.code;
    error.data = data;
    throw error;
  }

  return data;
}

export const api = {
  getUsers: () => apiRequest('/api/users'),
  getCampaigns: (params = {}, user) => {
    const q = new URLSearchParams(params).toString();
    return apiRequest(`/api/campaigns${q ? '?' + q : ''}`, { user });
  },
  getCampaign: (id, user) => apiRequest(`/api/campaigns/${id}`, { user }),
  createCampaign: (data, user) => apiRequest('/api/campaigns', { method: 'POST', body: data, user }),
  updateCampaign: (id, data, user, expectedVersion) => apiRequest(`/api/campaigns/${id}`, { method: 'PUT', body: data, user, expectedVersion }),
  acquireLock: (id, user) => apiRequest(`/api/campaigns/${id}/lock`, { method: 'POST', user }),
  releaseLock: (id, user) => apiRequest(`/api/campaigns/${id}/lock`, { method: 'DELETE', user }),
  submitCampaign: (id, user, idempotencyKey) => apiRequest(`/api/campaigns/${id}/submit`, { method: 'POST', user, idempotencyKey }),
  approveCampaign: (id, data, user) => apiRequest(`/api/campaigns/${id}/approve`, { method: 'POST', body: data, user }),
  requestChanges: (id, data, user) => apiRequest(`/api/campaigns/${id}/request-changes`, { method: 'POST', body: data, user }),
  rejectCampaign: (id, data, user) => apiRequest(`/api/campaigns/${id}/reject`, { method: 'POST', body: data, user }),
  scheduleCampaign: (id, data, user) => apiRequest(`/api/campaigns/${id}/schedule`, { method: 'POST', body: data, user }),
  getVersions: (id, user) => apiRequest(`/api/campaigns/${id}/versions`, { user }),
  getDecisions: (id, user) => apiRequest(`/api/campaigns/${id}/decisions`, { user }),
  getDiscussions: (id, user) => apiRequest(`/api/campaigns/${id}/discussions`, { user }),
  postDiscussion: (id, data, user) => apiRequest(`/api/campaigns/${id}/discussions`, { method: 'POST', body: data, user }),
  getNotifications: (user) => apiRequest('/api/notifications', { user }),
  markNotificationRead: (id, user) => apiRequest(`/api/notifications/${id}/read`, { method: 'POST', user }),
  markAllNotificationsRead: (user) => apiRequest('/api/notifications/read-all', { method: 'POST', user }),
  getAnalytics: (channel, user) => apiRequest(`/api/analytics${channel ? '?channel=' + channel : ''}`, { user }),
  getCalendar: (user) => apiRequest('/api/calendar', { user }),
  getAudit: (campaignId, user) => apiRequest(`/api/audit${campaignId ? '?campaign_id=' + campaignId : ''}`, { user }),
  getDiagnostics: (user, params = {}) => {
    const q = new URLSearchParams(params).toString();
    return apiRequest(`/api/diagnostics${q ? '?' + q : ''}`, { user });
  },
  getOutbox: (user) => apiRequest('/api/outbox', { user }),
  processOutbox: (user) => apiRequest('/api/outbox/process', { method: 'POST', user }),
  toggleEmailFailure: (failing, user) => apiRequest('/api/outbox/toggle-email-failure', { method: 'POST', body: { failing }, user }),
  toggleGeminiFailure: (failing, user) => apiRequest('/api/ai/toggle-failure', { method: 'POST', body: { failing }, user }),
  draftAI: (data, user) => apiRequest('/api/ai/draft', { method: 'POST', body: data, user }),
  summarizeAI: (data, user) => apiRequest('/api/ai/summarize', { method: 'POST', body: data, user }),
  runTests: (user) => apiRequest('/api/test/run-all', { method: 'POST', user }),
  seedData: (user) => apiRequest('/api/seed', { method: 'POST', user })
};

