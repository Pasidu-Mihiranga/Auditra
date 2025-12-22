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
    AssignFieldOfficerSerializer,
    AssignClientSerializer,
    AssignAgentSerializer,
    AssignAccessorSerializer,
    AssignSeniorValuerSerializer
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
            queryset = Project.objects.filter(coordinator=user)
        
        # Field officers see only assigned projects
        elif hasattr(user, 'role') and user.role.role == 'field_officer':
            queryset = Project.objects.filter(assigned_field_officer=user)
        
        # Clients see only assigned projects
        elif hasattr(user, 'role') and user.role.role == 'client':
            return Project.objects.filter(assigned_client=user)
        
        # Agents see only assigned projects
        elif hasattr(user, 'role') and user.role.role == 'agent':
            return Project.objects.filter(assigned_agent=user)
        
        # Accessors see only assigned projects
        elif hasattr(user, 'role') and user.role.role == 'accessor':
            return Project.objects.filter(assigned_accessor=user)
        
        # Senior valuers see only assigned projects
        elif hasattr(user, 'role') and user.role.role == 'senior_valuer':
            return Project.objects.filter(assigned_senior_valuer=user)
        
        # Clients see only assigned projects
        elif hasattr(user, 'role') and user.role.role == 'client':
            return Project.objects.filter(assigned_client=user)
        
        # Agents see only assigned projects
        elif hasattr(user, 'role') and user.role.role == 'agent':
            return Project.objects.filter(assigned_agent=user)
        
        # Accessors see only assigned projects
        elif hasattr(user, 'role') and user.role.role == 'accessor':
            return Project.objects.filter(assigned_accessor=user)
        
        # Senior valuers see only assigned projects
        elif hasattr(user, 'role') and user.role.role == 'senior_valuer':
            return Project.objects.filter(assigned_senior_valuer=user)
        
        # Admins see all projects
        elif user.is_staff or user.is_superuser:
            queryset = Project.objects.all()
        else:
            queryset = Project.objects.none()
        
        # Optimize queryset with select_related and prefetch_related
        return queryset.select_related(
            'coordinator', 'assigned_field_officer'
        ).prefetch_related(
            'documents', 'valuations__field_officer', 'valuations__photos'
        )
    
    def perform_create(self, serializer):
        # Only coordinators can create projects
        if not hasattr(self.request.user, 'role') or self.request.user.role.role != 'coordinator':
            raise serializers.ValidationError("Only coordinators can create projects.")
        
        # Remove client_info and agent_info from request data if present
        # These are informational and not stored in the Project model
        # They can be assigned later using the assign endpoints
        project = serializer.save(coordinator=self.request.user)
        
        # Create Firebase group chat for the project
        try:
            from chat.firebase_admin import create_project_group_chat
            create_project_group_chat(project)
        except Exception as e:
            # Log error but don't fail project creation
            print(f"Warning: Failed to create group chat for project {project.id}: {e}")


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
        
        # Clients can see assigned projects
        elif hasattr(user, 'role') and user.role.role == 'client':
            return Project.objects.filter(assigned_client=user)
        
        # Agents can see assigned projects
        elif hasattr(user, 'role') and user.role.role == 'agent':
            return Project.objects.filter(assigned_agent=user)
        
        # Accessors can see assigned projects
        elif hasattr(user, 'role') and user.role.role == 'accessor':
            return Project.objects.filter(assigned_accessor=user)
        
        # Senior valuers can see assigned projects
        elif hasattr(user, 'role') and user.role.role == 'senior_valuer':
            return Project.objects.filter(assigned_senior_valuer=user)
        
        # Admins can see all
        elif user.is_staff or user.is_superuser:
            return Project.objects.all()
        
        return Project.objects.none()
    
    def perform_update(self, serializer):
        # Only coordinators can update projects
        if not hasattr(self.request.user, 'role') or self.request.user.role.role != 'coordinator':
            raise serializers.ValidationError("Only coordinators can update projects.")
        
        project = serializer.instance
        new_status = serializer.validated_data.get('status', project.status)
        
        # If changing status to 'in_progress', validate that all required users are assigned
        if new_status == 'in_progress' and project.status != 'in_progress':
            # Check if field officer is assigned
            if project.assigned_field_officer is None:
                raise serializers.ValidationError(
                    "Cannot start project: Field officer must be assigned before starting."
                )
            
            # Check if client is assigned
            if project.assigned_client is None:
                raise serializers.ValidationError(
                    "Cannot start project: Client must be assigned before starting."
                )
            
            # Check if agent is assigned (if required)
            if project.has_agent and project.assigned_agent is None:
                raise serializers.ValidationError(
                    "Cannot start project: Agent must be assigned before starting."
                )
        
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
        project.save()
        
        # Add field officer to project group chat
        try:
            from chat.firebase_admin import add_member_to_group_chat
            add_member_to_group_chat(project.id, field_officer.id, 'field_officer')
        except Exception as e:
            print(f"Warning: Failed to add field officer to group chat: {e}")
        
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


