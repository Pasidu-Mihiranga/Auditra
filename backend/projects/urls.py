from django.urls import path
from . import views

app_name = 'projects'

urlpatterns = [
    path('', views.ProjectListView.as_view(), name='project-list'),
    path('check-email/', views.CheckUserByEmailView.as_view(), name='check-email'),
    path('<int:pk>/', views.ProjectDetailView.as_view(), name='project-detail'),
    path('<int:project_id>/assign-field-officer/', views.AssignFieldOfficerView.as_view(), name='assign-field-officer'),
    path('<int:project_id>/assign-client/', views.AssignClientView.as_view(), name='assign-client'),
    path('<int:project_id>/assign-agent/', views.AssignAgentView.as_view(), name='assign-agent'),
    path('<int:project_id>/assign-accessor/', views.AssignAccessorView.as_view(), name='assign-accessor'),
    path('<int:project_id>/assign-senior-valuer/', views.AssignSeniorValuerView.as_view(), name='assign-senior-valuer'),
    path('field-officers/', views.AvailableFieldOfficersView.as_view(), name='available-field-officers'),
    path('clients/', views.AvailableClientsView.as_view(), name='available-clients'),
    path('agents/', views.AvailableAgentsView.as_view(), name='available-agents'),
    path('accessors/', views.AvailableAccessorsView.as_view(), name='available-accessors'),
    path('senior-valuers/', views.AvailableSeniorValuersView.as_view(), name='available-senior-valuers'),
    path('users/<int:user_id>/projects/<str:role_type>/', views.UserAssignedProjectsView.as_view(), name='user-assigned-projects'),
    path('documents/', views.ProjectDocumentView.as_view(), name='project-document-create'),
    path('documents/<int:pk>/', views.ProjectDocumentDeleteView.as_view(), name='project-document-delete'),
    path('<int:pk>/md-gm-approve/', views.md_gm_approve_project, name='md-gm-approve-project'),
    path('<int:pk>/md-gm-reject/', views.md_gm_reject_project, name='md-gm-reject-project'),
]

