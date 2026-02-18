import { useState, useEffect } from 'react';
import {
  Box, Typography, Table, TableBody, TableCell, TableContainer,
  TableHead, TableRow, Paper, Button, Alert, TextField, Grid, Card, CardContent,
  Dialog, DialogTitle, DialogContent, DialogActions, MenuItem, InputAdornment
} from '@mui/material';
import { Add, Upload, PictureAsPdf, Visibility, Download, AccessTime, Search } from '@mui/icons-material';
import paymentService from '../../services/paymentService';
import LoadingSpinner from '../../components/LoadingSpinner';
import { formatCurrency } from '../../utils/helpers';
import { viewPaymentSlipPDF, downloadPaymentSlipPDF, downloadAllPaymentSlipPDFs } from '../../utils/generatePaymentPDF';

export default function PaymentManagement() {
  const [slips, setSlips] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [generating, setGenerating] = useState(false);
  const [publishing, setPublishing] = useState(false);
  const [genMonth, setGenMonth] = useState(new Date().getMonth() + 1);
  const [genYear, setGenYear] = useState(new Date().getFullYear().toString());
  const [overtimeDialog, setOvertimeDialog] = useState(null);
  const [overtimeHours, setOvertimeHours] = useState('');
  const [searchQuery, setSearchQuery] = useState('');

  const fetchSlips = async () => {
    try {
      const res = await paymentService.getAllSlips();
      setSlips(Array.isArray(res.data.data) ? res.data.data : []);
    } catch {
      setError('Failed to load payment slips');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchSlips(); }, []);

  const handleGenerate = async () => {
    setGenerating(true);
    setError('');
    setSuccess('');
    try {
      await paymentService.generateSlips({ month: genMonth, year: genYear });
      setSuccess('Payment slips generated successfully!');
      fetchSlips();
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to generate slips');
    } finally {
      setGenerating(false);
    }
  };

  const handlePublish = async () => {
    setPublishing(true);
    setError('');
    setSuccess('');
    try {
      await paymentService.publishSlips({ month: genMonth, year: genYear });
      setSuccess('Payment slips published to employees successfully!');
      fetchSlips();
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to publish slips');
    } finally {
      setPublishing(false);
    }
  };

  const handleOvertimeUpload = async () => {
    if (!overtimeDialog || !overtimeHours) return;
    setError('');
    try {
      await paymentService.uploadOvertime(overtimeDialog, { overtime_hours: parseFloat(overtimeHours) });
      setSuccess('Overtime uploaded');
      setOvertimeDialog(null);
      setOvertimeHours('');
      fetchSlips();
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to upload overtime');
    }
  };

  if (loading) return <LoadingSpinner />;

  return (
    <Box>
      <Typography variant="h5" sx={{ fontWeight: 700, mb: 3 }}>Payment Management</Typography>
      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError('')}>{error}</Alert>}
      {success && <Alert severity="success" sx={{ mb: 2 }} onClose={() => setSuccess('')}>{success}</Alert>}

      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>Generate Payment Slips</Typography>
          <Grid container spacing={2} alignItems="center">
            <Grid item xs={4}>
              <TextField select fullWidth label="Month" value={genMonth} onChange={(e) => setGenMonth(e.target.value)}
                size="small">
                {[
                  { v: 1, l: 'January' }, { v: 2, l: 'February' }, { v: 3, l: 'March' },
                  { v: 4, l: 'April' }, { v: 5, l: 'May' }, { v: 6, l: 'June' },
                  { v: 7, l: 'July' }, { v: 8, l: 'August' }, { v: 9, l: 'September' },
                  { v: 10, l: 'October' }, { v: 11, l: 'November' }, { v: 12, l: 'December' }
                ].map((m) => <MenuItem key={m.v} value={m.v}>{m.l}</MenuItem>)}
              </TextField>
            </Grid>
            <Grid item xs={4}>
              <TextField fullWidth label="Year" value={genYear} onChange={(e) => setGenYear(e.target.value)} size="small" />
            </Grid>
            <Grid item xs={2}>
              <Button variant="contained" startIcon={<Add />} onClick={handleGenerate} disabled={generating} fullWidth>
                {generating ? 'Generating...' : 'Generate'}
              </Button>
            </Grid>
            <Grid item xs={2}>
              <Button variant="outlined" color="secondary" startIcon={<Upload />} onClick={handlePublish} disabled={publishing} fullWidth>
                {publishing ? 'Publishing...' : 'Publish'}
              </Button>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      {slips.length > 0 && (
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
          <TextField
            size="small"
            placeholder="Search by employee name or ID"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            sx={{ width: 320 }}
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <Search color="action" />
                </InputAdornment>
              ),
            }}
          />
          <Button
            variant="outlined"
            color="error"
            startIcon={<PictureAsPdf />}
            onClick={() => downloadAllPaymentSlipPDFs(slips)}
          >
            Download All PDFs
          </Button>
        </Box>
      )}

      <TableContainer component={Paper}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Employee</TableCell>
              <TableCell>Month</TableCell>
              <TableCell>Basic</TableCell>
              <TableCell>Overtime</TableCell>
              <TableCell>Net Salary</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {(() => {
              const query = searchQuery.toLowerCase().trim();
              const filtered = query
                ? slips.filter((s) => {
                    const name = (s.user_full_name || s.user_username || s.employee_name || '').toLowerCase();
                    const empId = String(s.employee_number || s.user || '').toLowerCase();
                    return name.includes(query) || empId.includes(query);
                  })
                : slips;
              return filtered.length === 0 ? (
                <TableRow><TableCell colSpan={6} align="center">{query ? 'No matching employees found' : 'No payment slips found'}</TableCell></TableRow>
              ) : (
                filtered.map((s) => (
                <TableRow key={s.id}>
                  <TableCell sx={{ fontWeight: 600 }}>{s.user_username || s.employee_name || '-'}</TableCell>
                  <TableCell>{s.month || '-'}</TableCell>
                  <TableCell>{formatCurrency(s.basic_salary)}</TableCell>
                  <TableCell>{formatCurrency(s.overtime_pay)}</TableCell>
                  <TableCell sx={{ fontWeight: 700, color: 'primary.main' }}>{formatCurrency(s.net_salary)}</TableCell>
                  <TableCell>
                    <Box sx={{ display: 'flex', gap: 0.5, alignItems: 'center' }}>
                      <Button size="small" startIcon={<AccessTime />} onClick={() => setOvertimeDialog(s.id)}>Overtime</Button>
                      <Box sx={{ width: 40 }} />
                      <Button size="small" color="primary" startIcon={<Visibility />} onClick={() => viewPaymentSlipPDF(s)}>View</Button>
                      <Box sx={{ width: 40 }} />
                      <Button size="small" color="error" startIcon={<Download />} onClick={() => downloadPaymentSlipPDF(s)}>Download</Button>
                    </Box>
                  </TableCell>
                </TableRow>
              ))
              );
            })()}
          </TableBody>
        </Table>
      </TableContainer>

      <Dialog open={!!overtimeDialog} onClose={() => setOvertimeDialog(null)} maxWidth="xs" fullWidth>
        <DialogTitle>Upload Overtime Hours</DialogTitle>
        <DialogContent>
          <TextField fullWidth label="Overtime Hours" type="number" value={overtimeHours}
            onChange={(e) => setOvertimeHours(e.target.value)} sx={{ mt: 1 }} />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOvertimeDialog(null)}>Cancel</Button>
          <Button variant="contained" onClick={handleOvertimeUpload}>Upload</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
