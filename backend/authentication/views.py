from rest_framework import status, generics
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny, IsAuthenticated, IsAdminUser
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.utils import timezone
from decimal import Decimal, InvalidOperation
from .models import UserRole, PaymentSlip, ClientFormSubmission, EmployeeFormSubmission, LeaveRequest, UserProfile, SystemLog
from .serializers import (
    UserRegistrationSerializer, 
    UserSerializer, 
    UserDetailSerializer,
    LoginSerializer,
    AssignRoleSerializer,
    UserRoleSerializer,
    PaymentSlipSerializer,
    ClientFormSubmissionSerializer,
    EmployeeFormSubmissionSerializer,
    LeaveRequestSerializer,
    SystemLogSerializer
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


class EnableBiometricView(APIView):
    """Enable biometric authentication for the current user"""
    permission_classes = (IsAuthenticated,)
    
    def post(self, request):
        profile, created = UserProfile.objects.get_or_create(user=request.user)
        profile.biometric_enabled = True
        profile.save()
        
        return Response({
            'message': 'Biometric authentication enabled successfully',
            'biometric_enabled': True
        }, status=status.HTTP_200_OK)


class DisableBiometricView(APIView):
    """Disable biometric authentication for the current user"""
    permission_classes = (IsAuthenticated,)
    
    def post(self, request):
        profile, created = UserProfile.objects.get_or_create(user=request.user)
        profile.biometric_enabled = False
        profile.biometric_required = False
        profile.save()
        
        return Response({
            'message': 'Biometric authentication disabled successfully',
            'biometric_enabled': False
        }, status=status.HTTP_200_OK)


class BiometricLoginView(APIView):
    """Login using biometric authentication (username only)"""
    permission_classes = (AllowAny,)
    
    def post(self, request):
        username = request.data.get('username')
        
        if not username:
            return Response({
                'error': 'Username is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            user = User.objects.get(username=username)
        except User.DoesNotExist:
            return Response({
                'error': 'User not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Check if biometric is enabled for this user
        try:
            profile = user.profile
            if not profile.biometric_enabled:
                return Response({
                    'error': 'Biometric authentication is not enabled for this user'
                }, status=status.HTTP_403_FORBIDDEN)
        except UserProfile.DoesNotExist:
            return Response({
                'error': 'Biometric authentication is not enabled for this user'
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Generate JWT tokens
        refresh = RefreshToken.for_user(user)
        user_data = UserSerializer(user).data
        
        return Response({
            'user': user_data,
            'refresh': str(refresh),
            'access': str(refresh.access_token),
            'message': 'Biometric login successful'
        }, status=status.HTTP_200_OK)


class BiometricStatusView(APIView):
    """Get biometric authentication status for the current user"""
    permission_classes = (IsAuthenticated,)
    
    def get(self, request):
        profile, created = UserProfile.objects.get_or_create(user=request.user)
        
        return Response({
            'biometric_enabled': profile.biometric_enabled,
            'biometric_required': profile.biometric_required
        }, status=status.HTTP_200_OK)


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


class DeleteUserView(APIView):
    """Admin endpoint to delete a user from the database"""
    permission_classes = (IsAuthenticated,)
    
    def delete(self, request, user_id):
        # Check if user is admin
        if not hasattr(request.user, 'role') or request.user.role.role != 'admin':
            return Response({
                'error': 'Only admins can delete users'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            user_to_delete = User.objects.get(id=user_id)
            
            # Prevent deleting the admin user
            if hasattr(user_to_delete, 'role') and user_to_delete.role.role == 'admin':
                return Response({
                    'error': 'Cannot delete the admin user'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Prevent deleting yourself
            if user_to_delete.id == request.user.id:
                return Response({
                    'error': 'Cannot delete your own account'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Get user info before deletion
            user_name = user_to_delete.get_full_name() or user_to_delete.username
            user_role = user_to_delete.role.role if hasattr(user_to_delete, 'role') else 'unknown'
            
            # Delete the user (this will cascade delete related records like UserRole, PaymentSlips, etc.)
            user_to_delete.delete()
            
            return Response({
                'message': f'User {user_name} ({user_role}) has been deleted successfully from the database'
            }, status=status.HTTP_200_OK)
        except User.DoesNotExist:
            return Response({
                'error': 'User not found'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return Response({
                'error': f'Error deleting user: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


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
        try:
            # Check if user has a role
            if hasattr(request.user, 'role') and request.user.role:
                serializer = UserRoleSerializer(request.user.role)
                return Response(serializer.data, status=status.HTTP_200_OK)
            else:
                # Create a default role if it doesn't exist
                user_role, created = UserRole.objects.get_or_create(
                    user=request.user,
                    defaults={'role': 'unassigned'}
                )
                serializer = UserRoleSerializer(user_role)
                return Response(serializer.data, status=status.HTTP_200_OK)
        except Exception as e:
            # If there's any error, create a default role
            try:
                user_role, created = UserRole.objects.get_or_create(
                    user=request.user,
                    defaults={'role': 'unassigned'}
                )
                serializer = UserRoleSerializer(user_role)
                return Response(serializer.data, status=status.HTTP_200_OK)
            except Exception:
                return Response({
                    'error': 'Role not found',
                    'role': 'unassigned',
                    'role_display': 'Unassigned',
                    'salary': 0
                }, status=status.HTTP_200_OK)


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


class UploadPaymentSlipsView(APIView):
    """Admin endpoint to upload/publish payment slips for employees to view"""
    permission_classes = (IsAuthenticated,)
    
    def post(self, request):
        # Check if user is admin
        if not hasattr(request.user, 'role') or request.user.role.role != 'admin':
            return Response({
                'error': 'Only admins can upload payment slips'
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
        
        try:
            # Get all payment slips for the specified month/year
            payment_slips = PaymentSlip.objects.filter(month=month, year=year)
            
            if not payment_slips.exists():
                return Response({
                    'error': f'No payment slips found for {month}/{year}. Please create payment slips first.'
                }, status=status.HTTP_404_NOT_FOUND)
            
            # Update all payment slips to be uploaded/published
            updated_count = payment_slips.update(
                is_uploaded=True,
                uploaded_at=timezone.now()
            )
            
            return Response({
                'message': f'Payment slips uploaded successfully for {updated_count} employees',
                'month': month,
                'year': year,
                'uploaded_count': updated_count
            }, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({
                'error': f'Error uploading payment slips: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class UploadPaymentSlipsView(APIView):
    """Admin endpoint to upload/publish payment slips for employees to view"""
    permission_classes = (IsAuthenticated,)
    
    def post(self, request):
        # Check if user is admin
        if not hasattr(request.user, 'role') or request.user.role.role != 'admin':
            return Response({
                'error': 'Only admins can upload payment slips'
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
        
        try:
            # Update all payment slips for the specified month/year to be uploaded/published
            updated_count = PaymentSlip.objects.filter(
                month=month,
                year=year,
                is_uploaded=False
            ).update(
                is_uploaded=True,
                uploaded_at=timezone.now()
            )
            
            if updated_count == 0:
                return Response({
                    'message': f'No payment slips found for {month}/{year} to upload, or they are already uploaded.',
                    'month': month,
                    'year': year,
                    'uploaded_count': 0
                }, status=status.HTTP_200_OK)
            
            return Response({
                'message': f'Payment slips uploaded successfully for {updated_count} employees',
                'month': month,
                'year': year,
                'uploaded_count': updated_count
            }, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({
                'error': f'Error uploading payment slips: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class MyPaymentSlipsView(generics.ListAPIView):
    """Get current user's payment slips."""
    permission_classes = (IsAuthenticated,)
    serializer_class = PaymentSlipSerializer
    
    def get_queryset(self):
        try:
            # Check if user is admin
            is_admin = False
            try:
                if hasattr(self.request.user, 'role') and self.request.user.role:
                    is_admin = self.request.user.role.role == 'admin'
            except (AttributeError, Exception):
                # If user doesn't have a role, treat as non-admin
                is_admin = False
            
            if is_admin:
                # Admin can see all their payment slips (uploaded or not)
                return PaymentSlip.objects.filter(user=self.request.user).order_by('-year', '-month')
            else:
                # Employees can only see their own payment slips that are uploaded/published
                return PaymentSlip.objects.filter(
                    user=self.request.user,
                    is_uploaded=True
                ).order_by('-year', '-month')
        except Exception as e:
            # Return empty queryset on any error
            return PaymentSlip.objects.none()
    
    def list(self, request, *args, **kwargs):
        """Override list to handle errors gracefully"""
        try:
            return super().list(request, *args, **kwargs)
        except Exception as e:
            return Response({
                'error': f'Error retrieving payment slips: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


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


class PaymentSlipDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Get, update, and delete payment slip details (Admin only)"""
    permission_classes = (IsAuthenticated,)
    serializer_class = PaymentSlipSerializer
    
    def get_queryset(self):
        # Only admins can access payment slips
        if hasattr(self.request.user, 'role') and self.request.user.role.role == 'admin':
            return PaymentSlip.objects.all()
        
        # Employees cannot see payment slips - return empty queryset
        return PaymentSlip.objects.none()
    
    def update(self, request, *args, **kwargs):
        """Update payment slip and recalculate net salary (Admin only)"""
        # Check if user is admin
        if not hasattr(request.user, 'role') or request.user.role.role != 'admin':
            return Response({
                'error': 'Only admins can update payment slips'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            instance = self.get_object()
            
            # Get updated values from request
            salary = request.data.get('salary', None)
            allowances = request.data.get('allowances', None)
            epf_contribution = request.data.get('epf_contribution', None)
            overtime_pay = request.data.get('overtime_pay', None)
            
            # Validate and update fields if provided
            if salary is not None:
                try:
                    salary_decimal = Decimal(str(salary))
                    if salary_decimal < 0:
                        return Response({
                            'error': 'Salary cannot be negative'
                        }, status=status.HTTP_400_BAD_REQUEST)
                    instance.salary = salary_decimal
                except (ValueError, InvalidOperation):
                    return Response({
                        'error': 'Invalid salary value'
                    }, status=status.HTTP_400_BAD_REQUEST)
            
            if allowances is not None:
                try:
                    allowances_decimal = Decimal(str(allowances))
                    if allowances_decimal < 0:
                        return Response({
                            'error': 'Allowances cannot be negative'
                        }, status=status.HTTP_400_BAD_REQUEST)
                    instance.allowances = allowances_decimal
                except (ValueError, InvalidOperation):
                    return Response({
                        'error': 'Invalid allowances value'
                    }, status=status.HTTP_400_BAD_REQUEST)
            
            if epf_contribution is not None:
                try:
                    epf_decimal = Decimal(str(epf_contribution))
                    if epf_decimal < 0:
                        return Response({
                            'error': 'EPF contribution cannot be negative'
                        }, status=status.HTTP_400_BAD_REQUEST)
                    instance.epf_contribution = epf_decimal
                except (ValueError, InvalidOperation):
                    return Response({
                        'error': 'Invalid EPF contribution value'
                    }, status=status.HTTP_400_BAD_REQUEST)
            
            if overtime_pay is not None:
                try:
                    overtime_decimal = Decimal(str(overtime_pay))
                    if overtime_decimal < 0:
                        return Response({
                            'error': 'Overtime pay cannot be negative'
                        }, status=status.HTTP_400_BAD_REQUEST)
                    instance.overtime_pay = overtime_decimal
                except (ValueError, InvalidOperation):
                    return Response({
                        'error': 'Invalid overtime pay value'
                    }, status=status.HTTP_400_BAD_REQUEST)
            
            # Recalculate net salary: Basic Salary - EPF + Allowances + Overtime Pay
            instance.net_salary = instance.salary - instance.epf_contribution + instance.allowances + instance.overtime_pay
            
            # Save the instance
            instance.save()
            
            # Serialize and return
            serializer = self.get_serializer(instance)
            return Response(serializer.data, status=status.HTTP_200_OK)
        except PaymentSlip.DoesNotExist:
            return Response({
                'error': 'Payment slip not found'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return Response({
                'error': f'Error updating payment slip: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def destroy(self, request, *args, **kwargs):
        """Delete payment slip (Admin only)"""
        try:
            instance = self.get_object()
            employee_name = instance.user.get_full_name() or instance.user.username
            employee_number = instance.employee_number or str(instance.user.id)
            instance.delete()
            return Response({
                'message': f'Payment slip for {employee_name} (Employee #{employee_number}) has been deleted successfully'
            }, status=status.HTTP_200_OK)
        except PaymentSlip.DoesNotExist:
            return Response({
                'error': 'Payment slip not found'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return Response({
                'error': f'Error deleting payment slip: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class UploadOvertimeHoursView(APIView):
    """Upload overtime hours for a specific payment slip"""
    permission_classes = (IsAuthenticated,)
    
    def post(self, request, slip_id):
        # Check if user is admin
        if not hasattr(request.user, 'role') or request.user.role.role != 'admin':
            return Response({
                'error': 'Only admins can upload overtime hours'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            slip = PaymentSlip.objects.get(id=slip_id)
        except PaymentSlip.DoesNotExist:
            return Response({
                'error': 'Payment slip not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        overtime_hours = request.data.get('overtime_hours', None)
        if overtime_hours is None:
            return Response({
                'error': 'overtime_hours is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            overtime_hours_decimal = Decimal(str(overtime_hours))
            if overtime_hours_decimal < 0:
                return Response({
                    'error': 'Overtime hours cannot be negative'
                }, status=status.HTTP_400_BAD_REQUEST)
        except (ValueError, TypeError):
            return Response({
                'error': 'Invalid overtime_hours value'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Update overtime hours and mark as uploaded
        slip.overtime_hours = overtime_hours_decimal
        slip.overtime_hours_uploaded = True
        
        # Recalculate overtime pay
        basic_salary = float(slip.salary)
        slip.overtime_pay = Decimal(str(PaymentSlip.calculate_overtime_pay(float(overtime_hours_decimal), basic_salary)))
        
        # Recalculate net salary: Basic Salary - EPF + Allowances + Overtime Pay
        slip.net_salary = slip.salary - slip.epf_contribution + slip.allowances + slip.overtime_pay
        
        slip.save()
        
        serializer = PaymentSlipSerializer(slip)
        return Response({
            'success': True,
            'message': 'Overtime hours uploaded successfully',
            'data': serializer.data
        }, status=status.HTTP_200_OK)


class UploadAllOvertimeHoursView(APIView):
    """Upload overtime hours for all payment slips from a file or JSON data"""
    permission_classes = (IsAuthenticated,)
    
    def post(self, request):
        # Check if user is admin
        if not hasattr(request.user, 'role') or request.user.role.role != 'admin':
            return Response({
                'error': 'Only admins can upload overtime hours'
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Get month and year from request (optional, defaults to current month)
        month = request.data.get('month', None)
        year = request.data.get('year', None)
        
        if month is None or year is None:
            now = timezone.now()
            month = month or now.month
            year = year or now.year
        
        # Get overtime hours data (list of {user_id: overtime_hours} or {slip_id: overtime_hours})
        overtime_data = request.data.get('overtime_data', None)
        
        if not overtime_data:
            return Response({
                'error': 'overtime_data is required. Format: [{"user_id": 1, "overtime_hours": 10.5}, ...] or [{"slip_id": 1, "overtime_hours": 10.5}, ...]'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        updated_count = 0
        errors = []
        
        for item in overtime_data:
            try:
                slip_id = item.get('slip_id', None)
                user_id = item.get('user_id', None)
                overtime_hours = item.get('overtime_hours', None)
                
                if overtime_hours is None:
                    errors.append(f'Missing overtime_hours for item: {item}')
                    continue
                
                overtime_hours_decimal = Decimal(str(overtime_hours))
                if overtime_hours_decimal < 0:
                    errors.append(f'Invalid overtime_hours for item: {item}')
                    continue
                
                # Find payment slip
                if slip_id:
                    try:
                        slip = PaymentSlip.objects.get(id=slip_id)
                    except PaymentSlip.DoesNotExist:
                        errors.append(f'Payment slip {slip_id} not found')
                        continue
                elif user_id:
                    try:
                        slip = PaymentSlip.objects.get(user_id=user_id, month=month, year=year)
                    except PaymentSlip.DoesNotExist:
                        errors.append(f'Payment slip for user {user_id} in {month}/{year} not found')
                        continue
                else:
                    errors.append(f'Missing slip_id or user_id for item: {item}')
                    continue
                
                # Update overtime hours and mark as uploaded
                slip.overtime_hours = overtime_hours_decimal
                slip.overtime_hours_uploaded = True
                
                # Recalculate overtime pay
                basic_salary = float(slip.salary)
                slip.overtime_pay = Decimal(str(PaymentSlip.calculate_overtime_pay(float(overtime_hours_decimal), basic_salary)))
                
                # Recalculate net salary
                slip.net_salary = slip.salary - slip.epf_contribution + slip.allowances + slip.overtime_pay
                
                slip.save()
                updated_count += 1
                
            except Exception as e:
                errors.append(f'Error processing item {item}: {str(e)}')
        
        return Response({
            'success': True,
            'message': f'Updated {updated_count} payment slip(s)',
            'updated_count': updated_count,
            'errors': errors if errors else None
        }, status=status.HTTP_200_OK)


class ClientRegistrationView(APIView):
    """API endpoint for client registration form submission"""
    permission_classes = (AllowAny,)
    
    def post(self, request):
        try:
            serializer = ClientFormSubmissionSerializer(data=request.data)
            if serializer.is_valid():
                submission = serializer.save()
                return Response({
                    'success': True,
                    'message': 'Client registration submitted successfully. An administrator will review your application.',
                    'id': submission.id
                }, status=status.HTTP_201_CREATED)
            else:
                return Response({
                    'success': False,
                    'error': 'Validation failed',
                    'errors': serializer.errors
                }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            return Response({
                'success': False,
                'error': f'Error processing submission: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class EmployeeRegistrationView(APIView):
    """API endpoint for employee registration form submission"""
    permission_classes = (AllowAny,)
    
    def post(self, request):
        try:
            serializer = EmployeeFormSubmissionSerializer(data=request.data)
            if serializer.is_valid():
                submission = serializer.save()
                return Response({
                    'success': True,
                    'message': 'Employee registration submitted successfully. An administrator will review your application.',
                    'id': submission.id
                }, status=status.HTTP_201_CREATED)
            else:
                return Response({
                    'success': False,
                    'error': 'Validation failed',
                    'errors': serializer.errors
                }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            return Response({
                'success': False,
                'error': f'Error processing submission: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CreateLeaveRequestView(APIView):
    """API endpoint for employees to create leave requests"""
    permission_classes = (IsAuthenticated,)
    
    def post(self, request):
        try:
            data = request.data.copy()
            data['user'] = request.user.id
            serializer = LeaveRequestSerializer(data=data)
            if serializer.is_valid():
                leave_request = serializer.save(user=request.user)
                return Response({
                    'success': True,
                    'message': 'Leave request submitted successfully',
                    'data': LeaveRequestSerializer(leave_request).data
                }, status=status.HTTP_201_CREATED)
            else:
                return Response({
                    'success': False,
                    'error': 'Validation failed',
                    'errors': serializer.errors
                }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            return Response({
                'success': False,
                'error': f'Error creating leave request: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AllLeaveRequestsView(generics.ListAPIView):
    """API endpoint for admin to view all leave requests"""
    permission_classes = (IsAuthenticated,)
    serializer_class = LeaveRequestSerializer
    
    def get_queryset(self):
        # Check if user is admin
        try:
            user_role = UserRole.objects.get(user=self.request.user)
            if user_role.role != 'admin':
                return LeaveRequest.objects.none()
        except UserRole.DoesNotExist:
            return LeaveRequest.objects.none()
        
        return LeaveRequest.objects.all()
    
    def list(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        serializer = self.get_serializer(queryset, many=True)
        return Response({
            'success': True,
            'data': serializer.data
        })


class MyLeaveRequestsView(generics.ListAPIView):
    """API endpoint for employees to view their own leave requests"""
    permission_classes = (IsAuthenticated,)
    serializer_class = LeaveRequestSerializer
    
    def get_queryset(self):
        # Filter by current user
        return LeaveRequest.objects.filter(user=self.request.user).order_by('-submitted_at')
    
    def list(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        serializer = self.get_serializer(queryset, many=True)
        return Response({
            'success': True,
            'data': serializer.data
        })


class MyLeaveStatisticsView(APIView):
    """API endpoint for employees to get their leave statistics"""
    permission_classes = (IsAuthenticated,)
    
    def get(self, request):
        try:
            # Total leaves allocated per year
            TOTAL_LEAVES = 45
            
            # Get all approved (accepted) leave requests for current user in current year
            current_year = timezone.now().year
            approved_leaves = LeaveRequest.objects.filter(
                user=request.user,
                status='approved',  # Only count approved/accepted leave requests
                start_date__year=current_year
            )
            
            # Calculate total leave days taken (sum of days from all approved leave requests)
            # Each leave request's days property calculates: (end_date - start_date).days + 1
            leave_taken = sum(leave.days for leave in approved_leaves)
            
            # Calculate remaining leaves: Total leaves (45) - Leave taken (accepted requests)
            remaining_leaves = max(0, TOTAL_LEAVES - leave_taken)
            
            return Response({
                'success': True,
                'data': {
                    'total_leaves': TOTAL_LEAVES,
                    'leave_taken': leave_taken,  # Current number of leaves (accepted)
                    'remaining_leaves': remaining_leaves,  # Total - Accepted
                    'year': current_year,
                }
            }, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({
                'success': False,
                'error': f'Error calculating leave statistics: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class MonthlyLeaveSummaryView(APIView):
    """API endpoint for admin to get monthly leave summary for all employees"""
    permission_classes = (IsAuthenticated,)
    
    def get(self, request):
        try:
            # Check if user is admin
            user_role = UserRole.objects.get(user=request.user)
            if user_role.role != 'admin':
                return Response({
                    'success': False,
                    'error': 'Only admin can view leave summary'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Get month and year from query parameters (default to current month/year)
            month = int(request.query_params.get('month', timezone.now().month))
            year = int(request.query_params.get('year', timezone.now().year))
            
            # Get all approved leave requests for the specified month and year
            approved_leaves = LeaveRequest.objects.filter(
                status='approved',
                start_date__year=year,
                start_date__month=month
            ).select_related('user')
            
            # Group by user and calculate total days per employee
            employee_leave_summary = {}
            for leave in approved_leaves:
                user_id = leave.user.id
                employee_name = f"{leave.user.first_name} {leave.user.last_name}".strip()
                if not employee_name:
                    employee_name = leave.user.username
                
                if user_id not in employee_leave_summary:
                    employee_leave_summary[user_id] = {
                        'employee_id': str(user_id),
                        'employee_name': employee_name,
                        'leave_taken': 0,
                    }
                
                employee_leave_summary[user_id]['leave_taken'] += leave.days
            
            # Convert to list and sort by employee name
            summary_list = list(employee_leave_summary.values())
            summary_list.sort(key=lambda x: x['employee_name'])
            
            return Response({
                'success': True,
                'data': summary_list,
                'month': month,
                'year': year,
            }, status=status.HTTP_200_OK)
        except UserRole.DoesNotExist:
            return Response({
                'success': False,
                'error': 'User role not found'
            }, status=status.HTTP_403_FORBIDDEN)
        except Exception as e:
            return Response({
                'success': False,
                'error': f'Error getting leave summary: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class UpdateLeaveRequestView(APIView):
    """API endpoint for admin to approve/reject leave requests"""
    permission_classes = (IsAuthenticated,)
    
    def patch(self, request, pk):
        try:
            # Check if user is admin
            user_role = UserRole.objects.get(user=request.user)
            if user_role.role != 'admin':
                return Response({
                    'success': False,
                    'error': 'Only admin can update leave requests'
                }, status=status.HTTP_403_FORBIDDEN)
            
            leave_request = LeaveRequest.objects.get(pk=pk)
            new_status = request.data.get('status')
            
            if new_status not in ['approved', 'rejected']:
                return Response({
                    'success': False,
                    'error': 'Invalid status. Must be "approved" or "rejected"'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            leave_request.status = new_status
            leave_request.reviewed_by = request.user
            leave_request.reviewed_at = timezone.now()
            if request.data.get('notes'):
                leave_request.notes = request.data.get('notes')
            leave_request.save()
            
            return Response({
                'success': True,
                'message': f'Leave request {new_status} successfully',
                'data': LeaveRequestSerializer(leave_request).data
            }, status=status.HTTP_200_OK)
        except UserRole.DoesNotExist:
            return Response({
                'success': False,
                'error': 'User role not found'
            }, status=status.HTTP_403_FORBIDDEN)
        except LeaveRequest.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Leave request not found'
        }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return Response({
                'success': False,
                'error': f'Error updating leave request: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class SystemLogsView(generics.ListAPIView):
    """API endpoint for admin to view all system logs"""
    permission_classes = [IsAuthenticated]
    serializer_class = SystemLogSerializer
    
    def get_queryset(self):
        # Check if user is admin
        try:
            user_role = UserRole.objects.get(user=self.request.user)
            if user_role.role != 'admin':
                return SystemLog.objects.none()
        except UserRole.DoesNotExist:
            return SystemLog.objects.none()
        
        queryset = SystemLog.objects.all().select_related('user')
        
        # Optional filters
        action = self.request.query_params.get('action', None)
        severity = self.request.query_params.get('severity', None)
        user_id = self.request.query_params.get('user_id', None)
        start_date = self.request.query_params.get('start_date', None)
        end_date = self.request.query_params.get('end_date', None)
        
        if action:
            queryset = queryset.filter(action=action)
        if severity:
            queryset = queryset.filter(severity=severity)
        if user_id:
            queryset = queryset.filter(user_id=user_id)
        if start_date:
            queryset = queryset.filter(created_at__gte=start_date)
        if end_date:
            queryset = queryset.filter(created_at__lte=end_date)
        
        return queryset

