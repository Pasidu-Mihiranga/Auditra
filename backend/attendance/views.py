from rest_framework import status, generics
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from django.db.models import Sum, Count, Q
from datetime import datetime, date, timedelta, time
from django.contrib.auth.models import User
from .models import Attendance, Holiday
from .serializers import (
    AttendanceSerializer,
    AttendanceSummarySerializer,
    HolidaySerializer
)


class MarkAttendanceView(APIView):
    """Mark attendance (check-in) for the current day"""
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        today = timezone.now().date()
        user = request.user
        
        # Check if it's a working day
        if not Attendance.is_working_day(today):
            return Response({
                'error': 'Today is not a working day (Sunday or Holiday)'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Check if attendance already marked
        attendance, created = Attendance.objects.get_or_create(
            user=user,
            date=today,
            defaults={
                'check_in': timezone.now(),
                'status': 'present'
            }
        )
        
        if not created:
            if attendance.check_in:
                return Response({
                    'error': 'Attendance already marked for today'
                }, status=status.HTTP_400_BAD_REQUEST)
            else:
                attendance.check_in = timezone.now()
                attendance.status = 'present'
                attendance.save()
        
        serializer = AttendanceSerializer(attendance)
        return Response({
            'message': 'Attendance marked successfully',
            'data': serializer.data
        }, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)


class LeaveEarlyView(APIView):
    """Mark early leave (check-out before 5 PM)"""
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        today = timezone.now().date()
        user = request.user
        
        try:
            attendance = Attendance.objects.get(user=user, date=today)
        except Attendance.DoesNotExist:
            return Response({
                'error': 'Please mark attendance first'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        if attendance.check_out:
            return Response({
                'error': 'Already checked out for today'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Mark check-out
        attendance.check_out = timezone.now()
        attendance.save()  # This will calculate working hours and update status
        
        serializer = AttendanceSerializer(attendance)
        return Response({
            'message': 'Early leave marked successfully',
            'data': serializer.data,
            'is_full_day': attendance.is_full_day(),
            'working_hours': float(attendance.working_hours)
        }, status=status.HTTP_200_OK)


class CheckOutView(APIView):
    """Regular check-out at 5 PM"""
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        today = timezone.now().date()
        user = request.user
        
        try:
            attendance = Attendance.objects.get(user=user, date=today)
        except Attendance.DoesNotExist:
            return Response({
                'error': 'Please mark attendance first'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        if attendance.check_out:
            return Response({
                'error': 'Already checked out for today'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Mark check-out at 5 PM or current time if after 5 PM
        now = timezone.now()
        five_pm = timezone.make_aware(
            datetime.combine(today, time(17, 0))
        )
        
        attendance.check_out = min(now, five_pm)
        attendance.save()
        
        serializer = AttendanceSerializer(attendance)
        return Response({
            'message': 'Checked out successfully',
            'data': serializer.data
        }, status=status.HTTP_200_OK)


class StartOvertimeView(APIView):
    """Start overtime work (after 5 PM)"""
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        today = timezone.now().date()
        user = request.user
        
        try:
            attendance = Attendance.objects.get(user=user, date=today)
        except Attendance.DoesNotExist:
            return Response({
                'error': 'Please mark attendance first'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Check if already checked out
        if not attendance.check_out:
            return Response({
                'error': 'Please check out first before starting overtime'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Check if overtime already started
        if attendance.overtime_start:
            return Response({
                'error': 'Overtime already started'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Check if it's after 5 PM
        now = timezone.now()
        five_pm = timezone.make_aware(
            datetime.combine(today, time(17, 0))
        )
        
        if now < five_pm:
            return Response({
                'error': 'Overtime can only start after 5 PM'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        attendance.overtime_start = now
        attendance.save()
        
        serializer = AttendanceSerializer(attendance)
        return Response({
            'message': 'Overtime started successfully',
            'data': serializer.data
        }, status=status.HTTP_200_OK)


class EndOvertimeView(APIView):
    """End overtime work"""
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        today = timezone.now().date()
        user = request.user
        
        try:
            attendance = Attendance.objects.get(user=user, date=today)
        except Attendance.DoesNotExist:
            return Response({
                'error': 'Attendance not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        if not attendance.overtime_start:
            return Response({
                'error': 'Overtime not started'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        if attendance.overtime_end:
            return Response({
                'error': 'Overtime already ended'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        attendance.overtime_end = timezone.now()
        attendance.save()
        
        serializer = AttendanceSerializer(attendance)
        return Response({
            'message': 'Overtime ended successfully',
            'data': serializer.data,
            'overtime_hours': float(attendance.overtime_hours)
        }, status=status.HTTP_200_OK)


class TodayAttendanceView(APIView):
    """Get today's attendance status"""
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        today = timezone.now().date()
        user = request.user
        
        try:
            attendance = Attendance.objects.get(user=user, date=today)
            serializer = AttendanceSerializer(attendance)
            return Response({
                'success': True,
                'data': serializer.data
            }, status=status.HTTP_200_OK)
        except Attendance.DoesNotExist:
            # Check if it's a working day
            is_working_day = Attendance.is_working_day(today)
            return Response({
                'success': False,
                'data': None,
                'is_working_day': is_working_day,
                'message': 'Attendance not marked for today' if is_working_day else 'Today is not a working day'
            }, status=status.HTTP_200_OK)


class AttendanceSummaryView(APIView):
    """Get attendance summary (daily, weekly, monthly, yearly)"""
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        period = request.query_params.get('period', 'daily')  # daily, weekly, monthly, yearly
        user = request.user
        
        today = timezone.now().date()
        
        if period == 'daily':
            # Today's attendance
            try:
                attendance = Attendance.objects.get(user=user, date=today)
                data = {
                    'date': today,
                    'attendance': AttendanceSerializer(attendance).data,
                    'summary': {
                        'present': 1 if attendance.status == 'present' else 0,
                        'half_day': 1 if attendance.status == 'half_day' else 0,
                        'absent': 1 if attendance.status == 'absent' else 0,
                        'working_hours': float(attendance.working_hours),
                        'overtime_hours': float(attendance.overtime_hours),
                    }
                }
            except Attendance.DoesNotExist:
                data = {
                    'date': today,
                    'attendance': None,
                    'summary': {
                        'present': 0,
                        'half_day': 0,
                        'absent': 1,
                        'working_hours': 0.0,
                        'overtime_hours': 0.0,
                    }
                }
        
        elif period == 'weekly':
            # This week's attendance
            week_start = today - timedelta(days=today.weekday())
            week_end = week_start + timedelta(days=6)
            
            attendances = Attendance.objects.filter(
                user=user,
                date__range=[week_start, week_end]
            )
            
            data = self._calculate_summary(attendances, week_start, week_end)
        
        elif period == 'monthly':
            # This month's attendance
            month_start = today.replace(day=1)
            if today.month == 12:
                month_end = today.replace(year=today.year + 1, month=1, day=1) - timedelta(days=1)
            else:
                month_end = today.replace(month=today.month + 1, day=1) - timedelta(days=1)
            
            attendances = Attendance.objects.filter(
                user=user,
                date__range=[month_start, month_end]
            )
            
            data = self._calculate_summary(attendances, month_start, month_end)
        
        elif period == 'yearly':
            # This year's attendance
            year_start = today.replace(month=1, day=1)
            year_end = today.replace(month=12, day=31)
            
            attendances = Attendance.objects.filter(
                user=user,
                date__range=[year_start, year_end]
            )
            
            data = self._calculate_summary(attendances, year_start, year_end)
        
        else:
            return Response({
                'error': 'Invalid period. Use: daily, weekly, monthly, yearly'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        return Response({
            'period': period,
            'data': data
        }, status=status.HTTP_200_OK)
    
    def _calculate_summary(self, attendances, start_date, end_date):
        """Calculate summary statistics for a date range"""
        total_days = (end_date - start_date).days + 1
        
        # Count working days (excluding Sundays and holidays)
        working_days = 0
        current_date = start_date
        holidays = set(Holiday.objects.filter(
            date__range=[start_date, end_date],
            is_active=True
        ).values_list('date', flat=True))
        
        while current_date <= end_date:
            if current_date.weekday() != 6 and current_date not in holidays:
                working_days += 1
            current_date += timedelta(days=1)
        
        present_count = attendances.filter(status='present').count()
        half_day_count = attendances.filter(status='half_day').count()
        absent_count = working_days - present_count - half_day_count
        
        total_working_hours = attendances.aggregate(
            total=Sum('working_hours')
        )['total'] or 0.0
        
        total_overtime_hours = attendances.aggregate(
            total=Sum('overtime_hours')
        )['total'] or 0.0
        
        attendance_percentage = 0.0
        if working_days > 0:
            attendance_percentage = ((present_count + half_day_count * 0.5) / working_days) * 100
        
        # Get daily breakdown for charts
        daily_data = []
        current_date = start_date
        while current_date <= end_date:
            if current_date.weekday() != 6 and current_date not in holidays:
                try:
                    att = attendances.get(date=current_date)
                    daily_data.append({
                        'date': current_date.isoformat(),
                        'status': att.status,
                        'working_hours': float(att.working_hours),
                        'overtime_hours': float(att.overtime_hours),
                    })
                except Attendance.DoesNotExist:
                    daily_data.append({
                        'date': current_date.isoformat(),
                        'status': 'absent',
                        'working_hours': 0.0,
                        'overtime_hours': 0.0,
                    })
            current_date += timedelta(days=1)
        
        return {
            'start_date': start_date.isoformat(),
            'end_date': end_date.isoformat(),
            'total_days': total_days,
            'working_days': working_days,
            'summary': {
                'present': present_count,
                'half_day': half_day_count,
                'absent': absent_count,
                'total_working_hours': float(total_working_hours),
                'total_overtime_hours': float(total_overtime_hours),
                'attendance_percentage': round(float(attendance_percentage), 2),
            },
            'daily_data': daily_data
        }


class MyAttendancesView(generics.ListAPIView):
    """Get all attendances for the current user"""
    permission_classes = [IsAuthenticated]
    serializer_class = AttendanceSerializer
    
    def get_queryset(self):
        return Attendance.objects.filter(user=self.request.user).order_by('-date')

