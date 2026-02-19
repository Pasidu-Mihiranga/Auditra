import axiosClient from '../api/axiosClient';

const authService = {
  login: (username, password) =>
    axiosClient.post('/auth/login/', { username, password }),

  register: (data) =>
    axiosClient.post('/auth/register/', data),

  getProfile: () =>
    axiosClient.get('/auth/profile/'),

  getMyRole: () =>
    axiosClient.get('/auth/my-role/'),

  getAvailableRoles: () =>
    axiosClient.get('/auth/roles/'),

  getAllUsers: () =>
    axiosClient.get('/auth/users/'),

  assignRole: (userId, role) =>
    axiosClient.post('/auth/assign-role/', { user_id: userId, role }),

  deleteUser: (userId) =>
    axiosClient.delete(`/auth/users/${userId}/delete/`),

  registerClient: (data) =>
    axiosClient.post('/clients/register/', data),

  registerEmployee: (data) => {
    const formData = new FormData();
    Object.entries(data).forEach(([key, value]) => {
      if (value != null && value !== '') formData.append(key, value);
    });
    return axiosClient.post('/employees/register/', formData, {
      headers: { 'Content-Type': undefined },
    });
  },
};

export default authService;
