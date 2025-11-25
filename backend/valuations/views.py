from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from .models import Valuation, ValuationPhoto
from .serializers import (
    ValuationSerializer, ValuationCreateSerializer,
    ValuationPhotoSerializer, ValuationPhotoCreateSerializer
)
from projects.models import Project


class ValuationListCreateView(generics.ListCreateAPIView):
    """List and create valuations"""
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user
        project_id = self.request.query_params.get('project', None)
        
        queryset = Valuation.objects.filter(field_officer=user)
        
        if project_id:
            queryset = queryset.filter(project_id=project_id)
        
        return queryset.select_related('project', 'field_officer').prefetch_related('photos')
    
    def get_serializer_class(self):
        if self.request.method == 'POST':
            return ValuationCreateSerializer
        return ValuationSerializer
    
    def perform_create(self, serializer):
        serializer.save(field_officer=self.request.user)
    
    def create(self, request, *args, **kwargs):
        """Override create to provide better error messages and return full object with id"""
        serializer = self.get_serializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {
                    'detail': 'Validation failed',
                    'errors': serializer.errors
                },
                status=status.HTTP_400_BAD_REQUEST
            )
        self.perform_create(serializer)
        
        # Return the full object with id using ValuationSerializer
        instance = serializer.instance
        full_serializer = ValuationSerializer(instance, context={'request': request})
        headers = self.get_success_headers(full_serializer.data)
        return Response(full_serializer.data, status=status.HTTP_201_CREATED, headers=headers)


class ValuationDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Retrieve, update, or delete a valuation"""
    permission_classes = [IsAuthenticated]
    serializer_class = ValuationSerializer
    
    def get_queryset(self):
        return Valuation.objects.filter(field_officer=self.request.user).select_related(
            'project', 'field_officer'
        ).prefetch_related('photos')
    
    def get_serializer_class(self):
        if self.request.method in ['PUT', 'PATCH']:
            return ValuationCreateSerializer
        return ValuationSerializer
    
    def update(self, request, *args, **kwargs):
        """Override update to check if valuation can be edited"""
        instance = self.get_object()
        
        # Check if valuation can be edited (draft or submitted within 2 hours)
        if not instance.can_be_edited():
            return Response(
                {
                    'error': 'This valuation cannot be edited. Only draft valuations or valuations submitted within the last 2 hours can be edited.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # If status is submitted and being edited, reset to draft
        if instance.status == 'submitted':
            instance.status = 'draft'
            instance.submitted_at = None
            instance.save()
        
        return super().update(request, *args, **kwargs)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def submit_valuation(request, pk):
    """Submit a valuation (change status from draft to submitted)"""
    valuation = get_object_or_404(
        Valuation,
        pk=pk,
        field_officer=request.user
    )
    
    if valuation.status != 'draft':
        return Response(
            {'error': 'Only draft valuations can be submitted.'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    valuation.submit()
    serializer = ValuationSerializer(valuation, context={'request': request})
    return Response(serializer.data, status=status.HTTP_200_OK)


class ValuationPhotoListCreateView(generics.ListCreateAPIView):
    """List and create valuation photos"""
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        valuation_id = self.kwargs.get('valuation_id')
        return ValuationPhoto.objects.filter(
            valuation_id=valuation_id,
            valuation__field_officer=self.request.user
        )
    
    def get_serializer_class(self):
        if self.request.method == 'POST':
            return ValuationPhotoCreateSerializer
        return ValuationPhotoSerializer
    
    def perform_create(self, serializer):
        valuation_id = self.kwargs.get('valuation_id')
        valuation = get_object_or_404(
            Valuation,
            pk=valuation_id,
            field_officer=self.request.user
        )
        serializer.save(valuation=valuation)


class ValuationPhotoDetailView(generics.RetrieveDestroyAPIView):
    """Retrieve or delete a valuation photo"""
    permission_classes = [IsAuthenticated]
    serializer_class = ValuationPhotoSerializer
    
    def get_queryset(self):
        return ValuationPhoto.objects.filter(
            valuation__field_officer=self.request.user
        )
