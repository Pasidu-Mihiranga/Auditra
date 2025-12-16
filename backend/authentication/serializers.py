from rest_framework import serializers
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from .models import UserRole, PaymentSlip, ClientFormSubmission, EmployeeFormSubmission, LeaveRequest, SystemLog


class UserRoleSerializer(serializers.ModelSerializer):
    role_display = serializers.CharField(source='get_role_display', read_only=True)
    assigned_by_username = serializers.CharField(source='assigned_by.username', read_only=True)
    salary = serializers.ReadOnlyField()
    
    class Meta:
        model = UserRole
        fields = ('id', 'role', 'role_display', 'salary', 'assigned_by', 'assigned_by_username', 'assigned_at')
        read_only_fields = ('assigned_at',)


class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True, validators=[validate_password])
    password2 = serializers.CharField(write_only=True, required=True)
    
    class Meta:
        model = User
        fields = ('username', 'email', 'password', 'password2', 'first_name', 'last_name')
        extra_kwargs = {
            'first_name': {'required': False},
            'last_name': {'required': False},
            'email': {'required': True}
        }
    
    def validate(self, attrs):
        if attrs['password'] != attrs['password2']:
            raise serializers.ValidationError({"password": "Password fields didn't match."})
        return attrs
    
    def create(self, validated_data):
        validated_data.pop('password2')
        user = User.objects.create_user(**validated_data)
        return user


class UserSerializer(serializers.ModelSerializer):
    role = serializers.SerializerMethodField()
    role_display = serializers.SerializerMethodField()
    salary = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'first_name', 'last_name', 'role', 'role_display', 'salary')
    
    def get_role(self, obj):
        """Get role from user's role"""
        try:
            if hasattr(obj, 'role') and obj.role:
                return obj.role.role
        except Exception:
            pass
        return 'unassigned'
    
    def get_role_display(self, obj):
        """Get role display from user's role"""
        try:
            if hasattr(obj, 'role') and obj.role:
                return obj.role.role_display
        except Exception:
            pass
        return 'Unassigned'
    
    def get_salary(self, obj):
        """Get salary from user's role"""
        try:
            if hasattr(obj, 'role') and obj.role:
                return obj.role.salary
        except Exception:
            pass
        return 0


class UserDetailSerializer(serializers.ModelSerializer):
    role = serializers.SerializerMethodField()
    role_display = serializers.SerializerMethodField()
    salary = serializers.SerializerMethodField()
    role_info = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'first_name', 'last_name', 'role', 'role_display', 'salary', 'role_info', 'date_joined')
    
    def get_role(self, obj):
        """Get role from user's role"""
        try:
            if hasattr(obj, 'role') and obj.role:
                return obj.role.role
        except Exception:
            pass
        return 'unassigned'
    
    def get_role_display(self, obj):
        """Get role display from user's role"""
        try:
            if hasattr(obj, 'role') and obj.role:
                return obj.role.role_display
        except Exception:
            pass
        return 'Unassigned'
    
    def get_salary(self, obj):
        """Get salary from user's role"""
        try:
            if hasattr(obj, 'role') and obj.role:
                return obj.role.salary
        except Exception:
            pass
        return 0
    
    def get_role_info(self, obj):
        """Get role info from user's role"""
        try:
            if hasattr(obj, 'role') and obj.role:
                return UserRoleSerializer(obj.role).data
        except Exception:
            pass
        return None


class LoginSerializer(serializers.Serializer):
    username = serializers.CharField(required=True)
    password = serializers.CharField(required=True, write_only=True)


class AssignRoleSerializer(serializers.Serializer):
    user_id = serializers.IntegerField(required=True)
    role = serializers.ChoiceField(choices=UserRole.ROLE_CHOICES, required=True)
    
    def validate_user_id(self, value):
        if not User.objects.filter(id=value).exists():
            raise serializers.ValidationError("User not found.")
        return value
    
    def validate_role(self, value):
        if value == 'admin':
            raise serializers.ValidationError("Admin role cannot be assigned.")
        return value


