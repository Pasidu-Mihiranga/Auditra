from django.urls import path
from .views import (
    RegisterView, 
    LoginView, 
    UserProfileView,
    AssignRoleView,
    AllUsersView,
    RoleListView,
    MyRoleView
)

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('profile/', UserProfileView.as_view(), name='profile'),
    path('my-role/', MyRoleView.as_view(), name='my-role'),
    path('roles/', RoleListView.as_view(), name='roles'),
    path('assign-role/', AssignRoleView.as_view(), name='assign-role'),
    path('users/', AllUsersView.as_view(), name='all-users'),
]

