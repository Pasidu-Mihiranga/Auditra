import { Chip, useTheme } from '@mui/material';
import { getStatusColor } from '../utils/helpers';

export default function StatusChip({ status, label }) {
  const theme = useTheme();
  const color = getStatusColor(status);
  return (
    <Chip
      label={label || status?.replace(/_/g, ' ')}
      size="small"
      sx={{
        bgcolor: `${color}20`,
        color: color,
        fontWeight: 600,
        textTransform: 'capitalize',
        fontSize: 12,
        border: theme.palette.mode === 'dark' ? `1px solid ${color}40` : 'none',
      }}
    />
  );
}
