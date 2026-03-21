import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

const List<String> kAvailableServices = [
  'Plumber','Electrician','Cleaner','Painter','Carpenter',
  'AC Repair','Gardener','Security','Mason','Welder','Glass Work','Roof Repair',
];

class ProviderOnboardingScreen extends ConsumerStatefulWidget {
  const ProviderOnboardingScreen({super.key});
  @override
  ConsumerState<ProviderOnboardingScreen> createState() => _ProviderOnboardingScreenState();
}

class _ProviderOnboardingScreenState extends ConsumerState<ProviderOnboardingScreen> {
  final _bioController = TextEditingController();
  final _experienceController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _cnicController = TextEditingController();

  final List<String> _selectedServices = [];
  String _selectedGender = 'Male';
  File? _profileImage;
  bool _isLoading = false;
  int _currentStep = 0;

  @override
  void dispose() {
    _bioController.dispose();
    _experienceController.dispose();
    _hourlyRateController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _cnicController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null) setState(() => _profileImage = File(picked.path));
  }

  Future<String?> _uploadPhoto(String uid) async {
    if (_profileImage == null) return null;
    try {
      final ext = _profileImage!.path.split('.').last;
      final ref = FirebaseStorage.instance.ref()
          .child('avatars/$uid/profile_${DateTime.now().millisecondsSinceEpoch}.$ext');
      final task = await ref.putFile(_profileImage!, SettableMetadata(contentType: 'image/$ext'));
      return await task.ref.getDownloadURL();
    } catch (_) { return null; }
  }

  Future<void> _submitOnboarding() async {
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one service')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;
      final firestore = ref.read(firestoreProvider);
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final avatarUrl = await _uploadPhoto(user.uid);

      await firestore.collection('providers').doc(user.uid).set({
        'name': userData['name'] ?? '',
        'email': userData['email'] ?? '',
        'phone': _phoneController.text.trim(),
        'bio': _bioController.text.trim(),
        'skills': _selectedServices,
        'experienceYears': int.tryParse(_experienceController.text) ?? 0,
        'hourlyRate': double.tryParse(_hourlyRateController.text) ?? 0,
        'address': _addressController.text.trim(),
        'gender': _selectedGender,
        'age': int.tryParse(_ageController.text) ?? 0,
        'cnic': _cnicController.text.trim(),
        'rating': 0.0,
        'reviewCount': 0,
        'isAvailable': true,
        'isVerified': false,
        'latitude': 31.5204,
        'longitude': 74.3587,
        'createdAt': FieldValue.serverTimestamp(),
        'onboardingComplete': true,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      }, SetOptions(merge: true));

      await firestore.collection('users').doc(user.uid).update({
        'onboardingComplete': true,
        'phone': _phoneController.text.trim(),
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      });

      await firestore.collection('notifications').add({
        'recipientId': user.uid,
        'title': '🎉 Provider Profile Created!',
        'body': 'Your profile is under review. You\'ll be notified once verified.',
        'type': 'provider_welcome',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) context.go(AppRoutes.providerDashboard);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Set Up Your Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.userDashboard),
        ),
      ),
      body: Theme(
        data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)),
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 3) {
              setState(() => _currentStep++);
            } else {
              _submitOnboarding();
            }
          },
          onStepCancel: () { if (_currentStep > 0) setState(() => _currentStep--); },
          controlsBuilder: (context, details) => Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(children: [
              ElevatedButton(
                onPressed: _isLoading ? null : details.onStepContinue,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                    minimumSize: const Size(120, 44)),
                child: _isLoading && _currentStep == 3
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_currentStep == 3 ? 'Submit' : 'Continue'),
              ),
              if (_currentStep > 0) ...[
                const SizedBox(width: 12),
                TextButton(onPressed: details.onStepCancel, child: const Text('Back')),
              ],
            ]),
          ),
          steps: [
            Step(
              title: const Text('Personal Info'),
              subtitle: const Text('Photo, gender & age'),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: Column(children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: Stack(children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.primaryLight,
                        backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                        child: _profileImage == null
                            ? const Icon(Icons.person, size: 48, color: AppColors.primary) : null,
                      ),
                      Positioned(bottom: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        )),
                    ]),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Tap to add profile photo',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _selectedGender,
                  decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.person_outline)),
                  items: ['Male', 'Female', 'Prefer not to say']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setState(() => _selectedGender = v!),
                ),
                const SizedBox(height: 16),
                TextFormField(controller: _ageController, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age', prefixIcon: Icon(Icons.cake_outlined), hintText: 'e.g. 30')),
                const SizedBox(height: 16),
                TextFormField(controller: _cnicController, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'CNIC Number', prefixIcon: Icon(Icons.badge_outlined), hintText: '3XXXX-XXXXXXX-X')),
              ]),
            ),
            Step(
              title: const Text('Your Services'),
              subtitle: const Text('What do you offer?'),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Select all services you provide:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: kAvailableServices.map((service) {
                    final selected = _selectedServices.contains(service);
                    return FilterChip(
                      label: Text(service), selected: selected,
                      onSelected: (val) => setState(() => val ? _selectedServices.add(service) : _selectedServices.remove(service)),
                      selectedColor: AppColors.primaryLight, checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: selected ? AppColors.primary : AppColors.textPrimary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
                    );
                  }).toList(),
                ),
                if (_selectedServices.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('${_selectedServices.length} service(s) selected',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ],
              ]),
            ),
            Step(
              title: const Text('Experience & Rate'),
              subtitle: const Text('Your background'),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
              content: Column(children: [
                TextFormField(controller: _experienceController, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Years of Experience',
                      prefixIcon: Icon(Icons.workspace_premium_outlined), hintText: 'e.g. 5')),
                const SizedBox(height: 16),
                TextFormField(controller: _hourlyRateController, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Hourly Rate (Rs.)',
                      prefixIcon: Icon(Icons.payments_outlined), hintText: 'e.g. 800')),
                const SizedBox(height: 16),
                TextFormField(controller: _bioController, maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Bio / About You',
                      prefixIcon: Icon(Icons.description_outlined),
                      hintText: 'Describe your experience and what makes you stand out...',
                      alignLabelWithHint: true)),
              ]),
            ),
            Step(
              title: const Text('Contact & Location'),
              subtitle: const Text('How clients reach you'),
              isActive: _currentStep >= 3,
              state: StepState.indexed,
              content: Column(children: [
                TextFormField(controller: _phoneController, keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_outlined), hintText: '03XX-XXXXXXX')),
                const SizedBox(height: 16),
                TextFormField(controller: _addressController, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Service Area / Address',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      hintText: 'e.g. Gulberg, Lahore', alignLabelWithHint: true)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [
                    Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      'Your profile will be reviewed and verified by Home Ease before going live.',
                      style: TextStyle(fontSize: 12, color: AppColors.primary))),
                  ]),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
