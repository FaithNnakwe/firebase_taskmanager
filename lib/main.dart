// Import Flutter package
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(TaskApp());
}

class Task {
  String id; // Firestore document ID
  String name;
  bool isCompleted;
  String priority;

  Task({this.id = '', required this.name, this.isCompleted = false, required this.priority});

  factory Task.fromMap(Map<String, dynamic> data, String documentId) {
    return Task(
      id: documentId,
      name: data['name'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      priority: data['priority'] ?? 'Medium',
    );
  }

  Map<String, dynamic> toMap(String userId) {
    return {
      'name': name,
      'isCompleted': isCompleted,
      'priority': priority,
      'userId': userId,
    };
  }
}


class TaskApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TaskListScreen(),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
     final CollectionReference inventory = 
      FirebaseFirestore.instance.collection('inventory');

  List<Task> tasks = [];
  final TextEditingController _taskController = TextEditingController();
  String _selectedPriority = 'Medium';
  final List<String> _priorities = ['High', 'Medium', 'Low'];

  void _addTask() async {
  if (_taskController.text.isNotEmpty) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await inventory.add({
        'name': _taskController.text,
        'isCompleted': false,
        'priority': _selectedPriority,
        'userId': user.uid,
      });
    }
    _taskController.clear();
  }
}


  void _toggleTaskCompletion(int index) {
    setState(() {
      tasks[index].isCompleted = !tasks[index].isCompleted;
    });
  }

  void _removeTask(int index) {
    setState(() {
      tasks.removeAt(index);
    });
  }

  void _sortTasks() {
    tasks.sort((a, b) {
      return _priorities.indexOf(a.priority).compareTo(_priorities.indexOf(b.priority));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Task Manager')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: InputDecoration(
                      labelText: 'Enter task',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedPriority,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedPriority = newValue!;
                    });
                  },
                  items: _priorities.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTask,
                  child: Text('Add'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    tasks[index].name,
                    style: TextStyle(
                      decoration: tasks[index].isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Text('Priority: ${tasks[index].priority}'),
                  leading: Checkbox(
                    value: tasks[index].isCompleted,
                    onChanged: (value) {
                      _toggleTaskCompletion(index);
                    },
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => _removeTask(index),
                    child: Text('Delete', style: TextStyle(color: Colors.white)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
