from django.urls import path
from . import views

app_name = 'projects'

urlpatterns = [
    path('', views.ProjectListView.as_view(), name='project-list'),
    path('<int:pk>/', views.ProjectDetailView.as_view(), name='project-detail'),
    path('<int:project_id>/assign-field-officer/', views.AssignFieldOfficerView.as_view(), name='assign-field-officer'),
    path('field-officers/', views.AvailableFieldOfficersView.as_view(), name='available-field-officers'),
    path('documents/', views.ProjectDocumentView.as_view(), name='project-document-create'),
    path('documents/<int:pk>/', views.ProjectDocumentDeleteView.as_view(), name='project-document-delete'),
]

