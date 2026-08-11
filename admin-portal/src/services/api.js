import axios from 'axios';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000/api';

const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request Interceptor
apiClient.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('access_token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response Interceptor
apiClient.interceptors.response.use(
  (response) => {
    return response;
  },
  (error) => {
    if (error.response && error.response.status === 401) {
      localStorage.removeItem('access_token');
      localStorage.removeItem('refresh_token');
      localStorage.removeItem('user');
      if (!window.location.pathname.endsWith('/login')) {
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);

export const authService = {
  login: async (email, password) => {
    const response = await apiClient.post('/accounts/login/', { email, password });
    if (response.data && response.data.access) {
      localStorage.setItem('access_token', response.data.access);
      localStorage.setItem('refresh_token', response.data.refresh);
      localStorage.setItem('user', JSON.stringify(response.data.user || { email }));
    }
    return response.data;
  },
  sendSuperuserOTP: async (email) => {
    const response = await apiClient.post('/accounts/send-superuser-otp/', { email });
    return response.data;
  },
  createSuperuser: async (data = {}) => {
    const response = await apiClient.post('/accounts/create-superuser/', data);
    return response.data;
  },
  forgotPassword: async (email) => {
    const response = await apiClient.post('/auth/forgot-password/', { email });
    return response.data;
  },
  verifyResetOTP: async (email, otp) => {
    const response = await apiClient.post('/auth/verify-reset-otp/', { email, otp });
    return response.data;
  },
  resetPassword: async (resetToken, newPassword, confirmPassword) => {
    const response = await apiClient.post('/auth/reset-password/', {
      reset_token: resetToken,
      new_password: newPassword,
      confirm_password: confirmPassword,
    });
    return response.data;
  },
  logout: () => {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    localStorage.removeItem('user');
    window.location.href = '/login';
  }
};

export const societyService = {
  getAll: (params) => apiClient.get('/society/societies/', { params }),
  get: (id) => apiClient.get(`/society/societies/${id}/`),
  create: (data) => apiClient.post('/society/societies/', data),
  update: (id, data) => apiClient.put(`/society/societies/${id}/`, data),
  delete: (id) => apiClient.delete(`/society/societies/${id}/`),
  getStats: () => apiClient.get('/society/stats/'),
  assignManager: (id, manager_id) => apiClient.post(`/society/societies/${id}/assign-manager/`, { manager_id }),
  getEligibleManagers: () => apiClient.get('/society/societies/eligible-managers/'),
};

export const blockService = {
  getAll: (params) => apiClient.get('/society/blocks/', { params }),
  get: (id) => apiClient.get(`/society/blocks/${id}/`),
  create: (data) => apiClient.post('/society/blocks/', data),
  update: (id, data) => apiClient.put(`/society/blocks/${id}/`, data),
  delete: (id) => apiClient.delete(`/society/blocks/${id}/`),
};

export const flatService = {
  getAll: (params) => apiClient.get('/society/flats/', { params }),
  get: (id) => apiClient.get(`/society/flats/${id}/`),
  create: (data) => apiClient.post('/society/flats/', data),
  update: (id, data) => apiClient.put(`/society/flats/${id}/`, data),
  delete: (id) => apiClient.delete(`/society/flats/${id}/`),
};

export const residentService = {
  getAll: (params) => apiClient.get('/accounts/residents/', { params }),
  get: (id) => apiClient.get(`/accounts/residents/${id}/`),
  create: (data) => apiClient.post('/accounts/residents/', data),
  update: (id, data) => apiClient.put(`/accounts/residents/${id}/`, data),
  delete: (id) => apiClient.delete(`/accounts/residents/${id}/`),
  approve: (id) => apiClient.post(`/accounts/residents/${id}/approve/`),
  reject: (id) => apiClient.post(`/accounts/residents/${id}/reject/`),
};

export const volunteerService = {
  getAll: (params) => apiClient.get('/accounts/volunteers/', { params }),
  get: (id) => apiClient.get(`/accounts/volunteers/${id}/`),
  update: (id, data) => apiClient.put(`/accounts/volunteers/${id}/`, data),
  verify: (id, action, remarks = '') => apiClient.post(`/accounts/volunteers/${id}/verify/`, { action, remarks }),
  assign: (id, society, block) => apiClient.post(`/accounts/volunteers/${id}/assign/`, { society, block }),
};

export const securityService = {
  getAll: (params) => apiClient.get('/accounts/security/', { params }),
  get: (id) => apiClient.get(`/accounts/security/${id}/`),
  update: (id, data) => apiClient.put(`/accounts/security/${id}/`, data),
  verify: (id, action, remarks = '') => apiClient.post(`/accounts/security/${id}/verify/`, { action, remarks }),
  getDashboardSummary: () => apiClient.get('/security/dashboard/'),
  getIncidentsList: (params) => apiClient.get('/security/incidents/', { params }),
  submitResolution: (id, data) => apiClient.post(`/security/incidents/${id}/resolution/`, data),
  getReportingSummary: () => apiClient.get('/security/reports/summary/'),
};

export const guardianService = {
  getAll: (params) => apiClient.get('/accounts/guardians/', { params }),
  verify: (id, action, remarks = '') => apiClient.post(`/accounts/guardians/${id}/verify/`, { action, remarks }),
};

export const verificationService = {
  getCenterData: (params) => apiClient.get('/accounts/verification-center/', { params }),
  getDocuments: (params) => apiClient.get('/accounts/documents/', { params }),
};

export const reportService = {
  downloadReport: (type, format, filters = {}) => {
    const query = new URLSearchParams({ type, format, ...filters }).toString();
    const url = `${API_BASE_URL}/society/reports/download/?${query}`;
    window.open(url, '_blank');
  }
};

export const emergencyService = {
  getAllContacts: (params) => apiClient.get('/emergency/contacts/', { params }),
  createContact: (data) => apiClient.post('/emergency/contacts/', data),
  updateContact: (id, data) => apiClient.put(`/emergency/contacts/${id}/`, data),
  deleteContact: (id) => apiClient.delete(`/emergency/contacts/${id}/`),
  verifyContact: (id) => apiClient.post(`/emergency/contacts/${id}/verify/`),
  getRelationships: () => apiClient.get('/emergency/relationships/'),
  
  getAllGuardians: (params) => apiClient.get('/emergency/guardians/', { params }),
  createGuardian: (data) => apiClient.post('/emergency/guardians/', data),
  updateGuardian: (id, data) => apiClient.put(`/emergency/guardians/${id}/`, data),
  deleteGuardian: (id) => apiClient.delete(`/emergency/guardians/${id}/`),
};

export const dashboardService = {
  getStats: () => apiClient.get('/society/stats/'),
  getIncidentStats: () => apiClient.get('/sos/incidents/tracking-stats/'),
  getDashboardSummary: (params) => apiClient.get('/sos/dashboard/summary/', { params }),
  getAlertStatusTracking: (params) => apiClient.get('/sos/alert-status-tracking/', { params }),
  getIncidentStatusTracking: (id) => apiClient.get(`/sos/incidents/${id}/status-tracking/`),
  getNotificationDeliveryTracking: (params) => apiClient.get('/notifications/delivery-tracking/', { params }),
  getResponseMonitoring: () => apiClient.get('/sos/analytics/response-monitoring/'),
};

export const directoryService = {
  getDirectory: (params) => apiClient.get('/directory/', { params }),
};

export const sosService = {
  getAllIncidents: (params) => apiClient.get('/sos/incidents/', { params }),
  getIncident: (id) => apiClient.get(`/sos/incidents/${id}/`),
  getCategories: () => apiClient.get('/sos/categories/'),
  acceptIncident: (id) => apiClient.patch(`/sos/accept/${id}/`),
  markInProgress: (id) => apiClient.patch(`/sos/in-progress/${id}/`),
  resolveIncident: (id) => apiClient.patch(`/sos/resolve/${id}/`),
  cancelIncident: (id) => apiClient.patch(`/sos/cancel/${id}/`),
  getAssignmentLogs: (id) => apiClient.get(`/sos/incidents/${id}/assignment-logs/`),
  transitionStatus: (id, status, remarks = '') => apiClient.post(`/sos/incidents/${id}/status/`, { status, remarks }),
  closeIncident: (id, data) => apiClient.post(`/sos/incidents/${id}/closure/`, data),
  getTimeline: (id) => apiClient.get(`/sos/incidents/${id}/timeline/`),
  getStatusLogs: (id) => apiClient.get(`/sos/incidents/${id}/status-logs/`, { params: { incident: id } }),
  getChatHistory: (id, params) => apiClient.get(`/sos/incidents/${id}/chat/`, { params }),
  sendChatMessage: (id, data) => apiClient.post(`/sos/incidents/${id}/chat/`, data),
  deleteChatMessage: (id, messageId) => apiClient.delete(`/sos/incidents/${id}/chat/${messageId}/`),
  getResponseUpdates: (id, params) => apiClient.get(`/sos/incidents/${id}/updates/`, { params }),
  createResponseUpdate: (id, data) => apiClient.post(`/sos/incidents/${id}/updates/`, data),
};

export const escalationService = {
  getConfig: () => apiClient.get('/escalation/config/'),
  updateConfig: (data) => apiClient.post('/escalation/config/', data),
  getLogs: (params) => apiClient.get('/escalation/logs/', { params }),
  getIncidentEscalation: (id) => apiClient.get(`/incident/${id}/escalation/`),
  getIncidentTimeline: (id) => apiClient.get(`/incident/${id}/timeline/`),
  manualEscalate: (id, data = {}) => apiClient.post(`/incident/${id}/escalation/`, data),
};

export default apiClient;
