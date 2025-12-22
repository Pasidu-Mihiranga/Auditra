"""
Firebase Admin SDK integration for server-side operations
"""
import os
import firebase_admin
from firebase_admin import credentials, firestore, auth
from django.conf import settings
from django.contrib.auth.models import User


# Initialize Firebase Admin SDK (singleton pattern)
_firebase_app = None


def initialize_firebase():
    """Initialize Firebase Admin SDK"""
    global _firebase_app
    
    if _firebase_app is not None:
        return _firebase_app
    
    try:
        # Try to use service account from environment variable or Django settings
        from django.conf import settings
        service_account_path = os.environ.get(
            'FIREBASE_SERVICE_ACCOUNT_PATH',
            getattr(settings, 'FIREBASE_SERVICE_ACCOUNT_PATH', None)
        )
        
        if service_account_path and os.path.exists(service_account_path):
            cred = credentials.Certificate(service_account_path)
            _firebase_app = firebase_admin.initialize_app(cred)
        else:
            # Try default credentials (for Google Cloud environments)
            _firebase_app = firebase_admin.initialize_app()
        
        return _firebase_app
    except Exception as e:
        print(f"Warning: Firebase Admin SDK not initialized: {e}")
        print("Firebase features will be disabled. To enable:")
        print("1. Download service account key from Firebase Console")
        print("2. Set FIREBASE_SERVICE_ACCOUNT_PATH environment variable")
        return None


def create_custom_token(user_id, additional_claims=None):
    """
    Create a Firebase custom token for a Django user
    
    Args:
        user_id: Django user ID
        additional_claims: Dictionary of additional claims to include in token
    
    Returns:
        Custom token string
    """
    app = initialize_firebase()
    if app is None:
        raise FileNotFoundError("Firebase Admin SDK not initialized")
    
    # Use Django user ID as Firebase UID (prefixed to avoid conflicts)
    firebase_uid = f"django_{user_id}"
    
    # Create custom token
    custom_token = auth.create_custom_token(
        firebase_uid,
        additional_claims or {}
    )
    
    return custom_token.decode('utf-8')


def create_project_group_chat(project):
    """
    Create a Firestore group chat for a project
    
    Args:
        project: Django Project instance
    """
    app = initialize_firebase()
    if app is None:
        print("Warning: Firebase not initialized, skipping group chat creation")
        return None
    
    db = firestore.client()
    
    # Get project members (excluding client and agent)
    members = []
    member_roles = {}
    
    # Add coordinator
    if project.coordinator:
        members.append(f"django_{project.coordinator.id}")
        member_roles[f"django_{project.coordinator.id}"] = 'coordinator'
    
    # Add field officer if assigned
    if project.assigned_field_officer:
        members.append(f"django_{project.assigned_field_officer.id}")
        member_roles[f"django_{project.assigned_field_officer.id}"] = 'field_officer'
    
    # Add accessor if assigned
    if project.assigned_accessor:
        members.append(f"django_{project.assigned_accessor.id}")
        member_roles[f"django_{project.assigned_accessor.id}"] = 'accessor'
    
    # Add senior valuer if assigned
    if project.assigned_senior_valuer:
        members.append(f"django_{project.assigned_senior_valuer.id}")
        member_roles[f"django_{project.assigned_senior_valuer.id}"] = 'senior_valuer'
    
    # Don't create chat if no members (shouldn't happen, but safety check)
    if not members:
        return None
    
    # Create chat document
    chat_data = {
        'type': 'group',
        'projectId': str(project.id),
        'projectTitle': project.title,
        'members': members,
        'memberRoles': member_roles,
        'createdBy': f"django_{project.coordinator.id}",
        'createdAt': firestore.SERVER_TIMESTAMP,
        'lastMessage': '',
        'lastMessageTime': None,
        'unreadCount': {member: 0 for member in members}
    }
    
    # Use project ID as chat ID for easy lookup
    chat_id = f"project_{project.id}"
    
    try:
        db.collection('chats').document(chat_id).set(chat_data)
        return chat_id
    except Exception as e:
        print(f"Error creating group chat: {e}")
        return None


def add_member_to_group_chat(project_id, user_id, role):
    """
    Add a member to an existing project group chat
    
    Args:
        project_id: Project ID
        user_id: Django user ID
        role: User role
    """
    app = initialize_firebase()
    if app is None:
        return False
    
    db = firestore.client()
    chat_id = f"project_{project_id}"
    firebase_uid = f"django_{user_id}"
    
    try:
        chat_ref = db.collection('chats').document(chat_id)
        chat_doc = chat_ref.get()
        
        if not chat_doc.exists:
            return False
        
        # Update members and memberRoles
        chat_ref.update({
            'members': firestore.ArrayUnion([firebase_uid]),
            f'memberRoles.{firebase_uid}': role,
            f'unreadCount.{firebase_uid}': 0
        })
        
        return True
    except Exception as e:
        print(f"Error adding member to group chat: {e}")
        return False


def remove_member_from_group_chat(project_id, user_id):
    """
    Remove a member from project group chat (optional - may keep for history)
    
    Args:
        project_id: Project ID
        user_id: Django user ID
    """
    app = initialize_firebase()
    if app is None:
        return False
    
    db = firestore.client()
    chat_id = f"project_{project_id}"
    firebase_uid = f"django_{user_id}"
    
    try:
        chat_ref = db.collection('chats').document(chat_id)
        
        # Remove from members array and clean up
        chat_ref.update({
            'members': firestore.ArrayRemove([firebase_uid])
        })
        
        # Note: We keep memberRoles and unreadCount for history
        # Can be cleaned up later if needed
        
        return True
    except Exception as e:
        print(f"Error removing member from group chat: {e}")
        return False
