from rest_framework import status, generics, serializers
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from django.contrib.auth.models import User
from django.db.models import Q
from .models import Project, ProjectDocument, ProjectStatusHistory
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
from .utils import check_user_by_email, process_client_for_project, process_agent_for_project
import logging

logger = logging.getLogger(__name__)


def get_user_role(user):
    """Safely get user role, returns None if role doesn't exist"""
    try:
        if hasattr(user, 'role'):
            return user.role.role
    except Exception:
        pass
    return None


class CheckUserByEmailView(APIView):
    """Check if a user exists by email - for coordinators during project creation"""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user_role = get_user_role(request.user)
        if user_role != 'coordinator':
            return Response(
                {'error': 'Only coordinators can check user accounts'},
                status=status.HTTP_403_FORBIDDEN,
            )

        email = request.data.get('email', '').strip().lower()
        role_type = request.data.get('role_type', '')

        if not email:
            return Response({'error': 'Email is required'}, status=status.HTTP_400_BAD_REQUEST)

        if role_type not in ('client', 'agent'):
            return Response(
                {'error': 'role_type must be "client" or "agent"'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = check_user_by_email(email)

        if user:
            existing_role = get_user_role(user)
            if existing_role == role_type:
                return Response({
                    'exists': True,
                    'user': {
                        'id': user.id,
                        'username': user.username,
                        'full_name': f"{user.first_name} {user.last_name}".strip() or user.username,
                        'email': user.email,
                        'role': existing_role,
                    },
                    'message': 'Account found',
                })
            else:
                return Response({
                    'exists': True,
                    'role_mismatch': True,
                    'current_role': existing_role,
                    'expected_role': role_type,
                    'message': f'User exists but has role "{existing_role}", not "{role_type}"',
                })
        else:
            return Response({
                'exists': False,
                'message': 'No account found with this email',
            })


class ProjectListView(generics.ListCreateAPIView):
    """List all projects or create a new project"""
    permission_classes = [IsAuthenticated]
    
    def get_serializer_class(self):
        if self.request.method == 'POST':
            return ProjectCreateSerializer
        return ProjectSerializer
    
    def get_queryset(self):
        user = self.request.user
        
        # Get user role safely
        user_role = get_user_role(user)
        
        # Coordinators see all projects they created
        if user_role == 'coordinator':
            queryset = Project.objects.filter(coordinator=user)
        
        # Field officers see only assigned projects (pending, in_progress, completed)
        elif user_role == 'field_officer':
            queryset = Project.objects.filter(assigned_field_officer=user, status__in=['pending', 'in_progress', 'completed'])

        # Clients see only assigned projects (pending, in_progress, completed)
        elif user_role == 'client':
            queryset = Project.objects.filter(assigned_client=user, status__in=['pending', 'in_progress', 'completed'])

        # Agents see only assigned projects (pending, in_progress, completed)
        elif user_role == 'agent':
            queryset = Project.objects.filter(assigned_agent=user, status__in=['pending', 'in_progress', 'completed'])

        # Accessors see only assigned projects (pending, in_progress, completed)
        elif user_role == 'accessor':
            queryset = Project.objects.filter(assigned_accessor=user, status__in=['pending', 'in_progress', 'completed'])

        # Senior valuers see only assigned projects (pending, in_progress, completed)
        elif user_role == 'senior_valuer':
            queryset = Project.objects.filter(assigned_senior_valuer=user, status__in=['pending', 'in_progress', 'completed'])
        
        # Admins see all projects
        elif user.is_staff or user.is_superuser:
            queryset = Project.objects.all()
        else:
            queryset = Project.objects.none()
        
        # Optimize queryset with select_related and prefetch_related
        return queryset.select_related(
            'coordinator', 'assigned_field_officer'
        ).prefetch_related(
            'documents', 'valuations__field_officer', 'valuations__photos', 'history'
        )
    
    def perform_create(self, serializer):
        # Only coordinators can create projects
        user_role = get_user_role(self.request.user)
        if user_role != 'coordinator':
            raise serializers.ValidationError("Only coordinators can create projects.")

        project = serializer.save(coordinator=self.request.user)

        # Record project creation in history
        ProjectStatusHistory.objects.create(
            project=project,
            status=project.status,
            notes="Project created",
            created_by=self.request.user
        )

        # Process client info - check/create account and assign to project
        client_info = project.client_info
        if client_info and client_info.get('email'):
            client_user, was_created, error = process_client_for_project(project, client_info)
            if error:
                logger.warning(f"Client processing warning for project {project.id}: {error}")
            elif client_user:
                ProjectStatusHistory.objects.create(
                    project=project,
                    status=project.status,
                    notes=f"Client assigned: {client_user.first_name} {client_user.last_name}".strip() or client_user.username,
                    created_by=self.request.user
                )

        # Process agent info - check/create account and assign to project
        agent_info = project.agent_info
        if agent_info and agent_info.get('email'):
            agent_user, was_created, error = process_agent_for_project(project, agent_info)
            if error:
                logger.warning(f"Agent processing warning for project {project.id}: {error}")
            elif agent_user:
                ProjectStatusHistory.objects.create(
                    project=project,
                    status=project.status,
                    notes=f"Agent assigned: {agent_user.first_name} {agent_user.last_name}".strip() or agent_user.username,
                    created_by=self.request.user
                )

        try:
            from system_logs.utils import log_action, get_client_ip
            log_action(
                action='PROJECT_CREATED',
                user=self.request.user,
                description=f"Project created: {project.title} (ID: {project.id})",
                category='project',
                ip_address=get_client_ip(self.request),
                metadata={'project_id': project.id, 'project_title': project.title},
            )
        except Exception:
            pass

        # Send project assignment notification emails to assigned users
        try:
            from authentication.services import EmailService
            coordinator_name = f'{self.request.user.first_name} {self.request.user.last_name}'.strip() or self.request.user.username

            # Notify client
            if project.assigned_client:
                client = project.assigned_client
                client_name = f'{client.first_name} {client.last_name}'.strip() or client.username
                EmailService.send_project_assignment_notification(
                    email=client.email,
                    name=client_name,
                    project_title=project.title,
                    role_in_project='Client',
                    coordinator_name=coordinator_name,
                )

            # Notify agent
            if project.assigned_agent:
                agent = project.assigned_agent
                agent_name = f'{agent.first_name} {agent.last_name}'.strip() or agent.username
                EmailService.send_project_assignment_notification(
                    email=agent.email,
                    name=agent_name,
                    project_title=project.title,
                    role_in_project='Agent',
                    coordinator_name=coordinator_name,
                )
        except Exception:
            pass

        # If created from a client submission, update submission status to approved
        submission_id = self.request.data.get('submission_id', None)
        if submission_id:
            try:
                from authentication.models import ClientFormSubmission
                from django.utils import timezone as tz
                submission = ClientFormSubmission.objects.get(
                    id=submission_id,
                    coordinator=self.request.user,
                    status='assigned'
                )
                submission.status = 'approved'
                submission.reviewed_at = tz.now()
                submission.save()

                try:
                    from authentication.services import EmailService
                    EmailService.send_status_update(submission, 'approved')
                except Exception:
                    pass

                try:
                    from system_logs.utils import log_action, get_client_ip
                    log_action(
                        action='SUBMISSION_STATUS_UPDATED',
                        user=self.request.user,
                        description=f'Submission from {submission.first_name} {submission.last_name} approved via project creation: {project.title}',
                        category='submission',
                        ip_address=get_client_ip(self.request),
                    )
                except Exception:
                    pass
            except ClientFormSubmission.DoesNotExist:
                logger.warning(f"Submission {submission_id} not found or not assigned to coordinator")


class ProjectDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Retrieve, update or delete a project"""
    permission_classes = [IsAuthenticated]
    serializer_class = ProjectSerializer
    
    def get_queryset(self):
        user = self.request.user
        user_role = get_user_role(user)
        
        if user_role == 'coordinator':
            queryset = Project.objects.filter(coordinator=user)
        elif user_role == 'field_officer':
            queryset = Project.objects.filter(assigned_field_officer=user, status__in=['pending', 'in_progress', 'completed'])
        elif user_role == 'client':
            queryset = Project.objects.filter(assigned_client=user, status__in=['pending', 'in_progress', 'completed'])
        elif user_role == 'agent':
            queryset = Project.objects.filter(assigned_agent=user, status__in=['pending', 'in_progress', 'completed'])
        elif user_role == 'accessor':
            queryset = Project.objects.filter(assigned_accessor=user, status__in=['pending', 'in_progress', 'completed'])
        elif user_role == 'senior_valuer':
            queryset = Project.objects.filter(assigned_senior_valuer=user, status__in=['pending', 'in_progress', 'completed'])
        elif user.is_staff or user.is_superuser:
            queryset = Project.objects.all()
        else:
            queryset = Project.objects.none()

        return queryset.select_related(
            'coordinator', 'assigned_field_officer', 'assigned_client', 
            'assigned_agent', 'assigned_accessor', 'assigned_senior_valuer'
        ).prefetch_related(
            'documents', 'valuations__field_officer', 'valuations__photos', 'history'
        )
    
    def perform_update(self, serializer):
        # Only coordinators can update projects
        user_role = get_user_role(self.request.user)
        if user_role != 'coordinator':
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

            # Check if accessor is assigned
            if project.assigned_accessor is None:
                raise serializers.ValidationError(
                    "Cannot start project: Accessor must be assigned before starting."
                )

            # Check if senior valuer is assigned
            if project.assigned_senior_valuer is None:
                raise serializers.ValidationError(
                    "Cannot start project: Senior valuer must be assigned before starting."
                )

        if new_status != project.status:
            ProjectStatusHistory.objects.create(
                project=project,
                status=new_status,
                notes=f"Status changed from {project.get_status_display()} to {dict(Project.STATUS_CHOICES).get(new_status)}",
                created_by=self.request.user
            )

        serializer.save()

        try:
            from system_logs.utils import log_action, get_client_ip
            description = f"Project updated: {project.title} (ID: {project.id})"
            if new_status != project.status:
                description = f"Project status changed to {dict(Project.STATUS_CHOICES).get(new_status, new_status)}: {project.title}"
            log_action(
                action='PROJECT_UPDATED',
                user=self.request.user,
                description=description,
                category='project',
                ip_address=get_client_ip(self.request),
                metadata={'project_id': project.id, 'project_title': project.title, 'new_status': new_status},
            )
        except Exception:
            pass


class AssignFieldOfficerView(APIView):
    """Assign a field officer to a project"""
    permission_classes = [IsAuthenticated]
    
    def post(self, request, project_id):
        # Check if user is coordinator
        user_role = get_user_role(request.user)
        if user_role != 'coordinator':
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
        
        ProjectStatusHistory.objects.create(
            project=project,
            status=project.status,
            notes=f"Field Officer assigned: {field_officer.first_name} {field_officer.last_name}".strip() or field_officer.username,
            created_by=request.user
        )

        try:
            from system_logs.utils import log_action, get_client_ip
            fo_name = f"{field_officer.first_name} {field_officer.last_name}".strip() or field_officer.username
            log_action(
                action='FIELD_OFFICER_ASSIGNED',
                user=request.user,
                target_user=field_officer,
                description=f"Field officer {fo_name} assigned to project: {project.title}",
                category='project',
                ip_address=get_client_ip(request),
                metadata={'project_id': project.id, 'field_officer_id': field_officer.id},
            )
        except Exception:
            pass

        return Response({
            'message': 'Field officer assigned successfully',
            'project': ProjectSerializer(project, context={'request': request}).data
        }, status=status.HTTP_200_OK)


class AvailableFieldOfficersView(APIView):
    """Get list of available field officers for assignment"""
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        # Only coordinators can view field officers
        user_role = get_user_role(request.user)
        if user_role != 'coordinator':
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
        user_role = get_user_role(request.user)
        if user_role != 'coordinator':
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
        user_role = get_user_role(request.user)
        if user_role != 'coordinator':
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
        user_role = get_user_role(request.user)
        if user_role != 'coordinator':
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
        
        ProjectStatusHistory.objects.create(
            project=project,
            status=project.status,
            notes=f"Client assigned: {client.first_name} {client.last_name}".strip() or client.username,
            created_by=request.user
        )

        try:
            from system_logs.utils import log_action, get_client_ip
            client_name = f"{client.first_name} {client.last_name}".strip() or client.username
            log_action(
                action='CLIENT_ASSIGNED',
                user=request.user,
                target_user=client,
                description=f"Client {client_name} assigned to project: {project.title}",
                category='project',
                ip_address=get_client_ip(request),
                metadata={'project_id': project.id, 'client_id': client.id},
            )
        except Exception:
            pass

        return Response({
            'message': 'Client assigned successfully',
            'project': ProjectSerializer(project, context={'request': request}).data
        }, status=status.HTTP_200_OK)


class AssignAgentView(APIView):
    """Assign an agent to a project"""
    permission_classes = [IsAuthenticated]
    
    def post(self, request, project_id):
        # Check if user is coordinator
        user_role = get_user_role(request.user)
        if user_role != 'coordinator':
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
        
        ProjectStatusHistory.objects.create(
            project=project,
            status=project.status,
            notes=f"Agent assigned: {agent.first_name} {agent.last_name}".strip() or agent.username,
            created_by=request.user
        )

        try:
            from system_logs.utils import log_action, get_client_ip
            agent_name = f"{agent.first_name} {agent.last_name}".strip() or agent.username
            log_action(
                action='AGENT_ASSIGNED',
                user=request.user,
                target_user=agent,
                description=f"Agent {agent_name} assigned to project: {project.title}",
                category='project',
                ip_address=get_client_ip(request),
                metadata={'project_id': project.id, 'agent_id': agent.id},
            )
        except Exception:
            pass

        return Response({
            'message': 'Agent assigned successfully',
            'project': ProjectSerializer(project, context={'request': request}).data
        }, status=status.HTTP_200_OK)


class AssignAccessorView(APIView):
    """Assign an accessor to a project"""
    permission_classes = [IsAuthenticated]
    
    def post(self, request, project_id):
        # Check if user is coordinator
        user_role = get_user_role(request.user)
        if user_role != 'coordinator':
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
        
        ProjectStatusHistory.objects.create(
            project=project,
            status=project.status,
            notes=f"Accessor assigned: {accessor.first_name} {accessor.last_name}".strip() or accessor.username,
            created_by=request.user
        )

        try:
            from system_logs.utils import log_action, get_client_ip
            accessor_name = f"{accessor.first_name} {accessor.last_name}".strip() or accessor.username
            log_action(
                action='ACCESSOR_ASSIGNED',
                user=request.user,
                target_user=accessor,
                description=f"Accessor {accessor_name} assigned to project: {project.title}",
                category='project',
                ip_address=get_client_ip(request),
                metadata={'project_id': project.id, 'accessor_id': accessor.id},
            )
        except Exception:
            pass

        return Response({
            'message': 'Accessor assigned successfully',
            'project': ProjectSerializer(project, context={'request': request}).data
        }, status=status.HTTP_200_OK)


class AssignSeniorValuerView(APIView):
    """Assign a senior valuer to a project"""
    permission_classes = [IsAuthenticated]
    
    def post(self, request, project_id):
        # Check if user is coordinator
        user_role = get_user_role(request.user)
        if user_role != 'coordinator':
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
        
        ProjectStatusHistory.objects.create(
            project=project,
            status=project.status,
            notes=f"Senior Valuer assigned: {senior_valuer.first_name} {senior_valuer.last_name}".strip() or senior_valuer.username,
            created_by=request.user
        )

        try:
            from system_logs.utils import log_action, get_client_ip
            sv_name = f"{senior_valuer.first_name} {senior_valuer.last_name}".strip() or senior_valuer.username
            log_action(
                action='SENIOR_VALUER_ASSIGNED',
                user=request.user,
                target_user=senior_valuer,
                description=f"Senior valuer {sv_name} assigned to project: {project.title}",
                category='project',
                ip_address=get_client_ip(request),
                metadata={'project_id': project.id, 'senior_valuer_id': senior_valuer.id},
            )
        except Exception:
            pass

        return Response({
            'message': 'Senior valuer assigned successfully',
            'project': ProjectSerializer(project, context={'request': request}).data
        }, status=status.HTTP_200_OK)


class AvailableAccessorsView(APIView):
    """Get list of available accessors for assignment"""
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        # Only coordinators can view accessors
        user_role = get_user_role(request.user)
        if user_role != 'coordinator':
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
        user_role = get_user_role(request.user)
        if user_role != 'coordinator':
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

        try:
            from system_logs.utils import log_action, get_client_ip
            log_action(
                action='DOCUMENT_UPLOADED',
                user=self.request.user,
                description=f"Document uploaded to project: {project.title} (ID: {project.id})",
                category='project',
                ip_address=get_client_ip(self.request),
                metadata={'project_id': project.id, 'project_title': project.title},
            )
        except Exception:
            pass


class ProjectDocumentDeleteView(generics.DestroyAPIView):
    """Delete a project document"""
    permission_classes = [IsAuthenticated]
    queryset = ProjectDocument.objects.all()

    def get_queryset(self):
        user = self.request.user
        user_role = get_user_role(user)
        # Coordinators can delete documents from their projects
        # Field officers can delete documents from assigned projects
        if user_role == 'coordinator':
            return ProjectDocument.objects.filter(project__coordinator=user)
        elif user_role == 'field_officer':
            return ProjectDocument.objects.filter(project__assigned_field_officer=user)
        return ProjectDocument.objects.none()

    def perform_destroy(self, instance):
        project = instance.project
        doc_name = instance.title if hasattr(instance, 'title') else str(instance.id)
        instance.delete()

        try:
            from system_logs.utils import log_action, get_client_ip
            log_action(
                action='DOCUMENT_UPLOADED',
                user=self.request.user,
                description=f"Document deleted from project: {project.title} (ID: {project.id})",
                category='project',
                ip_address=get_client_ip(self.request),
                metadata={'project_id': project.id, 'document': doc_name},
            )
        except Exception:
            pass


from rest_framework.decorators import api_view, permission_classes as perm_classes
from django.utils import timezone


@api_view(['POST'])
@perm_classes([IsAuthenticated])
def md_gm_approve_project(request, pk):
    """MD/GM approves a project"""
    user_role = get_user_role(request.user)
    if user_role not in ('md_gm', 'admin') and not request.user.is_staff:
        return Response(
            {'error': 'Only MD/GM can approve projects'},
            status=status.HTTP_403_FORBIDDEN
        )

    try:
        project = Project.objects.get(pk=pk)
    except Project.DoesNotExist:
        return Response(
            {'error': 'Project not found'},
            status=status.HTTP_404_NOT_FOUND
        )

    project.md_gm_approval_status = 'approved'
    project.md_gm_approved_at = timezone.now()
    project.md_gm_rejection_reason = None
    project.save()

    try:
        from system_logs.utils import log_action, get_client_ip
        log_action(
            action='PROJECT_APPROVED',
            user=request.user,
            description=f"Project approved by MD/GM: {project.title} (ID: {project.id})",
            category='project',
            ip_address=get_client_ip(request),
            metadata={'project_id': project.id, 'project_title': project.title},
        )
    except Exception:
        pass

    return Response({
        'message': 'Project approved successfully',
        'project': ProjectSerializer(project, context={'request': request}).data
    }, status=status.HTTP_200_OK)


@api_view(['POST'])
@perm_classes([IsAuthenticated])
def md_gm_reject_project(request, pk):
    """MD/GM rejects a project"""
    user_role = get_user_role(request.user)
    if user_role not in ('md_gm', 'admin') and not request.user.is_staff:
        return Response(
            {'error': 'Only MD/GM can reject projects'},
            status=status.HTTP_403_FORBIDDEN
        )

    try:
        project = Project.objects.get(pk=pk)
    except Project.DoesNotExist:
        return Response(
            {'error': 'Project not found'},
            status=status.HTTP_404_NOT_FOUND
        )

    reason = request.data.get('reason', '')
    project.md_gm_approval_status = 'rejected'
    project.md_gm_rejected_at = timezone.now()
    project.md_gm_rejection_reason = reason
    project.save()

    try:
        from system_logs.utils import log_action, get_client_ip
        log_action(
            action='PROJECT_REJECTED',
            user=request.user,
            description=f"Project rejected by MD/GM: {project.title} (ID: {project.id}). Reason: {reason or 'No reason provided'}",
            category='project',
            ip_address=get_client_ip(request),
            metadata={'project_id': project.id, 'project_title': project.title, 'reason': reason},
        )
    except Exception:
        pass

    return Response({
        'message': 'Project rejected',
        'project': ProjectSerializer(project, context={'request': request}).data
    }, status=status.HTTP_200_OK)


class UserAssignedProjectsView(APIView):
    """Get projects assigned to a specific user"""
    permission_classes = [IsAuthenticated]
    
    def get(self, request, user_id, role_type):
        # Check if user is coordinator
        user_role = get_user_role(request.user)
        if user_role != 'coordinator':
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

