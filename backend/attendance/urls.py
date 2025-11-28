from django.urls import path
from . import views

app_name = 'attendance'

urlpatterns = [
    path('mark/', views.MarkAttendanceView.as_view(), name='mark-attendance'),
    path('leave-early/', views.LeaveEarlyView.as_view(), name='leave-early'),
    path('checkout/', views.CheckOutView.as_view(), name='checkout'),
    path('overtime/start/', views.StartOvertimeView.as_view(), name='start-overtime'),
    path('overtime/end/', views.EndOvertimeView.as_view(), name='end-overtime'),
    path('today/', views.TodayAttendanceView.as_view(), name='today-attendance'),
    path('summary/', views.AttendanceSummaryView.as_view(), name='attendance-summary'),
    path('my-attendances/', views.MyAttendancesView.as_view(), name='my-attendances'),
]

