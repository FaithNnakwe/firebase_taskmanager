// Import Flutter package
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async{
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
  String? uid; // Make the UID nullable

  @override
  void initState() {
    super.initState();
    // Get the current user UID safely
    if (_auth.currentUser != null) {
      uid = _auth.currentUser!.uid;
    }
  }

  Future<void> _addTask(String taskName) async {
    if (taskName.trim().isEmpty || uid == null) return; // Return early if uid is null

    await _firestore.collection('tasks').add({
      'userId': uid,
      'title': taskName,
      'completed': false,
      'timestamp': FieldValue.serverTimestamp(),
      'subtasks': [],
    });

    taskController.clear();
  }

  Future<void> _toggleComplete(String taskId, bool currentStatus) async {
    await _firestore.collection('tasks').doc(taskId).update({
      'completed': !currentStatus,
    });
  }

  Future<void> _deleteTask(String taskId) async {
    await _firestore.collection('tasks').doc(taskId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
              Navigator.of(context).pop(); // Go back to login screen
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
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
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addTask(taskController.text),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('tasks')
                  .where('userId', isEqualTo: uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();

                final tasks = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    var task = tasks[index];
                    var taskId = task.id;
                    var title = task['title'];
                    var completed = task['completed'];

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
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteTask(taskId),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
