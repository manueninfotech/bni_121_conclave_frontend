import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/business_categories.dart';
import '../data/auth_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  int _currentStep = 0;
  final _credsFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();
  
  // Credentials
  final _identifierController = TextEditingController(); // Email or Phone
  final _passwordController = TextEditingController();
  
  // OTP
  final _otpController = TextEditingController();
  String? _verificationId;
  bool _isPhoneFlow = false;
  
  // Profile
  final _nameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _chapterController = TextEditingController();
  final _locationController = TextEditingController();
  String? _selectedCategory;
  
  bool _isLoading = false;

  void _nextStep() async {
    if (_currentStep == 0) {
      if (_credsFormKey.currentState?.validate() ?? false) {
        final identifier = _identifierController.text.trim();
        _isPhoneFlow = RegExp(r'^\+?[0-9]{10,15}$').hasMatch(identifier);

        if (_isPhoneFlow) {
          setState(() => _isLoading = true);
          try {
            await ref.read(authRepositoryProvider).verifyPhone(
              phone: identifier,
              onCodeSent: (String verId) {
                if (mounted) {
                  setState(() {
                    _verificationId = verId;
                    _isLoading = false;
                    _currentStep = 1; // Go to OTP step
                  });
                }
              },
              onError: (String error) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error), backgroundColor: Colors.red),
                  );
                }
              },
            );
          } catch (e) {
            setState(() => _isLoading = false);
          }
        } else {
          setState(() => _currentStep = 2); // Skip OTP, go directly to profile
        }
      }
    } else if (_currentStep == 1) { // OTP Step
      if (_otpFormKey.currentState?.validate() ?? false) {
        setState(() => _isLoading = true);
        try {
          await ref.read(authRepositoryProvider).submitOtp(
            _verificationId!, 
            _otpController.text.trim()
          );
          if (mounted) {
            setState(() {
              _isLoading = false;
              _currentStep = 2; // Go to profile
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
            );
          }
        }
      }
    } else { // Profile step
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
    setState(() => _isLoading = true);
    final repo = ref.read(authRepositoryProvider);
    
    try {
      if (_isPhoneFlow) {
        // User is already signed in via OTP, just set password and save profile
        final user = FirebaseAuth.instance.currentUser!;
        await repo.registerProfileForPhoneUser(
          user: user,
          phone: _identifierController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
          businessName: _businessNameController.text.trim(),
          businessCategory: _selectedCategory!,
          location: _locationController.text.trim(),
          chapter: _chapterController.text.trim(),
        );
      } else {
        // Full email registration
        await repo.registerWithEmailAndPassword(
          email: _identifierController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
          businessName: _businessNameController.text.trim(),
          businessCategory: _selectedCategory!,
          location: _locationController.text.trim(),
          chapter: _chapterController.text.trim(),
        );
      }
      
      // Router redirect handles navigation automatically
      if (!_isPhoneFlow && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please check your email to verify your account.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() {
                if (_currentStep == 2 && !_isPhoneFlow) {
                  _currentStep = 0;
                } else {
                  _currentStep--;
                }
              });
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
              setState(() {
                if (_currentStep == 2 && !_isPhoneFlow) {
                  _currentStep = 0;
                } else {
                  _currentStep--;
                }
              });
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
                      onPressed: _isLoading ? null : details.onStepContinue,
                      child: _isLoading 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(_currentStep == 2 ? 'Complete Registration' : 'Next'),
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
                      controller: _identifierController,
                      decoration: const InputDecoration(
                        labelText: 'Email or Phone Number (+CountryCode)',
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
              title: const Text('Phone Verification'),
              isActive: _currentStep >= 1,
              state: _isPhoneFlow ? StepState.indexed : StepState.disabled,
              content: _isPhoneFlow ? Form(
                key: _otpFormKey,
                child: Column(
                  children: [
                    const Text('An OTP has been sent to your phone.'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Enter OTP',
                        prefixIcon: Icon(Icons.message),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
              ) : const Text('Email verification will be sent after registration.'),
            ),
            Step(
              title: const Text('Profile'),
              isActive: _currentStep >= 2,
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
                      initialValue: _selectedCategory,
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