class AvailableClientsView(APIView):
    """Get list of available clients for assignment"""
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        # Only coordinators can view clients
        if not hasattr(request.user, 'role') or request.user.role.role != 'coordinator':
            return Response({
                'error': 'Only coordinators can view clients'
            }, status=status.HTTP_403_FORBIDDEN)
        
        clients = User.objects.filter(
            role__role='client',
            is_active=True
        ).select_related('role')
        
        clients_data = []
        for client in clients:
            assigned_projects_count = Project.objects.filter(
                assigned_client=client
            ).count()
            
            clients_data.append({
                'id': client.id,
                'username': client.username,
                'email': client.email,
                'first_name': client.first_name,
                'last_name': client.last_name,
                'full_name': f"{client.first_name} {client.last_name}".strip() or client.username,
                'assigned_projects_count': assigned_projects_count,
            })
        
        return Response({
            'clients': clients_data
        }, status=status.HTTP_200_OK)


class AvailableAgentsView(APIView):
    """Get list of available agents for assignment"""
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        # Only coordinators can view agents
        if not hasattr(request.user, 'role') or request.user.role.role != 'coordinator':
            return Response({
                'error': 'Only coordinators can view agents'
            }, status=status.HTTP_403_FORBIDDEN)
        
        agents = User.objects.filter(
            role__role='agent',
            is_active=True
        ).select_related('role')
        
        agents_data = []
        for agent in agents:
            assigned_projects_count = Project.objects.filter(
                assigned_agent=agent
            ).count()
            
            agents_data.append({
                'id': agent.id,
                'username': agent.username,
                'email': agent.email,
                'first_name': agent.first_name,
                'last_name': agent.last_name,
                'full_name': f"{agent.first_name} {agent.last_name}".strip() or agent.username,
                'assigned_projects_count': assigned_projects_count,
            })
        
        return Response({
            'agents': agents_data
        }, status=status.HTTP_200_OK)


