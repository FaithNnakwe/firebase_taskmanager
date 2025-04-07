// Import Flutter package
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const TaskListScreen(),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TextEditingController taskController = TextEditingController();
  String? uid;
  String selectedPriority = 'Medium';
  String sortingCriteria = 'priority';
  bool showCompletedTasks = true;
  String? filterPriority;
  DateTime? dueDate;

  @override
void initState() {
  super.initState();
  _auth.authStateChanges().listen((User? user) {
    if (user != null) {
      setState(() {
        uid = user.uid;
      });
      updateExistingTasks();
      print("User logged in: ${user.uid}");
    } else {
      print("No user logged in.");
    }
  });
}

Future<void> updateExistingTasks() async {
  final tasks = await _firestore.collection('tasks').get();
  for (var task in tasks.docs) {
    if (!task.data().containsKey('priorityValue')) {
      String priority = task['priority'];
      Map<String, int> priorityOrder = {'High': 1, 'Medium': 2, 'Low': 3};

      await _firestore.collection('tasks').doc(task.id).update({
        'priorityValue': priorityOrder[priority] ?? 3, // Default to Low
      });
    }
  }
}

Future<void> _addTask(String taskName) async {
  final currentUser = _auth.currentUser;
  if (taskName.trim().isEmpty || currentUser == null) {
    print("Error: Task name is empty or user is null.");
    return;
  }

  // Map priority to numeric values
  Map<String, int> priorityOrder = {'High': 1, 'Medium': 2, 'Low': 3};

  try {
    await _firestore.collection('tasks').add({
      'userId': currentUser.uid,
      'title': taskName,
      'priority': selectedPriority, // ✅ Fix: Store priority
      'priorityValue': priorityOrder[selectedPriority], // Add numeric priority
      'completed': false,
      'due_date': dueDate, // Store due date in Firestore
    });
    print("Task added successfully!");
    setState(() {}); // Trigger a UI update
  } catch (e) {
    print("Error adding task: $e");
  }
}


  Future<void> _toggleComplete(String taskId, bool currentStatus) async {
    await _firestore.collection('tasks').doc(taskId).update({
      'completed': !currentStatus,
    });
  }

  Future<void> _deleteTask(String taskId) async {
    await _firestore.collection('tasks').doc(taskId).delete();
  }

  void _showEditDialog(String taskId, String currentTitle,DateTime? currentDueDate) {
  TextEditingController editController = TextEditingController(text: currentTitle);

  // Set the current due date to the passed task's due date or null
  setState(() {
    dueDate = currentDueDate;
  });

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Edit Task"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: editController,
            decoration: const InputDecoration(hintText: "Update your task"),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _pickDueDate,  // Open date picker when clicked
            child: Text(
              'Select Due Date: ${dueDate?.toLocal().toString().split(' ')[0] ?? 'Not set'}',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () async {
            String newTitle = editController.text.trim();
            if (newTitle.isNotEmpty) {
              await _firestore.collection('tasks').doc(taskId).update({
                'title': newTitle,
                'due_date': dueDate,  // Update due date when editing
              });
            }
            Navigator.pop(context);
          },
          child: const Text("Save"),
        ),
      ],
    ),
  );
}

void _pickDueDate() async {
  DateTime? pickedDate = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2000),
    lastDate: DateTime(2101),
  );

  if (pickedDate != null) {
    setState(() {
      dueDate = pickedDate;  // Update the due date when picked
    });
  }
}



  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.yellow;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(uid != null ? 'Welcome back!' : 'Task Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: taskController,
                    decoration: const InputDecoration(
                      hintText: 'Enter new task',
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: selectedPriority,
                  style: TextStyle(
    color: selectedPriority == 'Low'
        ? Colors.green
        : selectedPriority == 'Medium'
            ? Colors.orange
            : selectedPriority == 'High'
                ? Colors.red
                : Colors.black, // Default color for 'All' or other values
    fontSize: 16, // Optional: Adjust font size
  ),
                  items: ['High', 'Medium', 'Low'].map((String priority) {
                    return DropdownMenuItem<String>(
                      value: priority,
                      child: Text(priority),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedPriority = value!;
                    });
                  },
                ),
                IconButton(
        icon: const Icon(Icons.calendar_today),
        onPressed: _pickDueDate,  // Call the DatePicker
      ),
                 TextButton(
    onPressed: () => _addTask(taskController.text),
    child: Text(
      'Add',
      style: TextStyle(color: Colors.black),  // Adjust color as needed
    ),
  ),
              ], //onPressed: () => _addTask(taskController.text)
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<String>(
                  value: sortingCriteria,
                  items: {
                    'priority': 'Priority',
                    'due_date': 'Due Date'
                  }.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      sortingCriteria = value!;
                    });
                  },
                ),
                DropdownButton<String?>(
                  hint: const Text('Filter Priority'),
                  value: filterPriority,
                  items: [null, 'High', 'Medium', 'Low'].map((priority) {
                    return DropdownMenuItem<String?>(
                      value: priority,
                      child: Text(priority ?? 'All'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      filterPriority = value;
                    });
                  },
                ),
                Switch(
                  value: showCompletedTasks,
                  onChanged: (value) {
                    setState(() {
                      showCompletedTasks = value;
                    });
                  },
                  activeColor: Colors.blue,
                ),
              ],
            ),
          ),
          Expanded(
  child: uid == null
      ? Center(child: CircularProgressIndicator()) // Wait for uid to load
      : StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('tasks')
              .where('userId', isEqualTo: uid) // Now uid is guaranteed to be non-null
              // .orderBy(sortingCriteria == 'timestamp' ? 'timestamp' : 'priority', descending: sortingCriteria == 'timestamp')
              .orderBy('priorityValue',descending: false)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(child: Text("No tasks found."));
            }

            final tasks = snapshot.data!.docs.where((task) {
              if (!showCompletedTasks && task['completed']) return false;
              if (filterPriority != null && task['priority'] != filterPriority) return false;
              return true;
            }).toList();
            return ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                var task = tasks[index];
                var taskId = task.id;
                var title = task['title'];
                var completed = task['completed'];
                var priority = task['priority'];
                var dueDate = task['due_date'] != null ? (task['due_date'] as Timestamp).toDate() : null;

                return ListTile(
                  leading: Checkbox(
                    value: completed,
                    onChanged: (_) => _toggleComplete(taskId, completed),
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                      decoration: completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Text(
    'Due Date: ${dueDate?.toLocal().toString().split(' ')[0] ?? 'Not set'}',  // Display due date
  ),
                  trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    IconButton(
      icon: const Icon(Icons.edit),
      onPressed: () {
        _showEditDialog(taskId, title, dueDate);
      },
    ),
    IconButton(
      icon: const Icon(Icons.delete),
      onPressed: () => _deleteTask(taskId),
    ),
  ],
),
                  tileColor: _getPriorityColor(priority).withOpacity(0.2),
                );
              },
            );
          },
        ),
)
        ],
      ),
    );
  }
}
