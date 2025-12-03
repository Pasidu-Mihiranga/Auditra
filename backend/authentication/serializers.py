from rest_framework import serializers
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from .models import UserRole, PaymentSlip


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
    role = serializers.CharField(source='role.role', read_only=True)
    role_display = serializers.CharField(source='role.role_display', read_only=True)
    salary = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'first_name', 'last_name', 'role', 'role_display', 'salary')
    
    def get_salary(self, obj):
        """Get salary from user's role"""
        if hasattr(obj, 'role') and obj.role:
            return obj.role.salary
        return 0


class UserDetailSerializer(serializers.ModelSerializer):
    role = serializers.CharField(source='role.role', read_only=True)
    role_display = serializers.CharField(source='role.role_display', read_only=True)
    salary = serializers.SerializerMethodField()
    role_info = UserRoleSerializer(source='role', read_only=True)
    
    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'first_name', 'last_name', 'role', 'role_display', 'salary', 'role_info', 'date_joined')
    
    def get_salary(self, obj):
        """Get salary from user's role"""
        if hasattr(obj, 'role') and obj.role:
            return obj.role.salary
        return 0


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
            'overtime_pay', 'net_salary', 'role', 'role_display', 'pay_slip_number', 
            'employee_number', 'status', 'generated_by', 'generated_by_username', 
            'generated_at', 'paid_at'
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

