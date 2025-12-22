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
from projects.utils import check_user_by_email, create_user_account
from .services import EmailService


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


class CheckUserByEmailView(APIView):
    """Check if a user exists by email and return their role"""
    permission_classes = (IsAuthenticated,)
    
    def post(self, request):
        try:
            email = request.data.get('email', '').strip().lower()
            role_type = request.data.get('role_type', '')  # 'client' or 'agent'
            
            if not email:
                return Response({
                    'exists': False,
                    'error': 'Email is required'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            if role_type not in ['client', 'agent']:
                return Response({
                    'exists': False,
                    'error': 'Invalid role type. Must be "client" or "agent"'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Check if user exists (optimized query)
            try:
                user = User.objects.select_related('role').get(email=email)
            except User.DoesNotExist:
                return Response({
                    'exists': False,
                    'message': f'{role_type.capitalize()} does not exist'
                }, status=status.HTTP_200_OK)
            except User.MultipleObjectsReturned:
                # Handle edge case of duplicate emails
                user = User.objects.select_related('role').filter(email=email).first()
            
            if user:
                # Check if user has the correct role
                if hasattr(user, 'role') and user.role.role == role_type:
                    return Response({
                        'exists': True,
                        'user_id': user.id,
                        'username': user.username,
                        'name': f"{user.first_name} {user.last_name}".strip() or user.username,
                        'role': user.role.role,
                        'message': f'{role_type.capitalize()} already exists'
                    }, status=status.HTTP_200_OK)
                else:
                    # User exists but has different role
                    return Response({
                        'exists': False,
                        'error': f'User with this email exists but is not a {role_type}',
                        'current_role': user.role.role if hasattr(user, 'role') else None
                    }, status=status.HTTP_200_OK)
            else:
                return Response({
                    'exists': False,
                    'message': f'{role_type.capitalize()} does not exist'
                }, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({
                'exists': False,
                'error': f'Error checking user: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CreateClientAccountView(APIView):
    """Create a client account and send credentials via email"""
    permission_classes = (IsAuthenticated,)
    
    def post(self, request):
        # Only coordinators can create client accounts
        if not hasattr(request.user, 'role') or request.user.role.role != 'coordinator':
            return Response({
                'error': 'Only coordinators can create client accounts'
            }, status=status.HTTP_403_FORBIDDEN)
        
        email = request.data.get('email', '').strip().lower()
        name = request.data.get('name', '').strip()
        phone = request.data.get('phone', '').strip() or None
        address = request.data.get('address', '').strip() or None
        company = request.data.get('company', '').strip() or None
        
        if not email or not name:
            return Response({
                'error': 'Email and name are required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Check if user already exists
        existing_user = check_user_by_email(email)
        if existing_user:
            if hasattr(existing_user, 'role') and existing_user.role.role == 'client':
                return Response({
                    'error': 'Client with this email already exists',
                    'user_id': existing_user.id
                }, status=status.HTTP_400_BAD_REQUEST)
            else:
                return Response({
                    'error': f'User with this email exists but is not a client (current role: {existing_user.role.role})'
                }, status=status.HTTP_400_BAD_REQUEST)
        
        # Create client account
        user, password = create_user_account(
            email=email,
            name=name,
            role_type='client',
            phone=phone,
            address=address,
            company=company
        )
        
        if user:
            # Send email with credentials asynchronously (don't wait for it)
            try:
                from threading import Thread
                import logging
                logger = logging.getLogger(__name__)
                
                def send_email_async():
                    try:
                        logger.info(f"Starting async email send for client {email}")
                        result = EmailService.send_account_credentials(
                            email=email,
                            username=user.username,
                            password=password,
                            user_type='client',
                            name=name
                        )
                        if result:
                            logger.info(f"Email sent successfully to {email}")
                        else:
                            logger.error(f"Email sending failed for {email}")
                    except Exception as e:
                        logger.error(f"Exception in async email send for {email}: {e}", exc_info=True)
                
                # Use non-daemon thread to ensure email is sent
                email_thread = Thread(target=send_email_async, daemon=False)
                email_thread.start()
                logger.info(f"Started async email thread for client {email}")
            except Exception as e:
                # Log error but don't fail the request
                import logging
                logger = logging.getLogger(__name__)
                logger.error(f"Failed to start email thread: {e}", exc_info=True)
            
            return Response({
                'success': True,
                'message': 'Client account created successfully. Credentials will be sent via email.',
                'user': {
                    'id': user.id,
                    'username': user.username,
                    'email': user.email,
                    'name': f"{user.first_name} {user.last_name}".strip() or user.username
                }
            }, status=status.HTTP_201_CREATED)
        else:
            return Response({
                'error': 'Failed to create client account'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CreateAgentAccountView(APIView):
    """Create an agent account and send credentials via email"""
    permission_classes = (IsAuthenticated,)
    
    def post(self, request):
        # Only coordinators can create agent accounts
        if not hasattr(request.user, 'role') or request.user.role.role != 'coordinator':
            return Response({
                'error': 'Only coordinators can create agent accounts'
            }, status=status.HTTP_403_FORBIDDEN)
        
        email = request.data.get('email', '').strip().lower()
        name = request.data.get('name', '').strip()
        phone = request.data.get('phone', '').strip() or None
        address = request.data.get('address', '').strip() or None
        
        if not email or not name:
            return Response({
                'error': 'Email and name are required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Check if user already exists
        existing_user = check_user_by_email(email)
        if existing_user:
            if hasattr(existing_user, 'role') and existing_user.role.role == 'agent':
                return Response({
                    'error': 'Agent with this email already exists',
                    'user_id': existing_user.id
                }, status=status.HTTP_400_BAD_REQUEST)
            else:
                return Response({
                    'error': f'User with this email exists but is not an agent (current role: {existing_user.role.role})'
                }, status=status.HTTP_400_BAD_REQUEST)
        
        # Create agent account
        user, password = create_user_account(
            email=email,
            name=name,
            role_type='agent',
            phone=phone,
            address=address
        )
        
        if user:
            # Send email with credentials asynchronously (don't wait for it)
            try:
                from threading import Thread
                import logging
                logger = logging.getLogger(__name__)
                
                def send_email_async():
                    try:
                        logger.info(f"Starting async email send for agent {email}")
                        result = EmailService.send_account_credentials(
                            email=email,
                            username=user.username,
                            password=password,
                            user_type='agent',
                            name=name
                        )
                        if result:
                            logger.info(f"Email sent successfully to {email}")
                        else:
                            logger.error(f"Email sending failed for {email}")
                    except Exception as e:
                        logger.error(f"Exception in async email send for {email}: {e}", exc_info=True)
                
                # Use non-daemon thread to ensure email is sent
                email_thread = Thread(target=send_email_async, daemon=False)
                email_thread.start()
                logger.info(f"Started async email thread for agent {email}")
            except Exception as e:
                # Log error but don't fail the request
                import logging
                logger = logging.getLogger(__name__)
                logger.error(f"Failed to start email thread: {e}", exc_info=True)
            
            return Response({
                'success': True,
                'message': 'Agent account created successfully. Credentials will be sent via email.',
                'user': {
                    'id': user.id,
                    'username': user.username,
                    'email': user.email,
                    'name': f"{user.first_name} {user.last_name}".strip() or user.username
                }
            }, status=status.HTTP_201_CREATED)
        else:
            return Response({
                'error': 'Failed to create agent account'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
