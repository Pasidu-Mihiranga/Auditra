from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    RegisterView, 
    LoginView, 
    UserProfileView,
    AssignRoleView,
    AllUsersView,
    RoleListView,
    MyRoleView,
    ChangePasswordView,
    CheckUserByEmailView,
    CreateClientAccountView,
    CreateAgentAccountView
)

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('profile/', UserProfileView.as_view(), name='profile'),
    path('my-role/', MyRoleView.as_view(), name='my-role'),
    path('roles/', RoleListView.as_view(), name='roles'),
    path('assign-role/', AssignRoleView.as_view(), name='assign-role'),
    path('users/', AllUsersView.as_view(), name='all-users'),
    path('change-password/', ChangePasswordView.as_view(), name='change-password'),
    path('check-user-by-email/', CheckUserByEmailView.as_view(), name='check-user-by-email'),
    path('create-client-account/', CreateClientAccountView.as_view(), name='create-client-account'),
    path('create-agent-account/', CreateAgentAccountView.as_view(), name='create-agent-account'),
]

