from rest_framework import status, generics
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny, IsAuthenticated, IsAdminUser
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from .models import UserRole
from .serializers import (
    UserRegistrationSerializer, 
    UserSerializer, 
    UserDetailSerializer,
    LoginSerializer,
    AssignRoleSerializer,
    UserRoleSerializer,
    ChangePasswordSerializer
)


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = (AllowAny,)
    serializer_class = UserRegistrationSerializer
    
    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        
        # Generate JWT tokens
        refresh = RefreshToken.for_user(user)
        
        # Get user with role info
        user_data = UserSerializer(user).data
        
        return Response({
            'user': user_data,
            'refresh': str(refresh),
            'access': str(refresh.access_token),
            'message': 'User registered successfully'
        }, status=status.HTTP_201_CREATED)


class LoginView(APIView):
    permission_classes = (AllowAny,)
    serializer_class = LoginSerializer
    
    def post(self, request):
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        username = serializer.validated_data['username']
        password = serializer.validated_data['password']
        
        user = authenticate(username=username, password=password)
        
        if user is not None:
            refresh = RefreshToken.for_user(user)
            user_data = UserSerializer(user).data
            
            # Check if password change is required (for clients/agents who haven't changed password)
            password_change_required = False
            if hasattr(user, 'role'):
                user_role = user.role.role
                if user_role in ['client', 'agent'] and not user.role.password_changed:
                    password_change_required = True
            
            return Response({
                'user': user_data,
                'refresh': str(refresh),
                'access': str(refresh.access_token),
                'password_change_required': password_change_required,
                'message': 'Login successful'
            }, status=status.HTTP_200_OK)
        else:
            return Response({
                'error': 'Invalid credentials'
            }, status=status.HTTP_401_UNAUTHORIZED)


class UserProfileView(generics.RetrieveAPIView):
    permission_classes = (IsAuthenticated,)
    serializer_class = UserDetailSerializer
    
    def get_object(self):
        return self.request.user


class AssignRoleView(APIView):
    """Admin endpoint to assign roles to users"""
    permission_classes = (IsAuthenticated,)
    
    def post(self, request):
        # Check if user is admin
        if not hasattr(request.user, 'role') or request.user.role.role != 'admin':
            return Response({
                'error': 'Only admins can assign roles'
            }, status=status.HTTP_403_FORBIDDEN)
        
        serializer = AssignRoleSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        user_id = serializer.validated_data['user_id']
        role = serializer.validated_data['role']
        
        # Prevent assigning admin role to other users
        if role == 'admin':
            return Response({
                'error': 'Admin role cannot be assigned. Only the system admin has this role.'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            user = User.objects.get(id=user_id)
            
            # Prevent changing the system admin's role
            if user.role.role == 'admin':
                return Response({
                    'error': 'Cannot change the role of the system admin'
                }, status=status.HTTP_403_FORBIDDEN)
            
            user_role = user.role
            user_role.role = role
            user_role.assigned_by = request.user
            user_role.save()
            
            return Response({
                'message': 'Role assigned successfully',
                'user': UserDetailSerializer(user).data
            }, status=status.HTTP_200_OK)
        except User.DoesNotExist:
            return Response({
                'error': 'User not found'
            }, status=status.HTTP_404_NOT_FOUND)


class AllUsersView(generics.ListAPIView):
    """Admin endpoint to view all users"""
    permission_classes = (IsAuthenticated,)
    serializer_class = UserDetailSerializer
    
    def get_queryset(self):
        # Check if user is admin
        if not hasattr(self.request.user, 'role') or self.request.user.role.role != 'admin':
            return User.objects.none()
        return User.objects.all().order_by('-date_joined')


class RoleListView(APIView):
    """Get available roles (excluding admin and unassigned)"""
    permission_classes = (IsAuthenticated,)
    
    def get(self, request):
        roles = [
            {'value': role[0], 'label': role[1]} 
            for role in UserRole.ROLE_CHOICES
            if role[0] not in ['unassigned', 'admin']  # Exclude admin role from assignment
        ]
        return Response({'roles': roles}, status=status.HTTP_200_OK)


class MyRoleView(APIView):
    """Get current user's role"""
    permission_classes = (IsAuthenticated,)
    
    def get(self, request):
        if hasattr(request.user, 'role'):
            serializer = UserRoleSerializer(request.user.role)
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response({
            'error': 'Role not found'
        }, status=status.HTTP_404_NOT_FOUND)


class ChangePasswordView(APIView):
    """Change password endpoint (one-time only for clients/agents)"""
    permission_classes = (IsAuthenticated,)
    
    def post(self, request):
        # Only clients and agents can use this endpoint
        if not hasattr(request.user, 'role'):
            return Response({
                'error': 'User role not found'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        user_role = request.user.role.role
        if user_role not in ['client', 'agent']:
            return Response({
                'error': 'Password change is only available for clients and agents'
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Check if password has already been changed
        if request.user.role.password_changed:
            return Response({
                'error': 'Password has already been changed. You cannot change it again.'
            }, status=status.HTTP_403_FORBIDDEN)
        
        serializer = ChangePasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        old_password = serializer.validated_data['old_password']
        new_password = serializer.validated_data['new_password']
        
        # Verify old password
        if not request.user.check_password(old_password):
            return Response({
                'error': 'Current password is incorrect'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Set new password
        request.user.set_password(new_password)
        request.user.save()
        
        # Mark password as changed
        request.user.role.password_changed = True
        request.user.role.save()
        
        return Response({
            'message': 'Password changed successfully'
        }, status=status.HTTP_200_OK)
