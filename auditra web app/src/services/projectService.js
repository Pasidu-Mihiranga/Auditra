import axiosClient from '../api/axiosClient';

const projectService = {
  getProjects: () =>
    axiosClient.get('/projects/'),

  getProject: (id) =>
    axiosClient.get(`/projects/${id}/`),

  createProject: (data) =>
    axiosClient.post('/projects/', data),

  updateProject: (id, data) =>
    axiosClient.patch(`/projects/${id}/`, data),

  deleteProject: (id) =>
    axiosClient.delete(`/projects/${id}/`),

  assignFieldOfficer: (projectId, userId) =>
    axiosClient.post(`/projects/${projectId}/assign-field-officer/`, { field_officer_id: userId }),

  assignClient: (projectId, userId) =>
    axiosClient.post(`/projects/${projectId}/assign-client/`, { client_id: userId }),

  assignAgent: (projectId, userId) =>
    axiosClient.post(`/projects/${projectId}/assign-agent/`, { agent_id: userId }),

  assignAccessor: (projectId, userId) =>
    axiosClient.post(`/projects/${projectId}/assign-accessor/`, { accessor_id: userId }),

  assignSeniorValuer: (projectId, userId) =>
    axiosClient.post(`/projects/${projectId}/assign-senior-valuer/`, { senior_valuer_id: userId }),

  getFieldOfficers: () =>
    axiosClient.get('/projects/field-officers/'),

  getClients: () =>
    axiosClient.get('/projects/clients/'),

  getAgents: () =>
    axiosClient.get('/projects/agents/'),

  getAccessors: () =>
    axiosClient.get('/projects/accessors/'),

  getSeniorValuers: () =>
    axiosClient.get('/projects/senior-valuers/'),

  uploadDocument: (data) => {
    const formData = new FormData();
    Object.entries(data).forEach(([key, value]) => {
      if (value != null) formData.append(key, value);
    });
    return axiosClient.post('/projects/documents/', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  },

  deleteDocument: (id) =>
    axiosClient.delete(`/projects/documents/${id}/`),

  mdGmApprove: (projectId) =>
    axiosClient.post(`/projects/${projectId}/md-gm-approve/`),

  mdGmReject: (projectId) =>
    axiosClient.post(`/projects/${projectId}/md-gm-reject/`),

  checkEmail: (email, roleType) =>
    axiosClient.post('/projects/check-email/', { email, role_type: roleType }),
};

export default projectService;
