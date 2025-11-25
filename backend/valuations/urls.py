from django.urls import path
from . import views

app_name = 'valuations'

urlpatterns = [
    # Valuation endpoints
    path('', views.ValuationListCreateView.as_view(), name='valuation-list-create'),
    path('<int:pk>/', views.ValuationDetailView.as_view(), name='valuation-detail'),
    path('<int:pk>/submit/', views.submit_valuation, name='valuation-submit'),
    
    # Valuation photo endpoints
    path('<int:valuation_id>/photos/', views.ValuationPhotoListCreateView.as_view(), name='valuation-photo-list-create'),
    path('photos/<int:pk>/', views.ValuationPhotoDetailView.as_view(), name='valuation-photo-detail'),
]

