import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/business_categories.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  int _currentStep = 0;
  final _credsFormKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();
  
  // Credentials
  final _emailPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Profile
  final _nameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _chapterController = TextEditingController();
  final _locationController = TextEditingController();
  String? _selectedCategory;

  void _nextStep() {
    if (_currentStep == 0) {
      if (_credsFormKey.currentState?.validate() ?? false) {
        setState(() => _currentStep++);
      }
    } else {
      if (_profileFormKey.currentState?.validate() ?? false) {
        if (_selectedCategory == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a business category')),
          );
          return;
        }
        _submitRegistration();
      }
    }
  }

  void _submitRegistration() async {
    // TODO: Implement actual Firebase Auth registration
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registration successful!')),
    );
    context.go('/conclaves');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep == 1) {
              setState(() => _currentStep = 0);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: _nextStep,
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              context.pop();
            }
          },
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: details.onStepContinue,
                      child: Text(_currentStep == 1 ? 'Complete Registration' : 'Next'),
                    ),
                  ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Credentials'),
              isActive: _currentStep >= 0,
              content: Form(
                key: _credsFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Email or Phone Number',
                        prefixIcon: Icon(Icons.contact_mail),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (v) => v != null && v.length < 6 ? 'Min 6 chars' : null,
                    ),
                  ],
                ),
              ),
            ),
            Step(
              title: const Text('Profile'),
              isActive: _currentStep >= 1,
              content: Form(
                key: _profileFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _businessNameController,
                      decoration: const InputDecoration(labelText: 'Business Name'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Business Category'),
                      value: _selectedCategory,
                      items: bniBusinessCategories.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c));
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _chapterController,
                      decoration: const InputDecoration(labelText: 'Chapter (Optional)'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location (City)',
                        hintText: 'e.g., Guntur',
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
