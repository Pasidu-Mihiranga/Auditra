from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from projects.models import Project, ProjectStatusHistory
from valuations.models import Valuation
from authentication.models import UserRole, LeaveRequest, PaymentSlip, EmployeeRemovalRequest, ClientFormSubmission, EmployeeFormSubmission
from attendance.models import Attendance, Holiday
from django.utils import timezone
from datetime import datetime, time, timedelta
import random

class Command(BaseCommand):
    help = 'Populate mock data for projects, status history, valuations, attendance, leave requests, and payment slips'

    def handle(self, *args, **options):
        self.stdout.write('Starting mock data population...')

        # 1. Ensure users for each role exist
        roles = ['coordinator', 'field_officer', 'client', 'agent', 'accessor', 'senior_valuer']
        users = {}

        for role_name in roles:
            username = f'mock_{role_name}'
            user, created = User.objects.get_or_create(
                username=username,
                defaults={
                    'email': f'{username}@example.com',
                    'first_name': f'Mock',
                    'last_name': role_name.replace('_', ' ').title()
                }
            )
            if created:
                user.set_password('password123')
                user.save()
            
            # Ensure correct role
            user_role, role_created = UserRole.objects.get_or_create(user=user)
            user_role.role = role_name
            user_role.save()
            
            users[role_name] = user
            self.stdout.write(f'User ready: {username} ({role_name})')

        # 2. Populate Attendance for the last 45 days (to cover Jan and Feb)
        self.stdout.write('\nGenerating attendance data for the last 45 days...')
        staff_roles = ['coordinator', 'field_officer', 'accessor', 'senior_valuer']
        today = timezone.localdate()
        tz = timezone.get_current_timezone()

        for role_name in staff_roles:
            user = users[role_name]
            count = 0
            # Delete old mock attendance to fresh start
            Attendance.objects.filter(user=user).delete()
            
            for d in range(45):
                date = today - timedelta(days=d)
                
                # Skip Sundays and Holidays
                if date.weekday() == 6 or Holiday.objects.filter(date=date, is_active=True).exists():
                    continue
                
                # Randomize if present, absent, or half-day (90% present, 5% half-day, 5% absent)
                rand = random.random()
                if rand < 0.05: # Absent
                    Attendance.objects.create(user=user, date=date, status='absent')
                    continue
                
                # Create attendance
                att = Attendance(user=user, date=date, status='present')
                
                # Check-in: Randomly between 7:45 AM and 8:30 AM
                check_in_time = time(7, 45) if random.random() > 0.5 else time(8, random.randint(0, 30))
                att.check_in = timezone.make_aware(datetime.combine(date, check_in_time), tz)
                
                if rand < 0.10: # Half-day
                    # Check-out: Randomly between 12:00 PM and 1:00 PM
                    check_out_time = time(12, random.randint(0, 59))
                    att.check_out = timezone.make_aware(datetime.combine(date, check_out_time), tz)
                else: # Present
                    # Check-out: Randomly between 5:00 PM and 5:30 PM
                    check_out_time = time(17, random.randint(0, 30))
                    att.check_out = timezone.make_aware(datetime.combine(date, check_out_time), tz)
                    
                    # Optional Overtime (30% chance)
                    if random.random() < 0.3:
                        att.overtime_start = att.check_out
                        att.overtime_end = att.overtime_start + timedelta(hours=random.randint(1, 4), minutes=random.randint(0, 59))
                
                att.save() # calculates hours and status
                count += 1
            
            self.stdout.write(f'Created {count} attendance records for {user.username}')

        # 3. Populate Leave Requests
        self.stdout.write('\nGenerating leave requests...')
        leave_types = ['annual', 'sick', 'casual', 'emergency']
        
        for role_name in staff_roles:
            user = users[role_name]
            # Delete old mock leaves
            LeaveRequest.objects.filter(user=user).delete()
            
            # Scenario 1: Approved Leave (Recent past)
            LeaveRequest.objects.create(
                user=user,
                leave_type=random.choice(leave_types),
                start_date=today - timedelta(days=20),
                end_date=today - timedelta(days=18),
                reason="Personal matters and family visit.",
                status='approved',
                reviewed_by=users['coordinator'],
                reviewed_at=timezone.now() - timedelta(days=21),
                notes="Approved for family matters."
            )
            
            # Scenario 2: Pending Leave (Future)
            LeaveRequest.objects.create(
                user=user,
                leave_type=random.choice(leave_types),
                start_date=today + timedelta(days=5),
                end_date=today + timedelta(days=6),
                reason="Medical checkup appointment.",
                status='pending'
            )
            
            # Scenario 3: Rejected Leave (Past)
            LeaveRequest.objects.create(
                user=user,
                leave_type=random.choice(leave_types),
                start_date=today - timedelta(days=40),
                end_date=today - timedelta(days=39),
                reason="General vacation.",
                status='rejected',
                reviewed_by=users['coordinator'],
                reviewed_at=timezone.now() - timedelta(days=45),
                notes="Peak season, please reschedule."
            )
            
            self.stdout.write(f'Created leave requests for {user.username}')

        # 4. Populate Payment Slips
        self.stdout.write('\nGenerating payment slips for January and February 2026...')
        for role_name in staff_roles:
            user = users[role_name]
            # Delete old mock slips
            PaymentSlip.objects.filter(user=user, year=2026, month__in=[1, 2]).delete()
            
            # Jan 2026 - Paid
            slip_jan = PaymentSlip.generate_for_user(user, month=1, year=2026, generated_by=users['coordinator'])
            if slip_jan:
                slip_jan.status = 'paid'
                slip_jan.is_uploaded = True
                slip_jan.paid_at = timezone.now() - timedelta(days=14)
                slip_jan.save()
                self.stdout.write(f'Generated PAID slip for {user.username} (Jan 2026)')
            
            # Feb 2026 - Generated (Pending)
            slip_feb = PaymentSlip.generate_for_user(user, month=2, year=2026, generated_by=users['coordinator'])
            if slip_feb:
                slip_feb.status = 'generated'
                slip_feb.is_uploaded = True
                slip_feb.save()
                self.stdout.write(f'Generated PENDING slip for {user.username} (Feb 2026)')

        # 5. Populate Removal Requests (Demo for HR and Admin)
        self.stdout.write('\nGenerating removal requests...')
        hr_user = users['coordinator'] # Coordinator acts as HR for this demo
        
        # Scenario 1: Pending Removal (Current)
        user_to_remove = users['field_officer']
        EmployeeRemovalRequest.objects.filter(user=user_to_remove).delete()
        EmployeeRemovalRequest.objects.create(
            user=user_to_remove,
            requested_by=hr_user,
            reason="Performance issues and consistent absence without notice.",
            status='pending'
        )
        self.stdout.write(f'Created PENDING removal request for {user_to_remove.username}')

        # Scenario 2: Approved Removal (History)
        # Create a temp user to show approved history
        temp_user, _ = User.objects.get_or_create(username='former_employee', defaults={'email': 'former@example.com'})
        EmployeeRemovalRequest.objects.filter(user=temp_user).delete()
        req_approved = EmployeeRemovalRequest.objects.create(
            user=temp_user,
            requested_by=hr_user,
            reason="Resignation submitted and notice period completed.",
            status='approved',
            reviewed_by=User.objects.filter(is_superuser=True).first(),
            reviewed_at=timezone.now() - timedelta(days=5),
            admin_notes="Approved. Revoke all system access immediately."
        )
        self.stdout.write(f'Created APPROVED removal request for {temp_user.username}')

        # Scenario 3: Rejected Removal
        user_rejected = users['accessor']
        EmployeeRemovalRequest.objects.filter(user=user_rejected).delete()
        EmployeeRemovalRequest.objects.create(
            user=user_rejected,
            requested_by=hr_user,
            reason="Temporary suspension request during investigation.",
            status='rejected',
            reviewed_by=User.objects.filter(is_superuser=True).first(),
            reviewed_at=timezone.now() - timedelta(days=2),
            admin_notes="Rejection: Suspension is not grounds for account removal. Use role modification instead."
        )
        self.stdout.write(f'Created REJECTED removal request for {user_rejected.username}')

        # 6. Define Scenarios for Projects
        self.stdout.write('\nGenerating project scenarios...')
        scenarios = [
            {
                'title': 'Commercial Complex Valuation - Colombo 03',
                'description': 'Valuation of a 5-story commercial building and land in Colombo 03 for mortgage purposes.',
                'status': 'completed',
                'priority': 'high',
                'history': [
                    ('pending', 'Project created', users['coordinator'], -10),
                    ('pending', 'Client assigned: Mock Client', users['coordinator'], -9),
                    ('pending', 'Field Officer assigned: Mock Field Officer', users['coordinator'], -8),
                    ('pending', 'Accessor assigned: Mock Accessor', users['coordinator'], -7),
                    ('pending', 'Senior Valuer assigned: Mock Senior Valuer', users['coordinator'], -6),
                    ('in_progress', 'Project started and assigned to Field Officer', users['coordinator'], -5),
                    ('in_progress', 'Valuation report submitted by Field Officer', users['field_officer'], -4),
                    ('in_progress', 'Valuation (Building) accepted by Accessor and sent to Senior Valuer for approval.', users['accessor'], -3),
                    ('in_progress', 'Valuation (Land) accepted by Accessor and sent to Senior Valuer for approval.', users['accessor'], -3),
                    ('completed', 'Valuation (Building) approved by Senior Valuer.', users['senior_valuer'], -1),
                    ('completed', 'Valuation (Land) approved by Senior Valuer.', users['senior_valuer'], -1),
                ],
                'valuations': [
                    ('building', 'approved', 'Excellent structure, well maintained.', 45000000),
                    ('land', 'approved', 'Prime location in Colombo 03.', 120000000),
                ]
            },
            {
                'title': 'Residential Property - Kandy',
                'description': 'Valuation of a residential house and property in Kandy.',
                'status': 'in_progress',
                'priority': 'medium',
                'history': [
                    ('pending', 'Project created', users['coordinator'], -5),
                    ('pending', 'Client assigned: Mock Client', users['coordinator'], -4),
                    ('in_progress', 'Project started', users['coordinator'], -3),
                    ('in_progress', 'Valuation report submitted by Field Officer', users['field_officer'], -2),
                ],
                'valuations': [
                    ('building', 'submitted', 'Standard residential building.', 15000000),
                ]
            },
            {
                'title': 'Vehicle Valuation - Toyota Prius',
                'description': 'Market value assessment of a Toyota Prius 2018 model.',
                'status': 'in_progress',
                'priority': 'low',
                'history': [
                    ('pending', 'Project created', users['coordinator'], -2),
                    ('in_progress', 'Project started', users['coordinator'], -1),
                    ('in_progress', 'Valuation (Vehicle) rejected by Senior Valuer. Reason: Photos are unclear.', users['senior_valuer'], 0),
                ],
                'valuations': [
                    ('vehicle', 'rejected', 'Vehicle in good condition.', 8500000, 'Photos are unclear.'),
                ]
            }
        ]

        # 7. Populate Client Submissions (Leads)
        self.stdout.write('\nGenerating mock client submissions...')
        client_leads = [
            {
                'first_name': 'John', 'last_name': 'Doe', 'email': 'john.doe@enterprise.com',
                'phone': '0771234567', 'nic': '199012345678', 'company_name': 'Enterprise Ltd',
                'project_title': 'Office Complex Valuation', 
                'project_description': 'Full valuation for mortgage of our new HQ.',
                'agent_name': 'Self', 'agent_phone': '0771234567', 'agent_email': 'john.doe@enterprise.com',
                'status': 'pending'
            },
            {
                'first_name': 'Sarah', 'last_name': 'Connor', 'email': 's.connor@sky.net',
                'phone': '0777654321', 'nic': '198598765432', 'company_name': 'SkyNet Solutions',
                'project_title': 'Factory Land Assessment',
                'project_description': 'Assessing land value for expansion.',
                'agent_name': 'Reese Agents', 'agent_phone': '0712345678', 'agent_email': 'reese@agents.com',
                'status': 'approved', 'reviewed_by': User.objects.filter(is_superuser=True).first(),
                'reviewed_at': timezone.now() - timedelta(days=2), 'notes': 'Valid request, project created.'
            },
            {
                'first_name': 'James', 'last_name': 'Bond', 'email': '007@mi6.gov.uk',
                'phone': '0700070007', 'nic': '197000000007', 'company_name': 'MI6',
                'project_title': 'Safe House Evaluation',
                'project_description': 'Confidential valuation of overseas property.',
                'agent_name': 'Q Branch', 'agent_phone': '0700000001', 'agent_email': 'q@mi6.gov.uk',
                'status': 'rejected', 'reviewed_by': User.objects.filter(is_superuser=True).first(),
                'reviewed_at': timezone.now() - timedelta(days=1), 'notes': 'Out of scope for this region.'
            }
        ]

        for lead in client_leads:
            ClientFormSubmission.objects.update_or_create(
                email=lead['email'],
                project_title=lead['project_title'],
                defaults=lead
            )
        self.stdout.write(f'Populated {len(client_leads)} client leads.')

        # 8. Populate Employee Submissions (Agent Leads)
        self.stdout.write('\nGenerating mock employee submissions...')
        employee_leads = [
            {
                'first_name': 'Arthur', 'last_name': 'Dent', 'email': 'a.dent@hitchhiker.com',
                'address': 'Earth (Destroyed)', 'phone': '4242424242', 'birthday': '1980-01-01',
                'nic': '198042424242', 'status': 'pending'
            },
            {
                'first_name': 'Ford', 'last_name': 'Prefect', 'email': 'f.prefect@betelgeuse.com',
                'address': 'Richmond, London', 'phone': '0711111111', 'birthday': '1975-05-25',
                'nic': '197511111111', 'status': 'approved', 
                'reviewed_by': User.objects.filter(is_superuser=True).first(),
                'reviewed_at': timezone.now() - timedelta(days=3), 'notes': 'Experienced traveler, hiring as remote agent.'
            }
        ]

        for lead in employee_leads:
            EmployeeFormSubmission.objects.update_or_create(
                email=lead['email'],
                defaults=lead
            )
        self.stdout.write(f'Populated {len(employee_leads)} employee leads.')

        # 9. Create Projects and History
        for s in scenarios:
            # Check if project already exists to avoid duplicates if run multiple times
            if Project.objects.filter(title=s['title']).exists():
                continue
                
            project = Project.objects.create(
                title=s['title'],
                description=s['description'],
                status=s['status'],
                priority=s['priority'],
                coordinator=users['coordinator'],
                assigned_field_officer=users['field_officer'],
                assigned_client=users['client'],
                assigned_accessor=users['accessor'],
                assigned_senior_valuer=users['senior_valuer'],
            )

            # Manually set history entries with adjusted timestamps
            now = timezone.now()
            for status, notes, user, days_ago in s['history']:
                hist = ProjectStatusHistory.objects.create(
                    project=project,
                    status=status,
                    notes=notes,
                    created_by=user
                )
                # Overwrite auto_now_add timestamp
                hist.created_at = now + timedelta(days=days_ago)
                hist.save()

            # Create Valuations
            for category, status, notes, estimated_value, *rejection in s.get('valuations', []):
                rej_reason = rejection[0] if rejection else ''
                Valuation.objects.create(
                    project=project,
                    field_officer=users['field_officer'],
                    category=category,
                    status=status,
                    notes=notes,
                    estimated_value=estimated_value,
                    rejection_reason=rej_reason,
                    senior_valuer_comments="Verified by mock senior valuer." if status == 'approved' else ""
                )

            self.stdout.write(self.style.SUCCESS(f'Created project: {project.title}'))

        self.stdout.write(self.style.SUCCESS('\nMock data population complete!'))
