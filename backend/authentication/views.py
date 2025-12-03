from rest_framework import status, generics
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny, IsAuthenticated, IsAdminUser
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.utils import timezone
from .models import UserRole, PaymentSlip
from .serializers import (
    UserRegistrationSerializer, 
    UserSerializer, 
    UserDetailSerializer,
    LoginSerializer,
    AssignRoleSerializer,
    UserRoleSerializer,
    PaymentSlipSerializer
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
            
            return Response({
                'user': user_data,
                'refresh': str(refresh),
                'access': str(refresh.access_token),
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
            {
                'value': role[0], 
                'label': role[1],
                'salary': UserRole.get_role_salary(role[0])
            } 
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


class GeneratePaymentSlipsView(APIView):
    """Admin endpoint to generate payment slips for all users"""
    permission_classes = (IsAuthenticated,)
    
    def post(self, request):
        # Check if user is admin
        if not hasattr(request.user, 'role') or request.user.role.role != 'admin':
            return Response({
                'error': 'Only admins can generate payment slips'
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Get month and year from request, or use current month/year
        month = request.data.get('month', timezone.now().month)
        year = request.data.get('year', timezone.now().year)
        
        # Validate month and year
        if not (1 <= month <= 12):
            return Response({
                'error': 'Invalid month. Must be between 1 and 12.'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        if year < 2000 or year > 2100:
            return Response({
                'error': 'Invalid year.'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Generate payment slips
        try:
            # Check if force_regenerate is requested (default to True to update existing slips)
            force_regenerate = request.data.get('force_regenerate', True)
            
            result = PaymentSlip.generate_for_all_users(
                month=month,
                year=year,
                generated_by=request.user,
                force_regenerate=force_regenerate
            )
            
            generated_count = result.get('generated', 0)
            updated_count = result.get('updated', 0)
            total_count = result.get('total', 0)
            
            message = f'Payment slips processed successfully: {generated_count} created, {updated_count} updated (Total: {total_count} users)'
            if total_count == 0:
                message = 'No payment slips generated. All eligible users may already have payment slips for this month/year, or no users match the criteria.'
            
            return Response({
                'message': message,
                'month': month,
                'year': year,
                'generated_count': generated_count,
                'updated_count': updated_count,
                'total_count': total_count
            }, status=status.HTTP_201_CREATED)
        except Exception as e:
            return Response({
                'error': f'Error generating payment slips: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class MyPaymentSlipsView(generics.ListAPIView):
    """Get current user's payment slips (only for allowed roles). Auto-generates if missing."""
    permission_classes = (IsAuthenticated,)
    serializer_class = PaymentSlipSerializer
    
    def get_queryset(self):
        # Only allow these roles to view payment slips
        allowed_roles = [
            'coordinator', 'field_officer', 'accessor', 
            'senior_valuer', 'md_gm', 'hr_staff', 'general_employee'
        ]
        
        # Check if user has an allowed role
        if hasattr(self.request.user, 'role') and self.request.user.role:
            user_role = self.request.user.role.role
            if user_role in allowed_roles:
                # Auto-generate payment slip for current month/year if it doesn't exist
                PaymentSlip.generate_for_user(
                    user=self.request.user,
                    generated_by=None  # Auto-generated by system
                )
                return PaymentSlip.objects.filter(user=self.request.user).order_by('-year', '-month')
        
        # Return empty queryset for client, agent, unassigned, etc.
        return PaymentSlip.objects.none()


class AllPaymentSlipsView(generics.ListAPIView):
    """Admin endpoint to view all payment slips"""
    permission_classes = (IsAuthenticated,)
    serializer_class = PaymentSlipSerializer
    
    def get_queryset(self):
        # Check if user is admin
        if not hasattr(self.request.user, 'role') or self.request.user.role.role != 'admin':
            return PaymentSlip.objects.none()
        
        queryset = PaymentSlip.objects.all().order_by('-year', '-month', 'user__username')
        
        # Optional filters
        month = self.request.query_params.get('month', None)
        year = self.request.query_params.get('year', None)
        user_id = self.request.query_params.get('user_id', None)
        
        if month:
            queryset = queryset.filter(month=month)
        if year:
            queryset = queryset.filter(year=year)
        if user_id:
            queryset = queryset.filter(user_id=user_id)
        
        return queryset


class PaymentSlipDetailView(generics.RetrieveAPIView):
    """Get payment slip details"""
    permission_classes = (IsAuthenticated,)
    serializer_class = PaymentSlipSerializer
    
    def get_queryset(self):
        # Only allow these roles to view payment slips
        allowed_roles = [
            'coordinator', 'field_officer', 'accessor', 
            'senior_valuer', 'md_gm', 'hr_staff', 'general_employee'
        ]
        
        # Admins can see all payment slips
        if hasattr(self.request.user, 'role') and self.request.user.role.role == 'admin':
            return PaymentSlip.objects.all()
        
        # Users with allowed roles can only see their own payment slips
        if hasattr(self.request.user, 'role') and self.request.user.role:
            user_role = self.request.user.role.role
            if user_role in allowed_roles:
                return PaymentSlip.objects.filter(user=self.request.user)
        
        # Return empty queryset for client, agent, unassigned, etc.
        return PaymentSlip.objects.none()
