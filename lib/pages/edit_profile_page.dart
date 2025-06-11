import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ontrack/providers/profile_provider.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController nameController;
  late TextEditingController emailController;
  ImageProvider? picture;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>();
    nameController = TextEditingController(text: profile.name);
    emailController = TextEditingController(text: profile.email);
    picture = profile.picture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.indigo.shade100,
                  backgroundImage: picture,
                  child: picture == null
                      ? const Icon(Icons.person, size: 48, color: Colors.indigo)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.edit, size: 18, color: Colors.indigo),
                      onPressed: () async {
                        // For demo: Toggle between null and a sample image
                        setState(() {
                          if (picture == null) {
                            picture = const NetworkImage('https://i.pravatar.cc/150?img=3');
                          } else {
                            picture = null;
                          }
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
          ),
          const SizedBox(height: 24),
          // Consent suggestion placeholder
          Card(
            color: Colors.indigo.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: const [
                  Icon(Icons.privacy_tip, color: Colors.indigo),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Based on your searches, you might want to review your consent settings.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save Changes'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              context.read<ProfileProvider>().update(
                    name: nameController.text,
                    email: emailController.text,
                    picture: picture,
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile changes saved!')),
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}