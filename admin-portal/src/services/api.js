import axios from 'axios';

const API_BASE_URL = 'http://localhost:8000/api';

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
  approve: (id) => apiClient.post(`/accounts/residents/${id}/approve/`),
  reject: (id) => apiClient.post(`/accounts/residents/${id}/reject/`),
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
  getStats: () => apiClient.get('/accounts/dashboard-stats/'),
  getIncidentStats: () => apiClient.get('/sos/incidents/tracking-stats/'),
};

export const sosService = {
  getAllIncidents: (params) => apiClient.get('/sos/incidents/', { params }),
  getIncident: (id) => apiClient.get(`/sos/incidents/${id}/`),
  getCategories: () => apiClient.get('/sos/categories/'),
  acceptIncident: (id) => apiClient.patch(`/sos/accept/${id}/`),
  markInProgress: (id) => apiClient.patch(`/sos/in-progress/${id}/`),
  resolveIncident: (id) => apiClient.patch(`/sos/resolve/${id}/`),
  cancelIncident: (id) => apiClient.patch(`/sos/cancel/${id}/`),
};

export default apiClient;
