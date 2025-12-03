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
    GeneratePaymentSlipsView,
    MyPaymentSlipsView,
    AllPaymentSlipsView,
    PaymentSlipDetailView
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
    path('payment-slips/generate/', GeneratePaymentSlipsView.as_view(), name='generate-payment-slips'),
    path('payment-slips/my/', MyPaymentSlipsView.as_view(), name='my-payment-slips'),
    path('payment-slips/', AllPaymentSlipsView.as_view(), name='all-payment-slips'),
    path('payment-slips/<int:pk>/', PaymentSlipDetailView.as_view(), name='payment-slip-detail'),
]