class PaymentSlipSerializer(serializers.ModelSerializer):
    user_username = serializers.CharField(source='user.username', read_only=True)
    user_full_name = serializers.SerializerMethodField()
    month_display = serializers.CharField(source='get_month_display', read_only=True)
    generated_by_username = serializers.CharField(source='generated_by.username', read_only=True)
    salary = serializers.SerializerMethodField()
    allowances = serializers.SerializerMethodField()
    epf_contribution = serializers.SerializerMethodField()
    overtime_hours = serializers.SerializerMethodField()
    overtime_pay = serializers.SerializerMethodField()
    net_salary = serializers.SerializerMethodField()
    
    class Meta:
        model = PaymentSlip
        fields = (
            'id', 'user', 'user_username', 'user_full_name', 'month', 'month_display', 
            'year', 'salary', 'allowances', 'epf_contribution', 'overtime_hours', 
            'overtime_hours_uploaded', 'overtime_pay', 'net_salary', 'role', 'role_display', 
            'pay_slip_number', 'employee_number', 'status', 'is_uploaded', 'uploaded_at',
            'generated_by', 'generated_by_username', 'generated_at', 'paid_at'
        )
        read_only_fields = ('generated_at', 'paid_at')
    
    def get_user_full_name(self, obj):
        """Get user's full name"""
        if obj.user.first_name and obj.user.last_name:
            return f"{obj.user.first_name} {obj.user.last_name}"
        return obj.user.username
    
    def get_salary(self, obj):
        """Convert DecimalField to float for JSON serialization"""
        return float(obj.salary)
    
    def get_allowances(self, obj):
        """Convert DecimalField to float for JSON serialization"""
        return float(obj.allowances) if hasattr(obj, 'allowances') else 0.0
    
    def get_epf_contribution(self, obj):
        """Convert DecimalField to float for JSON serialization"""
        return float(obj.epf_contribution) if hasattr(obj, 'epf_contribution') else 0.0
    
    def get_overtime_hours(self, obj):
        """Convert DecimalField to float for JSON serialization"""
        return float(obj.overtime_hours) if hasattr(obj, 'overtime_hours') else 0.0
    
    def get_overtime_pay(self, obj):
        """Convert DecimalField to float for JSON serialization"""
        return float(obj.overtime_pay) if hasattr(obj, 'overtime_pay') else 0.0
    
    def get_net_salary(self, obj):
        """Convert DecimalField to float for JSON serialization"""
        return float(obj.net_salary) if hasattr(obj, 'net_salary') else 0.0


class ClientFormSubmissionSerializer(serializers.ModelSerializer):
    """Serializer for Client Form Submission"""
    
    class Meta:
        model = ClientFormSubmission
        fields = (
            'id', 'first_name', 'last_name', 'email', 'address', 
            'phone', 'nic', 'company_name', 'project_title', 
            'project_description', 'agent_name', 'agent_phone', 
            'agent_email', 'status', 'submitted_at', 'reviewed_at', 
            'notes', 'reviewed_by'
        )
        read_only_fields = ('status', 'submitted_at', 'reviewed_at', 'reviewed_by')


class EmployeeFormSubmissionSerializer(serializers.ModelSerializer):
    """Serializer for Employee Form Submission"""
    
    class Meta:
        model = EmployeeFormSubmission
        fields = (
            'id', 'first_name', 'last_name', 'email', 'address', 
            'phone', 'birthday', 'nic', 'cv', 'status', 
            'submitted_at', 'reviewed_at', 'notes', 'reviewed_by'
        )
        read_only_fields = ('status', 'submitted_at', 'reviewed_at', 'reviewed_by')


class LeaveRequestSerializer(serializers.ModelSerializer):
    """Serializer for Leave Request"""
    employee_name = serializers.SerializerMethodField()
    employee_id = serializers.SerializerMethodField()
    leave_type_display = serializers.CharField(source='get_leave_type_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    days = serializers.ReadOnlyField()
    
    class Meta:
        model = LeaveRequest
        fields = (
            'id', 'user', 'employee_name', 'employee_id', 'leave_type', 
            'leave_type_display', 'start_date', 'end_date', 'days', 
            'reason', 'status', 'status_display', 'submitted_at', 
            'reviewed_at', 'reviewed_by', 'notes'
        )
        read_only_fields = ('user', 'status', 'submitted_at', 'reviewed_at', 'reviewed_by')
    
    def get_employee_name(self, obj):
        """Get employee full name"""
        name_parts = [obj.user.first_name, obj.user.last_name]
        return ' '.join(filter(None, name_parts)) or obj.user.username
    
    def get_employee_id(self, obj):
        """Get employee ID (user ID)"""
        return str(obj.user.id)


class SystemLogSerializer(serializers.ModelSerializer):
    user_username = serializers.CharField(source='user.username', read_only=True)
    user_full_name = serializers.SerializerMethodField()
    action_display = serializers.CharField(source='get_action_display', read_only=True)
    severity_display = serializers.CharField(source='get_severity_display', read_only=True)
    
    class Meta:
        model = SystemLog
        fields = (
            'id', 'user', 'user_username', 'user_full_name',
            'action', 'action_display', 'severity', 'severity_display',
            'message', 'details', 'ip_address', 'user_agent', 'created_at'
        )
        read_only_fields = ('created_at',)
    
    def get_user_full_name(self, obj):
        if obj.user:
            full_name = f"{obj.user.first_name} {obj.user.last_name}".strip()
            return full_name if full_name else obj.user.username
        return 'System'

