# Received Projects Tab - Features Implemented

This document lists **only the features implemented in the Received Projects Tab** (pending projects).

---

## 📋 Table of Contents

1. [Received Tab Structure](#1-received-tab-structure)
2. [Start Project Button with Validation](#2-start-project-button-with-validation)
3. [Cancel Project Button](#3-cancel-project-button)
4. [Assign Users Button](#4-assign-users-button)
5. [Search and Sort Functionality](#5-search-and-sort-functionality)
6. [Project Card Display](#6-project-card-display)

---

## 📍 Quick Reference - Code Locations

| Feature | Component | File | Lines | Description |
|---------|-----------|------|-------|-------------|
| **Tab Definition** | Received Tab | `coordinator_dashboard.dart` | 6204, 6222-6228 | Tab definition and project filtering |
| **Start Button** | Start Project | `coordinator_dashboard.dart` | 6597-6614 | Start button with validation |
| **Cancel Button** | Cancel Project | `coordinator_dashboard.dart` | 6608-6610 | Cancel button for pending projects |
| **Assign Users Button** | Assign Users | `coordinator_dashboard.dart` | 6665-6691 | Assign users button |
| **Validation Method** | Start Validation | `coordinator_dashboard.dart` | 1333-1356 | Validates all required users |
| **Start Project Method** | Start Logic | `coordinator_dashboard.dart` | 1358-1422 | Handles validation and project start |
| **Search & Sort** | Search/Sort Bar | `coordinator_dashboard.dart` | 6256-6339 | Search and sort functionality |

---

## 1. Received Tab Structure

### Description
The Received tab displays all projects with "pending" status. Projects appear here when first created and remain until they are started (moved to Ongoing) or cancelled.

### Implementation

**File:** `auditra/lib/screens/coordinator_dashboard.dart`  
**Lines:** 6158-6228

```dart
6158|  Widget _buildProjectsTab() {
6159|    // Filter projects by status
6160|    // Use case-insensitive comparison to handle any potential case variations
6161|    final pendingProjects = _projects.where((p) => p.status.toLowerCase() == 'pending').toList();
6162|    final ongoingProjects = _projects.where((p) => p.status.toLowerCase() == 'in_progress').toList();
6163|    final completedProjects = _projects.where((p) => p.status.toLowerCase() == 'completed').toList();
6164|    final cancelledProjects = _projects.where((p) => p.status.toLowerCase() == 'cancelled').toList();
6165|    
6166|    // Initialize search controllers for each tab if not exists
6167|    for (int i = 0; i < 4; i++) {
6168|      if (!_searchControllers.containsKey(i)) {
6169|        _searchControllers[i] = TextEditingController();
6170|        _searchControllers[i]!.addListener(() => setState(() {}));
6171|      }
6172|    }
6173|
6174|    return Column(
6175|      children: [
6176|        // Create Project Button
6177|        Container(
6178|          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
6179|          decoration: BoxDecoration(
6180|            color: Colors.white,
6181|            boxShadow: [
6182|              BoxShadow(
6183|                color: Colors.grey[200]!,
6184|                blurRadius: 4,
6185|                offset: const Offset(0, 2),
6186|              ),
6187|            ],
6188|          ),
6189|          child: _buildCreateProjectButton(),
6190|        ),
6191|        // Project Subtabs
6192|        Container(
6193|          color: Colors.white,
6194|          child: _projectSubTabController != null && _projectSubTabController!.length == 4
6195|              ? TabBar(
6196|                  controller: _projectSubTabController,
6197|                  labelColor: Colors.blue[700],
6198|                  unselectedLabelColor: Colors.grey[600],
6199|                  indicatorColor: Colors.blue[700],
6200|                  indicatorWeight: 3,
6201|                  isScrollable: false,
6202|                  tabAlignment: TabAlignment.fill,
6203|                  tabs: const [
6204|                    Tab(text: 'Received'),
6205|                    Tab(text: 'Ongoing'),
6206|                    Tab(text: 'Completed'),
6207|                    Tab(text: 'Cancelled'),
6208|                  ],
6209|                )
6210|              : const SizedBox(height: 48),
6211|        ),
6212|        // Projects List with Subtabs
6213|        Expanded(
6214|          child: RefreshIndicator(
6215|            onRefresh: _loadProjects,
6216|            child: _isLoadingProjects || _projectSubTabController == null || _projectSubTabController!.length != 4
6217|                ? const Center(child: CircularProgressIndicator())
6218|                : TabBarView(
6219|                    controller: _projectSubTabController,
6220|                    physics: const AlwaysScrollableScrollPhysics(),
6221|                    children: [
6222|                      _buildProjectListWithSearch(
6223|                        _filterAndSortProjects(pendingProjects, 0),
6224|                        'No received projects',
6225|                        'Newly received projects will appear here',
6226|                        isReceivedTab: true,
6227|                        tabIndex: 0,
6228|                      ),
```

**What it does:**
- Filters projects by status: `pending` projects go to Received tab
- Creates the "Received" tab in the TabBar
- Displays filtered pending projects in the TabBarView
- Sets `isReceivedTab: true` flag for special styling
- Shows empty state message when no received projects

---

## 2. Start Project Button with Validation

### Description
The Start button appears only in the Received tab for pending projects. Before allowing the project to move to Ongoing, it validates that all required users (Field Officer, Client, Agent if needed, Accessor, Senior Valuer) are assigned. If any are missing, it shows an error message listing all missing roles.

### Implementation

**File:** `auditra/lib/screens/coordinator_dashboard.dart`

#### 2.1 Validation Method (Lines 1333-1356)

```dart
1333|  // Helper method to check if all required users are assigned
1334|  bool _canStartProject(Project project) {
1335|    // Field officer and client are always required
1336|    if (project.assignedFieldOfficerName == null || project.assignedClientName == null) {
1337|      return false;
1338|    }
1339|    
1340|    // Agent is required only if hasAgent is true
1341|    if (project.hasAgent && project.assignedAgentName == null) {
1342|      return false;
1343|    }
1344|    
1345|    // Accessor is required
1346|    if (project.assignedAccessorName == null) {
1347|      return false;
1348|    }
1349|    
1350|    // Senior Valuer is required
1351|    if (project.assignedSeniorValuerName == null) {
1352|      return false;
1353|    }
1354|    
1355|    return true;
1356|  }
```

**What it validates:**
- ✅ Field Officer must be assigned
- ✅ Client must be assigned
- ✅ Agent must be assigned (if `hasAgent` is true)
- ✅ Accessor must be assigned
- ✅ Senior Valuer must be assigned

---

#### 2.2 Start Project Method (Lines 1358-1422)

```dart
1358|  Future<void> _startProject(Project project) async {
1359|    // Check if all required users are assigned
1360|    if (!_canStartProject(project)) {
1361|      // Work out which user types are missing
1362|      final List<String> missing = [];

1364|      if (project.assignedFieldOfficerName == null) {
1365|        missing.add('Field Officer');
1366|      }
1367|      if (project.assignedClientName == null) {
1368|        missing.add('Client');
1369|      }
1370|      if (project.hasAgent && project.assignedAgentName == null) {
1371|        missing.add('Agent');
1372|      }
1373|      if (project.assignedAccessorName == null) {
1374|        missing.add('Accessor');
1375|      }
1376|      if (project.assignedSeniorValuerName == null) {
1377|        missing.add('Senior Valuer');
1378|      }

1380|      String message;
1381|      if (missing.length == 1) {
1382|        // Single missing type – show specific message
1383|        message = 'Please assign ${missing.first} before starting this project.';
1384|      } else {
1385|        // Multiple missing types – show all missing roles
1386|        message = 'Please assign all required users before starting this project. Missing roles: ${missing.join(', ')}';
1387|      }

1389|      ScaffoldMessenger.of(context).showSnackBar(
1390|        SnackBar(
1391|          content: Text(message),
1392|          backgroundColor: Colors.orange,
1393|          duration: const Duration(seconds: 4),
1394|        ),
1395|      );
1396|      return;
1397|    }

1399|    final result = await ApiService.updateProjectStatus(
1400|      projectId: project.id,
1401|      status: 'in_progress',
1402|    );

1404|    if (mounted) {
1405|      if (result['success']) {
1406|        ScaffoldMessenger.of(context).showSnackBar(
1407|          const SnackBar(
1408|            content: Text('Project started successfully!'),
1409|            backgroundColor: Colors.green,
1410|          ),
1411|        );
1412|        await _loadProjects();
1413|      } else {
1414|        ScaffoldMessenger.of(context).showSnackBar(
1415|          SnackBar(
1416|            content: Text(result['message'] ?? 'Failed to start project'),
1417|            backgroundColor: Colors.red,
1418|          ),
1419|        );
1420|      }
1421|    }
1422|  }
```

**What it does:**
- Validates all required users are assigned
- Collects missing roles into a list
- Shows specific error message for single missing role
- Shows comprehensive error message listing all missing roles for multiple missing roles
- Only proceeds to start project if validation passes
- Updates project status to 'in_progress' via API
- Shows success message and refreshes project list
- Project automatically moves from Received tab to Ongoing tab

---

#### 2.3 Start Button UI (Lines 6597-6614)

```dart
6597|                      // Cancel and Start buttons (for pending projects)
6598|                      if (isPending) ...[
6599|                        if (project.description != null)
6600|                          const SizedBox(width: 8),
6601|                        Row(
6602|                          mainAxisSize: MainAxisSize.min,
6603|                          children: [
6604|                            _HoverableStartButton(
6605|                              canStart: _canStartProject(project),
6606|                              onPressed: () => _startProject(project),
6607|                            ),
6608|                            const SizedBox(width: 4),
6609|                            _HoverableCancelButton(
6610|                              onPressed: () => _cancelProject(project),
6611|                            ),
6612|                          ],
6613|                        ),
6614|                      ],
```

**What it does:**
- Shows Start button only for pending projects (`isPending`)
- Button calls `_startProject()` which includes validation
- Button is positioned next to Cancel button
- Uses `_HoverableStartButton` widget for hover effects

---

### Error Messages

**Single Missing Role:**
```
"Please assign [Role Name] before starting this project."
```

**Example:**
```
"Please assign Accessor before starting this project."
```

---

**Multiple Missing Roles:**
```
"Please assign all required users before starting this project. Missing roles: [Role1, Role2, ...]"
```

**Example:**
```
"Please assign all required users before starting this project. Missing roles: Accessor, Senior Valuer"
```

---

### User Flow

1. Coordinator views projects in "Received" tab
2. Coordinator clicks "Start" button on a pending project
3. System validates all required users are assigned:
   - ✅ **If all assigned** → Project status changes to "in_progress" → Moves to "Ongoing" tab → Success message shown
   - ❌ **If any missing** → Error message shows with list of missing roles → Project stays in "Received" tab

---

## 3. Cancel Project Button

### Description
The Cancel button allows coordinators to cancel pending projects directly from the Received tab. This moves the project to the Cancelled tab.

### Implementation

**File:** `auditra/lib/screens/coordinator_dashboard.dart`

#### 3.1 Cancel Button UI (Lines 6608-6610)

```dart
6608|                            _HoverableCancelButton(
6609|                              onPressed: () => _cancelProject(project),
6610|                            ),
```

**What it does:**
- Shows Cancel button next to Start button for pending projects
- Calls `_cancelProject()` method on click
- Uses `_HoverableCancelButton` widget for hover effects

---

#### 3.2 Cancel Project Method (Lines 1424-1582)

```dart
1424|  Future<void> _cancelProject(Project project) async {
1425|    final confirm = await showDialog<bool>(
1426|      context: context,
1427|      barrierDismissible: false,
1428|      builder: (context) => Dialog(
1429|        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
1430|        child: Container(
1431|          width: MediaQuery.of(context).size.width * 0.85,
1432|          constraints: const BoxConstraints(maxHeight: 400),
1433|          child: Column(
1434|            mainAxisSize: MainAxisSize.min,
1435|            children: [
1436|              // Header with gradient
1437|              Container(
1438|                padding: const EdgeInsets.all(20),
1439|                decoration: BoxDecoration(
1440|                  color: Colors.red[500]!,
1441|                  borderRadius: const BorderRadius.only(
1442|                    topLeft: Radius.circular(20),
1443|                    topRight: Radius.circular(20),
1444|                  ),
1445|                ),
1446|                child: Row(
1447|                  children: [
1448|                    Container(
1449|                      padding: const EdgeInsets.all(12),
1450|                      decoration: BoxDecoration(
1451|                              color: Colors.red[400]!,
1452|                        borderRadius: BorderRadius.circular(12),
1453|                      ),
1454|                      child: const Icon(Icons.cancel_outlined, color: Colors.white, size: 24),
1455|                    ),
1456|                    const SizedBox(width: 16),
1457|                    const Expanded(
1458|                      child: Text(
1459|                        'Cancel Project',
1460|                        style: TextStyle(
1461|                          color: Colors.white,
1462|                          fontSize: 24,
1463|                          fontWeight: FontWeight.bold,
1464|                        ),
1465|                      ),
1466|                    ),
1467|                  ],
1468|                ),
1469|              ),
1470|              // Content
1471|              Padding(
1472|                padding: const EdgeInsets.all(24),
1473|                child: Column(
1474|                  children: [
1475|                    Icon(
1476|                      Icons.warning_amber_rounded,
1477|                      size: 64,
1478|                      color: Colors.red[300],
1479|                    ),
1480|                    const SizedBox(height: 16),
1481|                    const Text(
1482|                      'Are you sure?',
1483|                      style: TextStyle(
1484|                        fontSize: 20,
1485|                        fontWeight: FontWeight.bold,
1486|                      ),
1487|                    ),
1488|                    const SizedBox(height: 12),
1489|                    Text(
1490|                      'You are about to cancel "${project.title}". This action will mark the project as cancelled.',
1491|                      textAlign: TextAlign.center,
1492|                      style: TextStyle(
1493|                        fontSize: 14,
1494|                        color: Colors.grey[700],
1495|                        height: 1.5,
1496|                      ),
1497|                    ),
1498|                  ],
1499|                ),
1500|              ),
1501|              // Action Buttons
1502|              Container(
1503|                padding: const EdgeInsets.all(20),
1504|                decoration: BoxDecoration(
1505|                  color: Colors.grey[50],
1506|                  borderRadius: const BorderRadius.only(
1507|                    bottomLeft: Radius.circular(20),
1508|                    bottomRight: Radius.circular(20),
1509|                  ),
1510|                ),
1511|                child: Row(
1512|                  children: [
1513|                    Expanded(
1514|                      child: OutlinedButton(
1515|                        onPressed: () => Navigator.of(context).pop(false),
1516|                        style: OutlinedButton.styleFrom(
1517|                          padding: const EdgeInsets.symmetric(vertical: 16),
1518|                          shape: RoundedRectangleBorder(
1519|                            borderRadius: BorderRadius.circular(12),
1520|                          ),
1521|                        ),
1522|                        child: const Text('No, Keep It', style: TextStyle(fontSize: 16)),
1523|                      ),
1524|                    ),
1525|                    const SizedBox(width: 12),
1526|                    Expanded(
1527|                      child: ElevatedButton(
1528|                        onPressed: () => Navigator.of(context).pop(true),
1529|                        style: ElevatedButton.styleFrom(
1530|                          backgroundColor: Colors.red[600],
1531|                          foregroundColor: Colors.white,
1532|                          padding: const EdgeInsets.symmetric(vertical: 16),
1533|                          shape: RoundedRectangleBorder(
1534|                            borderRadius: BorderRadius.circular(12),
1535|                          ),
1536|                          elevation: 2,
1537|                        ),
1538|                        child: const Row(
1539|                          mainAxisAlignment: MainAxisAlignment.center,
1540|                          children: [
1541|                            Icon(Icons.cancel, size: 20),
1542|                            SizedBox(width: 8),
1543|                            Text('Cancel Project', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
1544|                          ],
1545|                        ),
1546|                      ),
1547|                    ),
1548|                  ],
1549|                ),
1550|              ),
1551|            ],
1552|          ),
1553|        ),
1554|      ),
1555|    );

1557|    if (confirm != true) return;

1559|    final result = await ApiService.updateProjectStatus(
1560|      projectId: project.id,
1561|      status: 'cancelled',
1562|    );

1564|    if (mounted) {
1565|      if (result['success']) {
1566|        ScaffoldMessenger.of(context).showSnackBar(
1567|          const SnackBar(
1568|            content: Text('Project cancelled successfully!'),
1569|            backgroundColor: Colors.green,
1570|          ),
1571|        );
1572|        await _loadProjects();
1573|      } else {
1574|        ScaffoldMessenger.of(context).showSnackBar(
1575|          SnackBar(
1576|            content: Text(result['message'] ?? 'Failed to cancel project'),
1577|            backgroundColor: Colors.red,
1578|          ),
1579|        );
1580|      }
1581|    }
1582|  }
```

**What it does:**
- Shows confirmation dialog before cancelling
- Displays warning message with project title
- Updates project status to 'cancelled' via API
- Shows success/error messages
- Refreshes project list after cancellation
- Project automatically moves from Received tab to Cancelled tab

---

## 4. Assign Users Button

### Description
The "Assign Users" button appears only for pending projects in the Received tab. It opens a dialog where coordinators can assign Field Officer, Client, Agent (if applicable), Accessor, and Senior Valuer to the project.

### Implementation

**File:** `auditra/lib/screens/coordinator_dashboard.dart`

#### 4.1 Assign Users Button UI (Lines 6665-6691)

```dart
6665|            // Assign Users button (for pending projects)
6666|            if (isPending) ...[
6667|              SizedBox(height: isReceivedTab ? 4 : 8),
6668|              SizedBox(
6669|                width: double.infinity,
6670|                child: ElevatedButton.icon(
6671|                  onPressed: () => _showAssignUsersDialog(project),
6672|                  icon: const Icon(Icons.person_add, size: 18),
6673|                  label: const Text(
6674|                    'Assign Users',
6675|                    style: TextStyle(
6676|                      fontSize: 14,
6677|                      fontWeight: FontWeight.w600,
6678|                    ),
6679|                  ),
6680|                  style: ElevatedButton.styleFrom(
6681|                    backgroundColor: Colors.cyan[600],
6682|                    foregroundColor: Colors.white,
6683|                    padding: const EdgeInsets.symmetric(vertical: 12),
6684|                    shape: RoundedRectangleBorder(
6685|                      borderRadius: BorderRadius.circular(8),
6686|                    ),
6687|                    elevation: 2,
6688|                  ),
6689|                ),
6690|              ),
6691|            ],
```

**What it does:**
- Shows "Assign Users" button only for pending projects (`isPending`)
- Full-width button with cyan color theme
- Calls `_showAssignUsersDialog()` method on click
- Uses person_add icon

---

#### 4.2 Assign Users Dialog

The assign users dialog includes tabs for:
- Field Officer
- Client
- Agent (if project has agent)
- **Accessor** (added feature)
- **Senior Valuer** (added feature)

After closing the dialog, the system validates all users and shows feedback messages.

**Validation After Dialog Close** (Lines 3212-3260):

```dart
3212|    // Check assigned users after dialog closes
3213|    if (mounted) {
3214|      // Get updated project
3215|      final updatedProject = _projects.firstWhere(
3216|        (p) => p.id == project.id,
3217|        orElse: () => project,
3218|      );
3219|      
3220|      // Check all users (including Senior Valuer and Accessor)
3221|      final List<String> allMissingRoles = [];
3222|      
3223|      if (updatedProject.assignedFieldOfficerName == null) {
3224|        allMissingRoles.add('Field Officer');
3225|      }
3226|      if (updatedProject.assignedClientName == null) {
3227|        allMissingRoles.add('Client');
3228|      }
3229|      if (updatedProject.hasAgent && updatedProject.assignedAgentName == null) {
3230|        allMissingRoles.add('Agent');
3231|      }
3232|      if (updatedProject.assignedAccessorName == null) {
3233|        allMissingRoles.add('Accessor');
3234|      }
3235|      if (updatedProject.assignedSeniorValuerName == null) {
3236|        allMissingRoles.add('Senior Valuer');
3237|      }
3238|      
3239|      // Show appropriate message
3240|      if (allMissingRoles.isEmpty) {
3241|        // All users assigned (including Senior Valuer and Accessor) - show success
3242|        ScaffoldMessenger.of(context).showSnackBar(
3243|          const SnackBar(
3244|            content: Text('All relevant users have been assigned successfully!'),
3245|            backgroundColor: Colors.green,
3246|            duration: Duration(seconds: 3),
3247|          ),
3248|        );
3249|      } else {
3250|        // Some users missing - show all missing roles
3251|        final missingText = allMissingRoles.length == 1
3252|            ? 'Missing user role: ${allMissingRoles.first}'
3253|            : 'Missing user roles: ${allMissingRoles.join(', ')}';
3254|        
3255|        ScaffoldMessenger.of(context).showSnackBar(
3256|          SnackBar(
3257|            content: Text(missingText),
3258|            backgroundColor: Colors.orange,
3259|            duration: const Duration(seconds: 4),
3260|          ),
3261|        );
3262|      }
3263|    }
```

**What it does:**
- After assignment dialog closes, checks all 5 required roles
- Shows success message if all users are assigned
- Shows warning message listing missing roles if any are missing
- Guides coordinator to complete assignments

---

## 5. Search and Sort Functionality

### Description
The Received tab includes search and sort functionality to help coordinators find and organize pending projects.

### Implementation

**File:** `auditra/lib/screens/coordinator_dashboard.dart`

#### 5.1 Search and Sort Bar (Lines 6256-6339)

```dart
6256|  Widget _buildProjectListWithSearch(List<Project> projects, String emptyTitle, String emptySubtitle, {bool isReceivedTab = false, bool isCancelledTab = false, required int tabIndex}) {
6257|    return Column(
6258|      children: [
6259|        // Search and Sort Bar
6260|        Container(
6261|          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
6262|          color: Colors.white,
6263|          child: Row(
6264|            children: [
6265|              // Search field
6266|              Expanded(
6267|                child: TextField(
6268|                  controller: _searchControllers[tabIndex],
6269|                  decoration: InputDecoration(
6270|                    hintText: 'Search projects...',
6271|                    prefixIcon: const Icon(Icons.search, size: 20),
6272|                    suffixIcon: _searchControllers[tabIndex]?.text.isNotEmpty == true
6273|                        ? IconButton(
6274|                            icon: const Icon(Icons.clear, size: 18),
6275|                            onPressed: () {
6276|                              _searchControllers[tabIndex]?.clear();
6277|                            },
6278|                          )
6278|                        : null,
6279|                    filled: true,
6280|                    fillColor: Colors.grey[100],
6281|                    border: OutlineInputBorder(
6282|                      borderRadius: BorderRadius.circular(8),
6283|                      borderSide: BorderSide.none,
6284|                    ),
6285|                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
6286|                    isDense: true,
6287|                  ),
6288|                ),
6289|              ),
6290|              const SizedBox(width: 8),
6291|              // Sort dropdown
6292|              Container(
6293|                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
6294|                decoration: BoxDecoration(
6295|                  color: Colors.blue[50],
6296|                  borderRadius: BorderRadius.circular(10),
6297|                  border: Border.all(color: Colors.blue[200]!, width: 1.5),
6298|                  boxShadow: [
6299|                    BoxShadow(
6300|                      color: Colors.grey[200]!,
6301|                      blurRadius: 4,
6302|                      offset: const Offset(0, 2),
6303|                    ),
6304|                  ],
6305|                ),
6306|                child: Row(
6307|                  mainAxisSize: MainAxisSize.min,
6308|                  children: [
6309|                    Icon(Icons.sort, size: 20, color: Colors.blue[700]),
6310|                    const SizedBox(width: 6),
6311|                    DropdownButton<String>(
6312|                      value: _sortOptions[tabIndex] ?? 'date_asc',
6313|                      underline: const SizedBox(),
6314|                      icon: Icon(Icons.arrow_drop_down, size: 22, color: Colors.blue[700]),
6315|                      isDense: false,
6316|                      style: TextStyle(
6317|                        fontSize: 14,
6318|                        fontWeight: FontWeight.w600,
6319|                        color: Colors.blue[900],
6320|                      ),
6321|                      items: const [
6322|                        DropdownMenuItem(
6323|                          value: 'date_asc',
6324|                          child: Text('Date ↑', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
6325|                        ),
6326|                        DropdownMenuItem(
6327|                          value: 'date_desc',
6328|                          child: Text('Date ↓', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
6329|                        ),
6329|                        DropdownMenuItem(
6330|                          value: 'title_asc',
6331|                          child: Text('Title A-Z', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
6332|                        ),
6333|                        DropdownMenuItem(
6334|                          value: 'title_desc',
6335|                          child: Text('Title Z-A', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
6336|                        ),
6337|                        DropdownMenuItem(
6338|                          value: 'priority',
6339|                          child: Text('Priority', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
6340|                        ),
6341|                      ],
6342|                      onChanged: (value) {
6343|                        setState(() {
6344|                          _sortOptions[tabIndex] = value!;
6345|                        });
6346|                      },
6347|                    ),
6348|                  ],
6349|                ),
6350|              ),
6351|            ],
6352|          ),
6353|        ),
```

**What it does:**
- Provides search field to filter projects by title
- Clear button appears when text is entered
- Sort dropdown with options:
  - Date ↑ (Oldest first)
  - Date ↓ (Newest first)
  - Title A-Z
  - Title Z-A
  - Priority (High → Medium → Low)
- Each tab has its own search controller and sort option

---

#### 5.2 Filter and Sort Logic (Lines 6105-6156)

```dart
6105|  List<Project> _filterAndSortProjects(List<Project> projects, int tabIndex) {
6106|    String? searchQuery = _searchControllers[tabIndex]?.text.toLowerCase();
6107|    String? sortOption = _sortOptions[tabIndex] ?? 'date_asc';
6108|    
6109|    // Filter
6110|    var filtered = projects.where((project) {
6111|      if (searchQuery != null && searchQuery.isNotEmpty) {
6112|        return project.title.toLowerCase().contains(searchQuery);
6113|      }
6114|      return true;
6115|    }).toList();
6116|    
6117|    // Sort
6118|    filtered.sort((a, b) {
6119|      switch (sortOption) {
6120|        case 'date_desc':
6121|          return b.createdAt.compareTo(a.createdAt);
6122|        case 'title_asc':
6123|          return a.title.compareTo(b.title);
6124|        case 'title_desc':
6125|          return b.title.compareTo(a.title);
6126|        case 'priority':
6127|          final priorityOrder = {'high': 3, 'medium': 2, 'low': 1};
6128|          final aPriority = priorityOrder[a.priority?.toLowerCase() ?? 'medium'] ?? 2;
6129|          final bPriority = priorityOrder[b.priority?.toLowerCase() ?? 'medium'] ?? 2;
6130|          if (aPriority != bPriority) return bPriority.compareTo(aPriority);
6131|          return a.createdAt.compareTo(b.createdAt);
6132|        case 'date_asc':
6133|        default:
6134|          return a.createdAt.compareTo(b.createdAt);
6135|      }
6136|    });
6137|    
6138|    return filtered;
6139|  }
```

**What it does:**
- Filters projects by title (case-insensitive search)
- Sorts projects based on selected option
- Maintains separate search/sort state for each tab

---

## 6. Project Card Display

### Description
Projects in the Received tab are displayed as cards with specific styling and features unique to pending projects.

### Implementation

**File:** `auditra/lib/screens/coordinator_dashboard.dart`

#### 6.1 Project Card (Lines 6424-6691)

```dart
6424|  Widget _buildProjectCard(Project project, {bool isReceivedTab = false, bool isCancelledTab = false}) {
6425|    final isPending = project.status.toLowerCase() == 'pending';
6426|    final isOngoing = project.status.toLowerCase() == 'in_progress';
6427|    final priority = project.priority ?? 'medium';
6428|
6429|    return Stack(
6430|      clipBehavior: Clip.none,
6431|      children: [
6432|        Container(
6433|          margin: EdgeInsets.only(bottom: isReceivedTab ? 4 : 10),
6434|          decoration: BoxDecoration(
6435|            color: Colors.white,
6436|            borderRadius: BorderRadius.circular(16),
6437|            boxShadow: [
6438|              BoxShadow(
6439|                color: Colors.grey[200]!,
6440|                blurRadius: 12,
6441|                offset: const Offset(0, 4),
6442|                spreadRadius: 0,
6443|              ),
6444|              BoxShadow(
6445|                color: Colors.grey[200]!,
6446|                blurRadius: 6,
6447|                offset: const Offset(0, 2),
6448|                spreadRadius: 0,
6449|              ),
6450|            ],
6451|          ),
6452|          child: Padding(
6453|            padding: const EdgeInsets.all(14.0),
6454|            child: Column(
6455|              crossAxisAlignment: CrossAxisAlignment.stretch,
6456|              mainAxisSize: MainAxisSize.min,
6457|              children: [
6458|                // Spacing for priority label
6459|                const SizedBox(height: 20),
6460|                // Top row: project name + status aligned with edit/delete icons
6461|                Row(
6462|                  crossAxisAlignment: CrossAxisAlignment.center,
6463|                  children: [
6464|                    // Project name and status on left
6465|                    Expanded(
6466|                      child: Row(
6467|                        children: [
6468|                          Flexible(
6469|                            child: Text(
6470|                              project.title,
6471|                              style: const TextStyle(
6472|                                fontSize: 15,
6473|                                fontWeight: FontWeight.bold,
6474|                                color: Colors.black87,
6475|                              ),
6476|                              maxLines: 1,
6477|                              overflow: TextOverflow.ellipsis,
6478|                            ),
6479|                          ),
6480|                        ],
6481|                      ),
6482|                    ),
6483|                    // Attachment, Edit & Delete buttons aligned with title
6484|                    Row(
6485|                      mainAxisSize: MainAxisSize.min,
6486|                      children: [
6487|                        IconButton(
6488|                          onPressed: () => _showDocumentsDialog(project),
6489|                          icon: const Icon(Icons.attach_file, size: 18),
6490|                          color: Colors.teal[700],
6491|                          padding: const EdgeInsets.all(4),
6492|                          constraints: const BoxConstraints(
6493|                            minWidth: 32,
6494|                            minHeight: 32,
6495|                          ),
6496|                          tooltip: 'Documents',
6497|                          style: IconButton.styleFrom(
6498|                            backgroundColor: Colors.teal[50],
6499|                            shape: RoundedRectangleBorder(
6500|                              borderRadius: BorderRadius.circular(6),
6501|                            ),
6502|                          ),
6503|                        ),
6504|                        const SizedBox(width: 4),
6505|                        IconButton(
6506|                          onPressed: () => _editProject(project),
6507|                          icon: const Icon(Icons.edit_outlined, size: 18),
6508|                          color: Colors.orange[700],
6509|                          padding: const EdgeInsets.all(4),
6510|                          constraints: const BoxConstraints(
6511|                            minWidth: 32,
6512|                            minHeight: 32,
6513|                          ),
6511|                          tooltip: 'Edit Project',
6512|                          style: IconButton.styleFrom(
6513|                            backgroundColor: Colors.orange[50],
6514|                            shape: RoundedRectangleBorder(
6515|                              borderRadius: BorderRadius.circular(6),
6516|                            ),
6517|                          ),
6518|                        ),
6519|                        const SizedBox(width: 4),
6520|                        IconButton(
6521|                          onPressed: () => _deleteProject(project),
6522|                          icon: const Icon(Icons.delete_outline, size: 18),
6523|                          color: Colors.red[700],
6524|                          padding: const EdgeInsets.all(4),
6525|                          constraints: const BoxConstraints(
6526|                            minWidth: 32,
6527|                            minHeight: 32,
6528|                          ),
6529|                          tooltip: 'Delete Project',
6530|                          style: IconButton.styleFrom(
6531|                            backgroundColor: Colors.red[50],
6532|                            shape: RoundedRectangleBorder(
6533|                              borderRadius: BorderRadius.circular(6),
6534|                            ),
6535|                          ),
6536|                        ),
6537|                      ],
6538|                    ),
6539|                  ],
6540|                ),
6541|                // Description row with Cancel and Start buttons (for pending projects)
6542|                if (project.description != null || isPending || isOngoing) ...[
6543|                  SizedBox(height: isReceivedTab ? 4 : 8),
6544|                  Row(
6545|                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
6546|                    crossAxisAlignment: CrossAxisAlignment.center,
6547|                    children: [
6548|                      // Description section
6549|                      if (project.description != null)
6550|                        Expanded(
6551|                          child: Text(
6552|                            project.description!,
6553|                            maxLines: 1,
6554|                            overflow: TextOverflow.ellipsis,
6555|                            style: TextStyle(
6556|                              fontSize: 14,
6557|                              color: Colors.black87,
6558|                              fontWeight: FontWeight.w400,
6559|                              height: 1.4,
6560|                            ),
6561|                          ),
6562|                        ),
6563|                      // Spacer to push buttons to the right when there's no description
6564|                      if (project.description == null && !isPending && isOngoing)
6565|                        const Spacer(),
6566|                      // Cancel and Start buttons (for pending projects)
6567|                      if (isPending) ...[
6568|                        if (project.description != null)
6569|                          const SizedBox(width: 8),
6570|                        Row(
6571|                          mainAxisSize: MainAxisSize.min,
6572|                          children: [
6573|                            _HoverableStartButton(
6574|                              canStart: _canStartProject(project),
6575|                              onPressed: () => _startProject(project),
6576|                            ),
6577|                            const SizedBox(width: 4),
6578|                            _HoverableCancelButton(
6579|                              onPressed: () => _cancelProject(project),
6580|                            ),
6581|                          ],
6582|                        ),
6583|                      ],
6584|                    ],
6585|                  ),
6586|                ],
6587|                // Date row
6588|                SizedBox(height: isReceivedTab ? 4 : 8),
6589|                if (project.startDate != null || project.endDate != null)
6590|                  Row(
6591|                    mainAxisAlignment: MainAxisAlignment.start,
6592|                    mainAxisSize: MainAxisSize.min,
6593|                    children: [
6594|                      if (project.startDate != null) ...[
6595|                        Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
6596|                        const SizedBox(width: 4),
6597|                        Text(
6598|                          DateFormat('MMM dd, yyyy').format(project.startDate!),
6599|                          style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500, height: 1.2),
6600|                        ),
6601|                      ],
6602|                      if (project.startDate != null && project.endDate != null) ...[
6603|                        Padding(
6604|                          padding: const EdgeInsets.symmetric(horizontal: 4),
6605|                          child: Icon(Icons.arrow_forward, size: 12, color: Colors.grey[400]),
6606|                        ),
6607|                      ],
6608|                      if (project.endDate != null) ...[
6609|                        Icon(Icons.event, size: 14, color: Colors.grey[600]),
6610|                        const SizedBox(width: 4),
6611|                        Text(
6612|                          DateFormat('MMM dd, yyyy').format(project.endDate!),
6613|                          style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500, height: 1.2),
6614|                        ),
6615|                      ],
6616|                    ],
6617|                  ),
6618|            // Assign Users button (for pending projects)
6619|            if (isPending) ...[
6620|              SizedBox(height: isReceivedTab ? 4 : 8),
6621|              SizedBox(
6622|                width: double.infinity,
6623|                child: ElevatedButton.icon(
6624|                  onPressed: () => _showAssignUsersDialog(project),
6625|                  icon: const Icon(Icons.person_add, size: 18),
6626|                  label: const Text(
6627|                    'Assign Users',
6628|                    style: TextStyle(
6629|                      fontSize: 14,
6630|                      fontWeight: FontWeight.w600,
6631|                    ),
6632|                  ),
6633|                  style: ElevatedButton.styleFrom(
6634|                    backgroundColor: Colors.cyan[600],
6635|                    foregroundColor: Colors.white,
6636|                    padding: const EdgeInsets.symmetric(vertical: 12),
6637|                    shape: RoundedRectangleBorder(
6638|                      borderRadius: BorderRadius.circular(8),
6639|                    ),
6639|                    elevation: 2,
6640|                  ),
6641|                ),
6642|              ),
6643|            ],
```

**What it displays for Received tab projects:**
- Project title (bold)
- Documents button (teal)
- Edit button (orange)
- Delete button (red)
- Description (if available)
- **Start button** (green) - only for pending
- **Cancel button** (red) - only for pending
- Date range (start date → end date)
- **Assign Users button** (cyan) - only for pending

**Special Styling:**
- Reduced margin between cards (`isReceivedTab ? 4 : 10`)
- Reduced spacing between elements (`isReceivedTab ? 4 : 8`)

---

## Summary of Received Tab Features

### ✅ Features Available in Received Tab

1. **Project Filtering**
   - Shows only projects with `pending` status
   - Empty state message when no projects

2. **Start Project Button** ⭐ **KEY FEATURE**
   - Validates all 5 required users before starting
   - Shows detailed error messages for missing roles
   - Moves project to Ongoing tab on success

3. **Cancel Project Button**
   - Confirmation dialog before cancelling
   - Moves project to Cancelled tab

4. **Assign Users Button**
   - Opens dialog to assign all 5 user types
   - Validates assignments after dialog closes
   - Shows feedback messages

5. **Search Functionality**
   - Search projects by title
   - Real-time filtering

6. **Sort Functionality**
   - Sort by date (ascending/descending)
   - Sort by title (A-Z, Z-A)
   - Sort by priority

7. **Project Actions**
   - Edit project
   - Delete project (request)
   - View documents

8. **Project Information Display**
   - Project title
   - Description
   - Date range
   - Priority indicator

---

## User Workflow in Received Tab

1. **View Projects**
   - Coordinator sees all pending projects
   - Can search and sort to find specific projects

2. **Assign Users**
   - Click "Assign Users" button
   - Assign Field Officer, Client, Agent (if needed), Accessor, Senior Valuer
   - System validates and shows feedback

3. **Start Project**
   - Click "Start" button
   - System validates all required users are assigned
   - If all assigned → Project moves to Ongoing tab
   - If any missing → Error message shows missing roles

4. **Manage Project**
   - Edit project details
   - Cancel project if needed
   - View/upload documents

---

## Code Statistics

- **Total Lines for Received Tab Features:** ~500+ lines
- **Key Methods:**
  - `_buildProjectsTab()` - Tab structure
  - `_canStartProject()` - Validation logic
  - `_startProject()` - Start with validation
  - `_cancelProject()` - Cancel functionality
  - `_showAssignUsersDialog()` - User assignment
  - `_buildProjectCard()` - Card display
  - `_filterAndSortProjects()` - Search and sort

---

**Last Updated:** 2024  
**Branch:** sapuni  
**Developer:** Sapuni

