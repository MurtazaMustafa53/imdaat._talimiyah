import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Imdaat Taleemiyah Receipt Generator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          primary: const Color(0xFF6366F1),
          surface: Colors.white,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        return user == null ? const LoginPage() : RoleGate(user: user);
      },
    );
  }
}

class RoleGate extends StatelessWidget {
  final User user;

  const RoleGate({required this.user, super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return ErrorPage(
            message: 'Unable to load your account role.',
            onRetry: () => (context as Element).markNeedsBuild(),
          );
        }
        final role = snapshot.data?.data()?['role']?.toString().toLowerCase();
        return role == 'admin'
            ? AdminPage(user: user)
            : ReceiptPage(user: user);
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        _showMessage(_authError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'The email or password is incorrect.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return error.message ?? 'Unable to sign in.';
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.receipt_long, size: 54),
                      const SizedBox(height: 16),
                      Text(
                        'Welcome back',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in to create and manage receipts.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || !value.contains('@')
                            ? 'Enter a valid email'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter your password'
                            : null,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _loading ? null : _login,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Sign in'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReceiptModel {
  final String name;
  final String its;
  final String phone;
  final String amount;
  final String user;
  final String? createdByUid;
  final Timestamp? createdAt;

  const ReceiptModel({
    required this.name,
    required this.its,
    required this.phone,
    required this.amount,
    required this.user,
    this.createdByUid,
    this.createdAt,
  });

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'its': its,
    'number': phone,
    'amount': amount,
    'user': user,
    'createdByUid': createdByUid,
    'createdAt': createdAt ?? FieldValue.serverTimestamp(),
  };

  factory ReceiptModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};
    return ReceiptModel(
      name: data['name']?.toString() ?? '',
      its: data['its']?.toString() ?? '',
      phone: data['number']?.toString() ?? data['phone']?.toString() ?? '',
      amount: data['amount']?.toString() ?? '',
      user: data['user']?.toString() ?? '',
      createdByUid: data['createdByUid']?.toString(),
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : null,
    );
  }
}

class ReceiptPage extends StatefulWidget {
  final User user;

  const ReceiptPage({required this.user, super.key});

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _itsController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _itsController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _generateReceipt() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final receipt = ReceiptModel(
      name: _nameController.text.trim(),
      its: _itsController.text.trim(),
      phone: _phoneController.text.trim(),
      amount: _amountController.text.trim(),
      user: widget.user.displayName ?? widget.user.email ?? widget.user.uid,
      createdByUid: widget.user.uid,
    );
    try {
      await FirebaseFirestore.instance
          .collection('receipts')
          .add(receipt.toFirestore());
      if (!mounted) return;
      await _showReceiptDialog(receipt);
    } catch (error) {
      if (mounted) _showMessage('Receipt could not be saved: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showReceiptDialog(ReceiptModel receipt) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        title: Text(receipt.name, textAlign: TextAlign.center),
        content: SizedBox(
          width: MediaQuery.sizeOf(context).width > 832
              ? 800
              : MediaQuery.sizeOf(context).width - 48,
          height: MediaQuery.sizeOf(context).height > 720
              ? 600
              : MediaQuery.sizeOf(context).height - 220,
          child: PdfPreview(
            build: (format) => _generateReceiptPdf(format, receipt),
            allowPrinting: true,
            allowSharing: true,
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            initialPageFormat: PdfPageFormat.a4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Generator'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _ReceiptForm(
        formKey: _formKey,
        nameController: _nameController,
        itsController: _itsController,
        phoneController: _phoneController,
        amountController: _amountController,
        saving: _saving,
        onSubmit: _generateReceipt,
      ),
    );
  }
}

class _ReceiptForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController itsController;
  final TextEditingController phoneController;
  final TextEditingController amountController;
  final bool saving;
  final VoidCallback onSubmit;

  const _ReceiptForm({
    required this.formKey,
    required this.nameController,
    required this.itsController,
    required this.phoneController,
    required this.amountController,
    required this.saving,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create a receipt',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter the payment details to save and generate a receipt.',
                    ),
                    const SizedBox(height: 24),
                    _field(nameController, 'Name', Icons.person_outline),
                    const SizedBox(height: 16),
                    _field(itsController, 'ITS', Icons.badge_outlined),
                    const SizedBox(height: 16),
                    _field(
                      phoneController,
                      'Phone',
                      Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _field(
                      amountController,
                      'Amount',
                      Icons.payments_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: saving ? null : onSubmit,
                      icon: saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(
                        saving ? 'Saving...' : 'Generate PDF receipt',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Please enter $label';
        if (label == 'Amount' && double.tryParse(value.trim()) == null) {
          return 'Enter a valid amount';
        }
        return null;
      },
    );
  }
}

class AdminPage extends StatelessWidget {
  final User user;

