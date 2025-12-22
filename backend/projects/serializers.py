from rest_framework import serializers
from django.contrib.auth.models import User
from .models import Project, ProjectDocument


class ProjectDocumentSerializer(serializers.ModelSerializer):
    uploaded_by_username = serializers.CharField(source='uploaded_by.username', read_only=True)
    assigned_to_username = serializers.CharField(source='assigned_to.username', read_only=True, allow_null=True)
    assigned_to_name = serializers.SerializerMethodField()
    file_url = serializers.SerializerMethodField()
    file_size = serializers.SerializerMethodField()
    
    class Meta:
        model = ProjectDocument
        fields = (
            'id', 'project', 'file', 'file_url', 'file_size',
            'name', 'description', 'uploaded_by', 'uploaded_by_username',
            'assigned_to', 'assigned_to_username', 'assigned_to_name',
            'uploaded_at'
        )
        read_only_fields = ('uploaded_by', 'uploaded_at')
    
    def get_assigned_to_name(self, obj):
        if obj.assigned_to:
            if obj.assigned_to.first_name or obj.assigned_to.last_name:
                return f"{obj.assigned_to.first_name} {obj.assigned_to.last_name}".strip()
            return obj.assigned_to.username
        return None
    
    def get_file_url(self, obj):
        if obj.file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.file.url)
            return obj.file.url
        return None
    
    def get_file_size(self, obj):
        if obj.file:
            try:
                return obj.file.size
            except:
                return None
        return None


