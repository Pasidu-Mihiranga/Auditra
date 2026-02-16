import axiosClient from '../api/axiosClient';

const valuationService = {
  getValuations: () =>
    axiosClient.get('/valuations/'),

  getValuation: (id) =>
    axiosClient.get(`/valuations/${id}/`),

  createValuation: (data) =>
    axiosClient.post('/valuations/', data),

  updateValuation: (id, data) =>
    axiosClient.patch(`/valuations/${id}/`, data),

  deleteValuation: (id) =>
    axiosClient.delete(`/valuations/${id}/`),

  submitValuation: (id) =>
    axiosClient.post(`/valuations/${id}/submit/`),

  acceptValuation: (id) =>
    axiosClient.post(`/valuations/${id}/accept/`),

  rejectValuation: (id, data) =>
    axiosClient.post(`/valuations/${id}/reject/`, data),

  approveValuation: (id) =>
    axiosClient.post(`/valuations/${id}/approve/`),

  seniorValuerReject: (id, data) =>
    axiosClient.post(`/valuations/${id}/senior-valuer-reject/`, data),

  getReviewed: () =>
    axiosClient.get('/valuations/senior-valuer/reviewed/'),

  submitProposal: (id, data) =>
    axiosClient.post(`/valuations/${id}/submit-proposal/`, data),

  getPhotos: (valuationId) =>
    axiosClient.get(`/valuations/${valuationId}/photos/`),

  uploadPhoto: (valuationId, data) => {
    const formData = new FormData();
    Object.entries(data).forEach(([key, value]) => {
      if (value != null) formData.append(key, value);
    });
    return axiosClient.post(`/valuations/${valuationId}/photos/`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  },

  deletePhoto: (photoId) =>
    axiosClient.delete(`/valuations/photos/${photoId}/`),
};

export default valuationService;