  const AdminPage({required this.user, super.key});

  CollectionReference<Map<String, dynamic>> get _receipts =>
      FirebaseFirestore.instance.collection('receipts');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Records'),
        actions: [
          IconButton(
            tooltip: 'Add entry',
            onPressed: () => _showEntryDialog(context),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _receipts.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Could not load receipts: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final documents = snapshot.data!.docs;
          if (documents.isEmpty) {
            return const Center(child: Text('No receipts saved yet.'));
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 700) {
                return _buildMobileList(context, documents);
              }
              return _buildDesktopTable(context, documents);
            },
          );
        },
      ),
    );
  }

  Widget _buildMobileList(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final document = documents[index];
        final receipt = ReceiptModel.fromDocument(document);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        receipt.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () =>
                          _showEntryDialog(context, document: document),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () => _deleteEntry(context, document.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                const Divider(height: 8),
                _mobileValue('ITS', receipt.its),
                _mobileValue('Phone', receipt.phone),
                _mobileValue('Amount', receipt.amount),
                _mobileValue('User', receipt.user),
                _mobileValue('Created', _formatDate(receipt.createdAt)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _mobileValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('ITS')),
          DataColumn(label: Text('Phone')),
          DataColumn(label: Text('Amount')),
          DataColumn(label: Text('User')),
          DataColumn(label: Text('Created')),
          DataColumn(label: Text('Actions')),
        ],
        rows: documents.map((document) {
          final receipt = ReceiptModel.fromDocument(document);
          return DataRow(
            cells: [
              DataCell(Text(receipt.name)),
              DataCell(Text(receipt.its)),
              DataCell(Text(receipt.phone)),
              DataCell(Text(receipt.amount)),
              DataCell(Text(receipt.user)),
              DataCell(Text(_formatDate(receipt.createdAt))),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () =>
                          _showEntryDialog(context, document: document),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () => _deleteEntry(context, document.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Pending';
    final date = timestamp.toDate();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _deleteEntry(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete receipt?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _receipts.doc(id).delete();
  }

  Future<void> _showEntryDialog(
    BuildContext context, {
    DocumentSnapshot<Map<String, dynamic>>? document,
  }) async {
    final existing = document == null
        ? null
        : ReceiptModel.fromDocument(document);
    final name = TextEditingController(text: existing?.name);
    final its = TextEditingController(text: existing?.its);
    final phone = TextEditingController(text: existing?.phone);
    final amount = TextEditingController(text: existing?.amount);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text(existing == null ? 'Add receipt' : 'Edit receipt'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _adminField(name, 'Name'),
                  _adminField(its, 'ITS'),
                  _adminField(phone, 'Phone'),
                  _adminField(amount, 'Amount'),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final data = {
                'name': name.text.trim(),
                'its': its.text.trim(),
                'number': phone.text.trim(),
                'amount': amount.text.trim(),
                'user': existing?.user ?? user.email ?? user.uid,
                'createdByUid': existing?.createdByUid ?? user.uid,
                'createdAt':
                    existing?.createdAt ?? FieldValue.serverTimestamp(),
              };
              if (document == null) {
                await _receipts.add(data);
              } else {
                await _receipts.doc(document.id).update(data);
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
    name.dispose();
    its.dispose();
    phone.dispose();
    amount.dispose();
  }

  Widget _adminField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Required' : null,
      ),
    );
  }
}

class ErrorPage extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorPage({required this.message, required this.onRetry, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

Future<Uint8List> _generateReceiptPdf(
  PdfPageFormat format,
  ReceiptModel receipt,
) async {
  final pdf = pw.Document();
  final imageBytes = await rootBundle.load('assets/image.jpeg');
  final bgImage = pw.MemoryImage(imageBytes.buffer.asUint8List());
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (context) => pw.Stack(
        children: [
          pw.Positioned.fill(
            top: 0,
            child: pw.Image(bgImage, fit: pw.BoxFit.fitWidth),
          ),
          _pdfText(receipt.name, 100, 355, 230),
          _pdfText(receipt.its, 100, 395, 230),
          _pdfText(receipt.amount, 120, 435, 190),
          _pdfText(receipt.user, 200, 503, 300),
        ],
      ),
    ),
  );
  return pdf.save();
}

pw.Widget _pdfText(String value, double left, double top, double width) {
  return pw.Positioned(
    left: left,
    top: top,
    child: pw.Container(
      width: width,
      height: 45,
      padding: const pw.EdgeInsets.all(8),
      color: PdfColors.white,
      child: pw.FittedBox(
        fit: pw.BoxFit.none,
        child: pw.Text(value, style: pw.TextStyle(fontSize: 25)),
      ),
    ),
  );
}
