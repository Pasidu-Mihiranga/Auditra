from rest_framework import serializers
from django.contrib.auth.models import User
from .models import Project, ProjectDocument


class ProjectDocumentSerializer(serializers.ModelSerializer):
    uploaded_by_username = serializers.CharField(source='uploaded_by.username', read_only=True)
    file_url = serializers.SerializerMethodField()
    file_size = serializers.SerializerMethodField()
    
    class Meta:
        model = ProjectDocument
        fields = (
            'id', 'project', 'file', 'file_url', 'file_size',
            'name', 'description', 'uploaded_by', 'uploaded_by_username',
            'uploaded_at'
        )
        read_only_fields = ('uploaded_by', 'uploaded_at')
    
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
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    documents = ProjectDocumentSerializer(many=True, read_only=True)
    documents_count = serializers.IntegerField(source='documents.count', read_only=True)
    
    class Meta:
        model = Project
        fields = (
            'id', 'title', 'description', 'coordinator', 'coordinator_username',
            'coordinator_name', 'assigned_field_officer', 'assigned_field_officer_username',
            'assigned_field_officer_name', 'status', 'status_display',
            'start_date', 'end_date', 'documents', 'documents_count',
            'created_at', 'updated_at'
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


class ProjectCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating projects"""
    
    class Meta:
        model = Project
        fields = ('title', 'description', 'start_date', 'end_date')
    
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

