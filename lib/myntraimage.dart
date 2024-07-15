import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ImageUploadWidget extends StatefulWidget {
  @override
  _ImageUploadWidgetState createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends State<ImageUploadWidget> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _hashtagController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> _getImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _imageFile = File(pickedFile.path);
      } else {
        print('No image selected.');
      }
    });
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null) return;

    try {
      // Upload image to Firebase Storage
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = _storage.ref().child('images/$fileName.jpg');
      UploadTask uploadTask = ref.putFile(_imageFile!);
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      // Save image info to Firestore
      await _firestore.collection('images').add({
        'url': downloadUrl,
        'hashtag': _hashtagController.text,
        'fileName': fileName,
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image uploaded successfully!')));

      // Clear the form
      setState(() {
        _imageFile = null;
        _hashtagController.clear();
      });
    } catch (e) {
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to upload image')));
    }
  }

  Future<void> _deleteImage(String downloadUrl, String fileName) async {
    try {
      // Delete image from Firebase Storage
      await _storage.ref().child('images/$fileName.jpg').delete();

      // Delete image info from Firestore
      QuerySnapshot querySnapshot = await _firestore
          .collection('images')
          .where('url', isEqualTo: downloadUrl)
          .get();
      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image deleted successfully!')));
    } catch (e) {
      print('Error deleting image: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to delete image')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Image Upload and Delete')),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            _imageFile != null
                ? Image.file(_imageFile!, height: 200)
                : Text('No image selected.'),
            ElevatedButton(
              onPressed: _getImage,
              child: Text('Select Image'),
            ),
            TextField(
              controller: _hashtagController,
              decoration: InputDecoration(labelText: 'Hashtag'),
            ),
            ElevatedButton(
              onPressed: _uploadImage,
              child: Text('Upload Image'),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('images').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                return ListView(
                  shrinkWrap: true,
                  children: snapshot.data!.docs.map((doc) {
                    Map<String, dynamic> data =
                        doc.data() as Map<String, dynamic>;
                    return ListTile(
                      leading: Image.network(data['url'], width: 50, height: 50),
                      title: Text(data['hashtag']),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => _deleteImage(data['url'], data['fileName']),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}