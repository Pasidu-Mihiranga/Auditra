from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone
from datetime import datetime, time, timedelta


class Holiday(models.Model):
    """Sri Lankan public holidays"""
    name = models.CharField(max_length=200)
    date = models.DateField(unique=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'holidays'
        verbose_name = 'Holiday'
        verbose_name_plural = 'Holidays'
        ordering = ['date']
    
    def __str__(self):
        return f"{self.name} - {self.date}"


class Attendance(models.Model):
    """Attendance tracking for field officers"""
    
    STATUS_CHOICES = [
        ('present', 'Present'),
        ('half_day', 'Half Day'),
        ('absent', 'Absent'),
        ('leave', 'On Leave'),
    ]
    
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='attendances')
    date = models.DateField()
    
    # Regular working hours (8 AM - 5 PM)
    check_in = models.DateTimeField(null=True, blank=True)
    check_out = models.DateTimeField(null=True, blank=True)
    
    # Overtime hours (after 5 PM)
    overtime_start = models.DateTimeField(null=True, blank=True)
    overtime_end = models.DateTimeField(null=True, blank=True)
    
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='absent')
    
    # Calculated fields
    working_hours = models.DecimalField(max_digits=5, decimal_places=2, default=0.00)  # Hours worked (8 AM - 5 PM)
    overtime_hours = models.DecimalField(max_digits=5, decimal_places=2, default=0.00)  # Overtime hours
    
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'attendances'
        verbose_name = 'Attendance'
        verbose_name_plural = 'Attendances'
        unique_together = ['user', 'date']
        ordering = ['-date', '-check_in']
    
    def __str__(self):
        return f"{self.user.username} - {self.date} - {self.get_status_display()}"
    
    def calculate_working_hours(self):
        """Calculate working hours from check_in to check_out"""
        if self.check_in and self.check_out:
            duration = self.check_out - self.check_in
            hours = duration.total_seconds() / 3600
            # Cap at 9 hours (8 AM to 5 PM)
            return min(hours, 9.0)
        return 0.0
    
    def calculate_overtime_hours(self):
        """Calculate overtime hours"""
        if self.overtime_start and self.overtime_end:
            duration = self.overtime_end - self.overtime_start
            return duration.total_seconds() / 3600
        return 0.0
    
    def is_full_day(self):
        """Check if it's a full day (at least 4.5 hours)"""
        return self.working_hours >= 4.5
    
    def save(self, *args, **kwargs):
        # Calculate working hours
        if self.check_in and self.check_out:
            self.working_hours = self.calculate_working_hours()
            # Determine status based on working hours
            if self.working_hours >= 4.5:
                self.status = 'present'
            elif self.working_hours > 0:
                self.status = 'half_day'
        
        # Calculate overtime hours
        if self.overtime_start and self.overtime_end:
            self.overtime_hours = self.calculate_overtime_hours()
        
        super().save(*args, **kwargs)
    
    @staticmethod
    def is_working_day(date):
        """Check if a date is a working day (not Sunday and not a holiday)"""
        # Check if it's Sunday
        if date.weekday() == 6:  # Sunday is 6
            return False
        
        # Check if it's a holiday
        if Holiday.objects.filter(date=date, is_active=True).exists():
            return False
        
        return True

