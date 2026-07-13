import axios from "axios";

const BASE_URL = process.env.REACT_APP_API_BASE_URL || "http://127.0.0.1:8000/api";
const ACCESS_TOKEN_KEY = "careconnect_admin_access_token";
const REFRESH_TOKEN_KEY = "careconnect_admin_refresh_token";
const USER_KEY = "careconnect_admin_user";

export const api = axios.create({
  baseURL: BASE_URL,
  headers: {
    Accept: "application/json",
  },
});

api.interceptors.request.use(async (config) => {
  const token = localStorage.getItem(ACCESS_TOKEN_KEY);
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;
    const refreshToken = localStorage.getItem(REFRESH_TOKEN_KEY);

    if (
      error.response?.status === 401 &&
      refreshToken &&
      originalRequest &&
      !originalRequest._retry
    ) {
      originalRequest._retry = true;

      try {
        const refreshResponse = await axios.post(`${BASE_URL}/token/refresh/`, {
          refresh: refreshToken,
        });
        const newAccessToken = refreshResponse.data.access;
        localStorage.setItem(ACCESS_TOKEN_KEY, newAccessToken);
        originalRequest.headers.Authorization = `Bearer ${newAccessToken}`;
        return api(originalRequest);
      } catch (refreshError) {
        clearAuth();
        return Promise.reject(refreshError);
      }
    }

    return Promise.reject(error);
  }
);

function extractResults(data) {
  if (Array.isArray(data)) {
    return data;
  }

  if (data && Array.isArray(data.results)) {
    return data.results;
  }

  return [];
}

export function getAuthToken() {
  return localStorage.getItem(ACCESS_TOKEN_KEY);
}

export function getCurrentUser() {
  const value = localStorage.getItem(USER_KEY);
  return value ? JSON.parse(value) : null;
}

export function isAuthenticated() {
  return Boolean(getAuthToken());
}

export function clearAuth() {
  localStorage.removeItem(ACCESS_TOKEN_KEY);
  localStorage.removeItem(REFRESH_TOKEN_KEY);
  localStorage.removeItem(USER_KEY);
}

export async function login({ email, password }) {
  const response = await api.post("/accounts/login/", { email, password });
  const { access, refresh, user } = response.data;
  localStorage.setItem(ACCESS_TOKEN_KEY, access);
  localStorage.setItem(REFRESH_TOKEN_KEY, refresh);
  localStorage.setItem(USER_KEY, JSON.stringify(user));
  return response.data;
}

export async function getDashboardStats() {
  const response = await api.get("/accounts/dashboard-stats/");
  return response.data;
}

export async function getSocieties(params = {}) {
  const response = await api.get("/society/societies/", { params });
  return extractResults(response.data);
}

export async function getBlocks(params = {}) {
  const response = await api.get("/society/blocks/", { params });
  return extractResults(response.data);
}

export async function getFlats(params = {}) {
  const response = await api.get("/society/flats/", { params });
  return extractResults(response.data);
}

export async function getResidents(params = {}) {
  const response = await api.get("/accounts/residents/", { params });
  return extractResults(response.data);
}

export async function approveResident(id) {
  const response = await api.post(`/accounts/residents/${id}/approve/`);
  return response.data;
}

export async function rejectResident(id) {
  const response = await api.post(`/accounts/residents/${id}/reject/`);
  return response.data;
}

export async function getRelationships() {
  const response = await api.get("/emergency/relationships/");
  return extractResults(response.data);
}

export async function getContacts(params = {}) {
  const response = await api.get("/emergency/contacts/", { params });
  return extractResults(response.data);
}

export async function verifyContact(id) {
  const response = await api.post(`/emergency/contacts/${id}/verify/`);
  return response.data;
}
