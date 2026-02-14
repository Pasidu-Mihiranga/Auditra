export const getStatusColor = (status) => {
  const colors = {
    pending: '#D97706',
    active: '#2563EB',
    in_progress: '#2563EB',
    completed: '#16A34A',
    cancelled: '#DC2626',
    approved: '#16A34A',
    rejected: '#DC2626',
    draft: '#64748B',
    submitted: '#1565C0',
    reviewed: '#16A34A',
    accepted: '#16A34A',
    present: '#16A34A',
    absent: '#DC2626',
    half_day: '#D97706',
  };
  return colors[status] || '#64748B';
};

export const getPriorityColor = (priority) => {
  const colors = {
    high: '#DC2626',
    medium: '#D97706',
    low: '#16A34A',
  };
  return colors[priority] || '#64748B';
};

export const formatDate = (dateString) => {
  if (!dateString) return '-';
  return new Date(dateString).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
};

export const formatDateTime = (dateString) => {
  if (!dateString) return '-';
  return new Date(dateString).toLocaleString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

export const formatCurrency = (amount) => {
  if (amount == null) return '-';
  return new Intl.NumberFormat('en-LK', {
    style: 'currency',
    currency: 'LKR',
    minimumFractionDigits: 0,
  }).format(amount);
};
