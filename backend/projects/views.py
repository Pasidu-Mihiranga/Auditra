from rest_framework import status, generics, serializers
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from django.contrib.auth.models import User
from django.db.models import Q
from .models import Project, ProjectDocument
from .serializers import (
    ProjectSerializer,
    ProjectCreateSerializer,
    ProjectDocumentSerializer,
    AssignFieldOfficerSerializer
)


class ProjectListView(generics.ListCreateAPIView):
    """List all projects or create a new project"""
    permission_classes = [IsAuthenticated]
    
    def get_serializer_class(self):
        if self.request.method == 'POST':
            return ProjectCreateSerializer
        return ProjectSerializer
    
    def get_queryset(self):
        user = self.request.user
        
        # Coordinators see all projects they created
        if hasattr(user, 'role') and user.role.role == 'coordinator':
            return Project.objects.filter(coordinator=user)
        
        # Field officers see only assigned projects
        elif hasattr(user, 'role') and user.role.role == 'field_officer':
            return Project.objects.filter(assigned_field_officer=user)
        
        # Admins see all projects
        elif user.is_staff or user.is_superuser:
            return Project.objects.all()
        
        return Project.objects.none()
    
    def perform_create(self, serializer):
        # Only coordinators can create projects
        if not hasattr(self.request.user, 'role') or self.request.user.role.role != 'coordinator':
            raise serializers.ValidationError("Only coordinators can create projects.")
        serializer.save(coordinator=self.request.user)


class ProjectDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Retrieve, update or delete a project"""
    permission_classes = [IsAuthenticated]
    serializer_class = ProjectSerializer
    
    def get_queryset(self):
        user = self.request.user
        
        # Coordinators can see their projects
        if hasattr(user, 'role') and user.role.role == 'coordinator':
            return Project.objects.filter(coordinator=user)
        
        # Field officers can see assigned projects
        elif hasattr(user, 'role') and user.role.role == 'field_officer':
            return Project.objects.filter(assigned_field_officer=user)
        
        # Admins can see all
        elif user.is_staff or user.is_superuser:
            return Project.objects.all()
        
        return Project.objects.none()
    
    def perform_update(self, serializer):
        # Only coordinators can update projects
        if not hasattr(self.request.user, 'role') or self.request.user.role.role != 'coordinator':
            raise serializers.ValidationError("Only coordinators can update projects.")
        serializer.save()


class AssignFieldOfficerView(APIView):
    """Assign a field officer to a project"""
    permission_classes = [IsAuthenticated]
    
    def post(self, request, project_id):
        # Check if user is coordinator
        if not hasattr(request.user, 'role') or request.user.role.role != 'coordinator':
            return Response({
                'error': 'Only coordinators can assign field officers to projects'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            project = Project.objects.get(id=project_id, coordinator=request.user)
        except Project.DoesNotExist:
            return Response({
                'error': 'Project not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        serializer = AssignFieldOfficerSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        field_officer_id = serializer.validated_data['field_officer_id']
        field_officer = User.objects.get(id=field_officer_id)
        
        project.assigned_field_officer = field_officer
        project.status = 'in_progress'
        project.save()
        
        return Response({
            'message': 'Field officer assigned successfully',
            'project': ProjectSerializer(project, context={'request': request}).data
        }, status=status.HTTP_200_OK)


class AvailableFieldOfficersView(APIView):
    """Get list of available field officers for assignment"""
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        # Only coordinators can view field officers
        if not hasattr(request.user, 'role') or request.user.role.role != 'coordinator':
            return Response({
                'error': 'Only coordinators can view field officers'
            }, status=status.HTTP_403_FORBIDDEN)
        
        field_officers = User.objects.filter(
            role__role='field_officer',
            is_active=True
        ).select_related('role')
        
        officers_data = []
        for officer in field_officers:
            assigned_projects_count = Project.objects.filter(
                assigned_field_officer=officer,
                status__in=['pending', 'in_progress']
            ).count()
            
            officers_data.append({
                'id': officer.id,
                'username': officer.username,
                'email': officer.email,
                'first_name': officer.first_name,
                'last_name': officer.last_name,
                'full_name': f"{officer.first_name} {officer.last_name}".strip() or officer.username,
                'assigned_projects_count': assigned_projects_count,
            })
        
        return Response({
            'field_officers': officers_data
        }, status=status.HTTP_200_OK)


class ProjectDocumentView(generics.CreateAPIView):
    """Upload document to a project"""
    permission_classes = [IsAuthenticated]
    serializer_class = ProjectDocumentSerializer
    
    def perform_create(self, serializer):
        project_id = self.request.data.get('project')
        
        # Check if user is coordinator of the project
        try:
            project = Project.objects.get(id=project_id)
            if project.coordinator != self.request.user:
                if not (hasattr(self.request.user, 'role') and 
                       self.request.user.role.role == 'field_officer' and
                       project.assigned_field_officer == self.request.user):
                    raise serializers.ValidationError("You don't have permission to add documents to this project.")
        except Project.DoesNotExist:
            raise serializers.ValidationError("Project not found.")
        
        serializer.save(
            project=project,
            uploaded_by=self.request.user
        )


class ProjectDocumentDeleteView(generics.DestroyAPIView):
    """Delete a project document"""
    permission_classes = [IsAuthenticated]
    queryset = ProjectDocument.objects.all()
    
    def get_queryset(self):
        user = self.request.user
        # Coordinators can delete documents from their projects
        # Field officers can delete documents from assigned projects
        if hasattr(user, 'role') and user.role.role == 'coordinator':
            return ProjectDocument.objects.filter(project__coordinator=user)
        elif hasattr(user, 'role') and user.role.role == 'field_officer':
            return ProjectDocument.objects.filter(project__assigned_field_officer=user)
        return ProjectDocument.objects.none()