class AssignClientView(APIView):
    """Assign a client to a project"""
    permission_classes = [IsAuthenticated]
    
    def post(self, request, project_id):
        # Check if user is coordinator
        if not hasattr(request.user, 'role') or request.user.role.role != 'coordinator':
            return Response({
                'error': 'Only coordinators can assign clients to projects'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            project = Project.objects.get(id=project_id, coordinator=request.user)
        except Project.DoesNotExist:
            return Response({
                'error': 'Project not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        serializer = AssignClientSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        client_id = serializer.validated_data['client_id']
        client = User.objects.get(id=client_id)
        
        project.assigned_client = client
        project.save()
        
        return Response({
            'message': 'Client assigned successfully',
            'project': ProjectSerializer(project, context={'request': request}).data
        }, status=status.HTTP_200_OK)


class AssignAgentView(APIView):
    """Assign an agent to a project"""
    permission_classes = [IsAuthenticated]
    
    def post(self, request, project_id):
        # Check if user is coordinator
        if not hasattr(request.user, 'role') or request.user.role.role != 'coordinator':
            return Response({
                'error': 'Only coordinators can assign agents to projects'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            project = Project.objects.get(id=project_id, coordinator=request.user)
        except Project.DoesNotExist:
            return Response({
                'error': 'Project not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        serializer = AssignAgentSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        agent_id = serializer.validated_data['agent_id']
        agent = User.objects.get(id=agent_id)
        
        project.assigned_agent = agent
        project.save()
        
        return Response({
            'message': 'Agent assigned successfully',
            'project': ProjectSerializer(project, context={'request': request}).data
        }, status=status.HTTP_200_OK)


class AssignAccessorView(APIView):
    """Assign an accessor to a project"""
    permission_classes = [IsAuthenticated]
    
    def post(self, request, project_id):
        # Check if user is coordinator
        if not hasattr(request.user, 'role') or request.user.role.role != 'coordinator':
            return Response({
                'error': 'Only coordinators can assign accessors to projects'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            project = Project.objects.get(id=project_id, coordinator=request.user)
        except Project.DoesNotExist:
            return Response({
                'error': 'Project not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        serializer = AssignAccessorSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        accessor_id = serializer.validated_data['accessor_id']
        accessor = User.objects.get(id=accessor_id)
        
        project.assigned_accessor = accessor
        project.save()
        
        # Add accessor to project group chat
        try:
            from chat.firebase_admin import add_member_to_group_chat
            add_member_to_group_chat(project.id, accessor.id, 'accessor')
        except Exception as e:
            print(f"Warning: Failed to add accessor to group chat: {e}")
        
        return Response({
            'message': 'Accessor assigned successfully',
            'project': ProjectSerializer(project, context={'request': request}).data
        }, status=status.HTTP_200_OK)


class AssignSeniorValuerView(APIView):
    """Assign a senior valuer to a project"""
    permission_classes = [IsAuthenticated]
    
    def post(self, request, project_id):
        # Check if user is coordinator
        if not hasattr(request.user, 'role') or request.user.role.role != 'coordinator':
            return Response({
                'error': 'Only coordinators can assign senior valuers to projects'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            project = Project.objects.get(id=project_id, coordinator=request.user)
        except Project.DoesNotExist:
            return Response({
                'error': 'Project not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        serializer = AssignSeniorValuerSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        senior_valuer_id = serializer.validated_data['senior_valuer_id']
        senior_valuer = User.objects.get(id=senior_valuer_id)
        
        project.assigned_senior_valuer = senior_valuer
        project.save()
        
        # Add senior valuer to project group chat
        try:
            from chat.firebase_admin import add_member_to_group_chat
            add_member_to_group_chat(project.id, senior_valuer.id, 'senior_valuer')
        except Exception as e:
            print(f"Warning: Failed to add senior valuer to group chat: {e}")
        
        return Response({
            'message': 'Senior valuer assigned successfully',
            'project': ProjectSerializer(project, context={'request': request}).data
        }, status=status.HTTP_200_OK)


class AvailableAccessorsView(APIView):
    """Get list of available accessors for assignment"""
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        # Only coordinators can view accessors
        if not hasattr(request.user, 'role') or request.user.role.role != 'coordinator':
            return Response({
                'error': 'Only coordinators can view accessors'
            }, status=status.HTTP_403_FORBIDDEN)
        
        accessors = User.objects.filter(
            role__role='accessor',
            is_active=True
        ).select_related('role')
        
        accessors_data = []
        for accessor in accessors:
            assigned_projects_count = Project.objects.filter(
                assigned_accessor=accessor
            ).count()
            
            accessors_data.append({
                'id': accessor.id,
                'username': accessor.username,
                'email': accessor.email,
                'first_name': accessor.first_name,
                'last_name': accessor.last_name,
                'full_name': f"{accessor.first_name} {accessor.last_name}".strip() or accessor.username,
                'assigned_projects_count': assigned_projects_count,
            })
        
        return Response({
            'accessors': accessors_data
        }, status=status.HTTP_200_OK)


class AvailableSeniorValuersView(APIView):
    """Get list of available senior valuers for assignment"""
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        # Only coordinators can view senior valuers
        if not hasattr(request.user, 'role') or request.user.role.role != 'coordinator':
            return Response({
                'error': 'Only coordinators can view senior valuers'
            }, status=status.HTTP_403_FORBIDDEN)
        
        senior_valuers = User.objects.filter(
            role__role='senior_valuer',
            is_active=True
        ).select_related('role')
        
        senior_valuers_data = []
        for valuer in senior_valuers:
            assigned_projects_count = Project.objects.filter(
                assigned_senior_valuer=valuer
            ).count()
            
            senior_valuers_data.append({
                'id': valuer.id,
                'username': valuer.username,
                'email': valuer.email,
                'first_name': valuer.first_name,
                'last_name': valuer.last_name,
                'full_name': f"{valuer.first_name} {valuer.last_name}".strip() or valuer.username,
                'assigned_projects_count': assigned_projects_count,
            })
        
        return Response({
            'senior_valuers': senior_valuers_data
        }, status=status.HTTP_200_OK)


class ProjectDocumentView(generics.CreateAPIView):
    """Upload document to a project"""
    permission_classes = [IsAuthenticated]
    serializer_class = ProjectDocumentSerializer
    
    def perform_create(self, serializer):
        project_id = self.request.data.get('project')
        assigned_to_id = self.request.data.get('assigned_to')
        
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
        
        # Validate assigned_to user if provided
        assigned_to = None
        if assigned_to_id:
            try:
                assigned_to = User.objects.get(id=assigned_to_id)
                # Verify the user is actually assigned to this project
                if (assigned_to != project.assigned_field_officer and
                    assigned_to != project.assigned_client and
                    assigned_to != project.assigned_agent and
                    assigned_to != project.assigned_accessor and
                    assigned_to != project.assigned_senior_valuer):
                    raise serializers.ValidationError("Selected user is not assigned to this project.")
            except User.DoesNotExist:
                raise serializers.ValidationError("Assigned user not found.")
        
        serializer.save(
            project=project,
            uploaded_by=self.request.user,
            assigned_to=assigned_to
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


class UserAssignedProjectsView(APIView):
    """Get projects assigned to a specific user"""
    permission_classes = [IsAuthenticated]
    
    def get(self, request, user_id, role_type):
        # Check if user is coordinator
        if not hasattr(request.user, 'role') or request.user.role.role != 'coordinator':
            return Response({
                'error': 'Only coordinators can view user assigned projects'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            return Response({
                'error': 'User not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Get projects based on role type
        if role_type == 'field_officer':
            projects = Project.objects.filter(assigned_field_officer=user).order_by('-created_at')
        elif role_type == 'accessor':
            projects = Project.objects.filter(assigned_accessor=user).order_by('-created_at')
        elif role_type == 'senior_valuer':
            projects = Project.objects.filter(assigned_senior_valuer=user).order_by('-created_at')
        else:
            return Response({
                'error': 'Invalid role type'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        projects_data = []
        for project in projects:
            # Get the assignment date (use created_at as proxy, or we could add an assigned_at field)
            projects_data.append({
                'id': project.id,
                'title': project.title,
                'status': project.status,
                'status_display': project.get_status_display(),
                'assigned_date': project.created_at.isoformat(),  # Using created_at as assigned date
            })
        
        return Response({
            'projects': projects_data,
            'user': {
                'id': user.id,
                'username': user.username,
                'full_name': f"{user.first_name} {user.last_name}".strip() or user.username,
            }
        }, status=status.HTTP_200_OK)