class ProjectSerializer(serializers.ModelSerializer):
    coordinator_username = serializers.CharField(source='coordinator.username', read_only=True)
    coordinator_name = serializers.SerializerMethodField()
    assigned_field_officer_username = serializers.CharField(
        source='assigned_field_officer.username',
        read_only=True,
        allow_null=True
    )
    assigned_field_officer_name = serializers.SerializerMethodField()
    assigned_field_officer_email = serializers.CharField(
        source='assigned_field_officer.email',
        read_only=True,
        allow_null=True
    )
    assigned_client_username = serializers.CharField(
        source='assigned_client.username',
        read_only=True,
        allow_null=True
    )
    assigned_client_name = serializers.SerializerMethodField()
    assigned_client_email = serializers.CharField(
        source='assigned_client.email',
        read_only=True,
        allow_null=True
    )
    assigned_agent_username = serializers.CharField(
        source='assigned_agent.username',
        read_only=True,
        allow_null=True
    )
    assigned_agent_name = serializers.SerializerMethodField()
    assigned_agent_email = serializers.CharField(
        source='assigned_agent.email',
        read_only=True,
        allow_null=True
    )
    assigned_accessor_username = serializers.CharField(
        source='assigned_accessor.username',
        read_only=True,
        allow_null=True
    )
    assigned_accessor_name = serializers.SerializerMethodField()
    assigned_accessor_email = serializers.CharField(
        source='assigned_accessor.email',
        read_only=True,
        allow_null=True
    )
    assigned_senior_valuer_username = serializers.CharField(
        source='assigned_senior_valuer.username',
        read_only=True,
        allow_null=True
    )
    assigned_senior_valuer_name = serializers.SerializerMethodField()
    assigned_senior_valuer_email = serializers.CharField(
        source='assigned_senior_valuer.email',
        read_only=True,
        allow_null=True
    )
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    md_gm_approval_status_display = serializers.SerializerMethodField()
    documents = ProjectDocumentSerializer(many=True, read_only=True)
    documents_count = serializers.IntegerField(source='documents.count', read_only=True)
    valuations = serializers.SerializerMethodField()
    valuations_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Project
        fields = (
            'id', 'title', 'description', 'coordinator', 'coordinator_username',
            'coordinator_name', 'assigned_field_officer', 'assigned_field_officer_username',
            'assigned_field_officer_name', 'assigned_field_officer_email',
            'assigned_client', 'assigned_client_username', 'assigned_client_name',
            'assigned_client_email', 'assigned_agent', 'assigned_agent_username',
            'assigned_agent_name', 'assigned_agent_email', 'assigned_accessor',
            'assigned_accessor_username', 'assigned_accessor_name', 'assigned_accessor_email',
            'assigned_senior_valuer', 'assigned_senior_valuer_username', 'assigned_senior_valuer_name',
            'assigned_senior_valuer_email', 'has_agent', 'client_info', 'agent_info',
            'status', 'status_display', 'workflow_stage', 'priority', 'start_date', 'end_date',
            'md_gm_approval_status', 'md_gm_approval_status_display', 'md_gm_rejection_reason',
            'md_gm_approved_at', 'md_gm_rejected_at',
            'documents', 'documents_count', 'valuations', 'valuations_count', 'created_at', 'updated_at'
        )
        read_only_fields = ('coordinator', 'created_at', 'updated_at')
    
    def get_coordinator_name(self, obj):
        if obj.coordinator.first_name or obj.coordinator.last_name:
            return f"{obj.coordinator.first_name} {obj.coordinator.last_name}".strip()
        return obj.coordinator.username
    
    def get_assigned_field_officer_name(self, obj):
        if obj.assigned_field_officer:
            if obj.assigned_field_officer.first_name or obj.assigned_field_officer.last_name:
                return f"{obj.assigned_field_officer.first_name} {obj.assigned_field_officer.last_name}".strip()
            return obj.assigned_field_officer.username
        return None
    
    def get_assigned_client_name(self, obj):
        if obj.assigned_client:
            # Format as "Client + first_name" if first_name exists, otherwise just "Client"
            if obj.assigned_client.first_name:
                return f"Client {obj.assigned_client.first_name}".strip()
            return "Client"
        return None
    
    def get_assigned_agent_name(self, obj):
        if obj.assigned_agent:
            if obj.assigned_agent.first_name or obj.assigned_agent.last_name:
                return f"{obj.assigned_agent.first_name} {obj.assigned_agent.last_name}".strip()
            return obj.assigned_agent.username
        return None
    
    def get_assigned_accessor_name(self, obj):
        if obj.assigned_accessor:
            if obj.assigned_accessor.first_name or obj.assigned_accessor.last_name:
                return f"{obj.assigned_accessor.first_name} {obj.assigned_accessor.last_name}".strip()
            return obj.assigned_accessor.username
        return None
    
    def get_assigned_senior_valuer_name(self, obj):
        if obj.assigned_senior_valuer:
            if obj.assigned_senior_valuer.first_name or obj.assigned_senior_valuer.last_name:
                return f"{obj.assigned_senior_valuer.first_name} {obj.assigned_senior_valuer.last_name}".strip()
            return obj.assigned_senior_valuer.username
        return None
    
    def get_md_gm_approval_status_display(self, obj):
        status_map = {
            'pending': 'Pending',
            'approved': 'Approved',
            'rejected': 'Rejected',
        }
        return status_map.get(obj.md_gm_approval_status, 'Pending')
    
    def get_valuations(self, obj):
        """Get valuations for this project"""
        # Import here to avoid circular import
        from valuations.serializers import ValuationSerializer
        request = self.context.get('request')
        
        # Filter valuations based on user role
        valuations = obj.valuations.all().select_related('field_officer').prefetch_related('photos')
        
        # Senior valuer should only see reviewed valuations (sent by assessor)
        if request and hasattr(request.user, 'role') and request.user.role.role == 'senior_valuer':
            valuations = valuations.filter(status='reviewed')
        
        # MD/GM should see all valuations for projects they receive
        # (Projects are already filtered to only show those with all approved valuations)
        # No need to filter valuations here - show all reports
        
        return ValuationSerializer(valuations, many=True, context=self.context).data
    
    def get_valuations_count(self, obj):
        """Get count of valuations for this project"""
        request = self.context.get('request')
        
        # Senior valuer should only count reviewed valuations
        if request and hasattr(request.user, 'role') and request.user.role.role == 'senior_valuer':
            return obj.valuations.filter(status='reviewed').count()
        
        # MD/GM should see all valuations count for projects they receive
        return obj.valuations.count()


class ProjectCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating projects"""
    client_info = serializers.JSONField(required=False, allow_null=True)
    agent_info = serializers.JSONField(required=False, allow_null=True)
    
    class Meta:
        model = Project
        fields = ('title', 'description', 'start_date', 'end_date', 'has_agent', 'priority', 'client_info', 'agent_info')
        extra_kwargs = {
            'title': {'required': True},
            'description': {'required': False, 'allow_blank': True},
            'start_date': {'required': False, 'allow_null': True},
            'end_date': {'required': False, 'allow_null': True},
            'has_agent': {'required': False, 'default': False},
            'priority': {'required': False, 'default': 'medium'},
        }
    
    def to_internal_value(self, data):
        # Keep client_info and agent_info to store them in the project
        data = data.copy() if hasattr(data, 'copy') else dict(data)
        
        # Check if agent_info was provided to determine has_agent
        if 'agent_info' in data and data.get('agent_info'):
            data['has_agent'] = True
        elif 'has_agent' not in data:
            data['has_agent'] = False
            
        return super().to_internal_value(data)
    
    def create(self, validated_data):
        validated_data['coordinator'] = self.context['request'].user
        return super().create(validated_data)


class AssignFieldOfficerSerializer(serializers.Serializer):
    """Serializer for assigning field officer to project"""
    field_officer_id = serializers.IntegerField(required=True)
    
    def validate_field_officer_id(self, value):
        try:
            user = User.objects.get(id=value)
            if not hasattr(user, 'role') or user.role.role != 'field_officer':
                raise serializers.ValidationError("User must be a field officer.")
            return value
        except User.DoesNotExist:
            raise serializers.ValidationError("User not found.")


class AssignClientSerializer(serializers.Serializer):
    """Serializer for assigning client to project"""
    client_id = serializers.IntegerField(required=True)
    
    def validate_client_id(self, value):
        try:
            user = User.objects.get(id=value)
            if not hasattr(user, 'role') or user.role.role != 'client':
                raise serializers.ValidationError("User must be a client.")
            return value
        except User.DoesNotExist:
            raise serializers.ValidationError("User not found.")


class AssignAgentSerializer(serializers.Serializer):
    """Serializer for assigning agent to project"""
    agent_id = serializers.IntegerField(required=True)
    
    def validate_agent_id(self, value):
        try:
            user = User.objects.get(id=value)
            if not hasattr(user, 'role') or user.role.role != 'agent':
                raise serializers.ValidationError("User must be an agent.")
            return value
        except User.DoesNotExist:
            raise serializers.ValidationError("User not found.")


class AssignAccessorSerializer(serializers.Serializer):
    """Serializer for assigning accessor to project"""
    accessor_id = serializers.IntegerField(required=True)
    
    def validate_accessor_id(self, value):
        try:
            user = User.objects.get(id=value)
            if not hasattr(user, 'role') or user.role.role != 'accessor':
                raise serializers.ValidationError("User must be an accessor.")
            return value
        except User.DoesNotExist:
            raise serializers.ValidationError("User not found.")


class AssignSeniorValuerSerializer(serializers.Serializer):
    """Serializer for assigning senior valuer to project"""
    senior_valuer_id = serializers.IntegerField(required=True)
    
    def validate_senior_valuer_id(self, value):
        try:
            user = User.objects.get(id=value)
            if not hasattr(user, 'role') or user.role.role != 'senior_valuer':
                raise serializers.ValidationError("User must be a senior valuer.")
            return value
        except User.DoesNotExist:
            raise serializers.ValidationError("User not found.")

