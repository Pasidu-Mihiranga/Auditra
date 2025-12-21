from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from django.db import transaction
import logging
from .models import Valuation, ValuationPhoto
from .serializers import (
    ValuationSerializer, ValuationCreateSerializer,
    ValuationPhotoSerializer, ValuationPhotoCreateSerializer
)
from projects.models import Project

logger = logging.getLogger(__name__)


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
        
        # If status is submitted or rejected and being edited, reset to draft
        # This allows rejected reports to be updated and resubmitted
        if instance.status == 'submitted':
            instance.status = 'draft'
            instance.submitted_at = None
            instance.save()
        elif instance.status == 'rejected':
            instance.status = 'draft'
            instance.rejection_reason = ''  # Clear rejection reason when resubmitting
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


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@transaction.atomic
def accept_valuation(request, pk):
    """Accept a valuation (change status to reviewed/approved)"""
    valuation = get_object_or_404(Valuation, pk=pk)
    
    # Check if user is an accessor (has accessor role)
    if not hasattr(request.user, 'role') or request.user.role.role != 'accessor':
        return Response(
            {'error': 'Only accessors can accept valuations.'},
            status=status.HTTP_403_FORBIDDEN
        )
    
    # Check if accessor is assigned to the project
    if valuation.project.assigned_accessor != request.user:
        return Response(
            {'error': 'You can only accept valuations for projects assigned to you.'},
            status=status.HTTP_403_FORBIDDEN
        )
    
    # Allow accepting draft or submitted valuations only
    if valuation.status not in ['draft', 'submitted']:
        return Response(
            {'error': f'Cannot accept valuation with status: {valuation.status}. Only draft or submitted valuations can be accepted.'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Change status to reviewed (accessor acceptance - not final approval)
    # Reports remain as reviewed until senior valuer approves them
    valuation.status = 'reviewed'
    
    # Clear rejection reason if it exists
    valuation.rejection_reason = ''
    valuation.save(update_fields=['status', 'rejection_reason', 'updated_at'])
    
    logger.info(f'Valuation {valuation.id} accepted by accessor {request.user.username} - status changed to reviewed')
    
    serializer = ValuationSerializer(valuation, context={'request': request})
    return Response(serializer.data, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@transaction.atomic
def reject_valuation(request, pk):
    """Reject a valuation (change status to rejected)"""
    valuation = get_object_or_404(Valuation, pk=pk)
    
    # Check if user is an accessor (has accessor role)
    if not hasattr(request.user, 'role') or request.user.role.role != 'accessor':
        return Response(
            {'error': 'Only accessors can reject valuations.'},
            status=status.HTTP_403_FORBIDDEN
        )
    
    # Check if accessor is assigned to the project
    if valuation.project.assigned_accessor != request.user:
        return Response(
            {'error': 'You can only reject valuations for projects assigned to you.'},
            status=status.HTTP_403_FORBIDDEN
        )
    
    # Allow rejecting draft, submitted, or reviewed valuations
    if valuation.status not in ['draft', 'submitted', 'reviewed']:
        return Response(
            {'error': f'Cannot reject valuation with status: {valuation.status}'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Get rejection reason from request
    rejection_reason = request.data.get('rejection_reason', '').strip()
    if not rejection_reason:
        return Response(
            {'error': 'Rejection reason is required.'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Update valuation status and rejection reason
    valuation.status = 'rejected'
    valuation.rejection_reason = rejection_reason
    valuation.save(update_fields=['status', 'rejection_reason', 'updated_at'])
    
    logger.info(f'Valuation {valuation.id} rejected by accessor {request.user.username}')
    
    serializer = ValuationSerializer(valuation, context={'request': request})
    return Response(serializer.data, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@transaction.atomic
def senior_valuer_approve_valuation(request, pk):
    """Approve a valuation (change status to approved) - Only senior valuer can do this"""
    valuation = get_object_or_404(Valuation, pk=pk)
    
    # Check if user is a senior valuer (has senior_valuer role)
    if not hasattr(request.user, 'role') or request.user.role.role != 'senior_valuer':
        return Response(
            {'error': 'Only senior valuers can approve valuations.'},
            status=status.HTTP_403_FORBIDDEN
        )
    
    # Check if senior valuer is assigned to the project
    if valuation.project.assigned_senior_valuer != request.user:
        return Response(
            {'error': 'You can only approve valuations for projects assigned to you.'},
            status=status.HTTP_403_FORBIDDEN
        )
    
    # Only reviewed valuations can be approved by senior valuer
    if valuation.status != 'reviewed':
        return Response(
            {'error': f'Only reviewed valuations can be approved. Current status: {valuation.status}'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Change status to approved (final approval by senior valuer)
    valuation.status = 'approved'
    valuation.save(update_fields=['status', 'updated_at'])
    
    logger.info(f'Valuation {valuation.id} approved by senior valuer {request.user.username}')
    
    serializer = ValuationSerializer(valuation, context={'request': request})
    return Response(serializer.data, status=status.HTTP_200_OK)
