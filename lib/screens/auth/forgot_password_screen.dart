import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/brutal_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  
  int _step = 1; // 1 = Email, 2 = OTP & New Password
  bool _loading = false;

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;

    setState(() => _loading = true);
    try {
      await apiService.sendOtp(type: 'FORGOT_PASSWORD', value: email);
      if (mounted) {
        setState(() {
          _step = 2;
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP sent to email')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppTheme.rose));
      }
    }
  }

  Future<void> _verifyAndReset() async {
    final email = _emailCtrl.text.trim();
    final otp = _otpCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (otp.isEmpty || pass.isEmpty) return;

    setState(() => _loading = true);
    try {
      await apiService.verifyOtp(type: 'FORGOT_PASSWORD', value: email, otp: otp);
      await apiService.resetPassword(email: email, otp: otp, newPassword: pass);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset successfully. You can now login.'), backgroundColor: AppTheme.teal));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppTheme.rose));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Forgot Password', style: TextStyle(color: AppTheme.text, fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.text),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reset your password securely.', style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
              const SizedBox(height: 32),
              
              if (_step == 1) ...[
                BrutalTextField(
                  label: 'Email Address',
                  controller: _emailCtrl,
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                const SizedBox(height: 24),
                BrutalButton(
                  label: 'SEND OTP',
                  onPressed: _loading ? null : _sendOtp,
                  isLoading: _loading,
                  width: double.infinity,
                ),
              ] else ...[
                Text('OTP sent to ${_emailCtrl.text.trim()}', style: const TextStyle(color: AppTheme.teal, fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                BrutalTextField(
                  label: 'Enter OTP',
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  prefixIcon: const Icon(Icons.security),
                ),
                const SizedBox(height: 16),
                BrutalTextField(
                  label: 'New Password',
                  controller: _passCtrl,
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                const SizedBox(height: 24),
                BrutalButton(
                  label: 'RESET PASSWORD',
                  onPressed: _loading ? null : _verifyAndReset,
                  isLoading: _loading,
                  width: double.infinity,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
