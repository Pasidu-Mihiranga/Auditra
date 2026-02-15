from rest_framework import serializers
from .models import Valuation, ValuationPhoto


class ValuationPhotoSerializer(serializers.ModelSerializer):
    """Serializer for valuation photos"""
    
    photo_url = serializers.SerializerMethodField()
    
    class Meta:
        model = ValuationPhoto
        fields = ['id', 'photo', 'photo_url', 'caption', 'uploaded_at']
        read_only_fields = ['uploaded_at']
    
    def get_photo_url(self, obj):
        if obj.photo:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.photo.url)
            return obj.photo.url
        return None


class ValuationSerializer(serializers.ModelSerializer):
    """Serializer for valuations"""
    
    photos = ValuationPhotoSerializer(many=True, read_only=True)
    field_officer_username = serializers.CharField(source='field_officer.username', read_only=True)
    field_officer_name = serializers.SerializerMethodField()
    project_title = serializers.CharField(source='project.title', read_only=True)
    category_display = serializers.CharField(source='get_category_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    accessor_username = serializers.CharField(source='project.assigned_accessor.username', read_only=True, allow_null=True)
    accessor_name = serializers.SerializerMethodField()
    can_be_edited = serializers.SerializerMethodField()
    final_report_url = serializers.SerializerMethodField()
    
    class Meta:
        model = Valuation
        fields = [
            'id', 'project', 'project_title', 'field_officer', 'field_officer_username',
            'field_officer_name', 'accessor_username', 'accessor_name',
            'category', 'category_display', 'status', 'status_display',
            'description', 'estimated_value', 'notes',
            # Land fields
            'land_area', 'land_type', 'land_location', 'land_latitude', 'land_longitude',
            # Building fields
            'building_area', 'building_type', 'building_location', 'building_latitude',
            'building_longitude', 'number_of_floors', 'year_built',
            # Vehicle fields
            'vehicle_make', 'vehicle_model', 'vehicle_year', 'vehicle_registration_number',
            'vehicle_mileage', 'vehicle_condition',
            # Other fields
            'other_type', 'other_specifications',
            # Accessor review fields
            'rejection_reason',
            # Senior valuer fields
            'senior_valuer_comments', 'final_report', 'final_report_url',
            # Timestamps
            'created_at', 'updated_at', 'submitted_at', 'photos', 'can_be_edited'
        ]
        read_only_fields = ['field_officer', 'created_at', 'updated_at', 'submitted_at']
    
    def get_field_officer_name(self, obj):
        if obj.field_officer.first_name or obj.field_officer.last_name:
            return f"{obj.field_officer.first_name or ''} {obj.field_officer.last_name or ''}".strip()
        return obj.field_officer.username

    def get_accessor_name(self, obj):
        if obj.project.assigned_accessor:
            accessor = obj.project.assigned_accessor
            if accessor.first_name or accessor.last_name:
                return f"{accessor.first_name or ''} {accessor.last_name or ''}".strip()
            return accessor.username
        return "N/A"
    
    def get_can_be_edited(self, obj):
        """Check if valuation can be edited"""
        return obj.can_be_edited()
    
    def get_final_report_url(self, obj):
        """Get URL for final report file"""
        if obj.final_report:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.final_report.url)
            return obj.final_report.url
        return None


class ValuationCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating valuations"""
    
    class Meta:
        model = Valuation
        fields = [
            'project', 'category', 'description', 'estimated_value', 'notes',
            # Land fields
            'land_area', 'land_type', 'land_location', 'land_latitude', 'land_longitude',
            # Building fields
            'building_area', 'building_type', 'building_location', 'building_latitude',
            'building_longitude', 'number_of_floors', 'year_built',
            # Vehicle fields
            'vehicle_make', 'vehicle_model', 'vehicle_year', 'vehicle_registration_number',
            'vehicle_mileage', 'vehicle_condition',
            # Other fields
            'other_type', 'other_specifications',
        ]
    
    def validate_project(self, value):
        """Ensure the project is assigned to the current user"""
        request = self.context.get('request')
        if request and request.user:
            if value.assigned_field_officer != request.user:
                raise serializers.ValidationError("You can only create valuations for projects assigned to you.")
        return value


class ValuationPhotoCreateSerializer(serializers.ModelSerializer):
    """Serializer for uploading valuation photos"""
    
    class Meta:
        model = ValuationPhoto
        fields = ['valuation', 'photo', 'caption']

