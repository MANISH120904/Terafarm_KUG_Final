import 'package:flutter/material.dart';

class SubsidiesPage extends StatefulWidget {
  const SubsidiesPage({super.key});

  @override
  State<SubsidiesPage> createState() => _SubsidiesPageState();
}

class _SubsidiesPageState extends State<SubsidiesPage> {
  final List<Map<String, dynamic>> subsidies = [
    {
      'title': 'Pradhan Mantri Kisan Samman Nidhi',
      'description': 'Direct income support of ₹6,000 per year to small and marginal farmers',
      'eligibility': 'Small and marginal farmer families with cultivable land up to 2 hectares',
      'amount': '₹6,000 per year',
      'status': 'Active',
    },
    {
      'title': 'Kisan Credit Card (KCC)',
      'description': 'Credit facility for farmers to meet production credit and investment credit requirements',
      'eligibility': 'All farmers including tenant farmers, sharecroppers, and oral lessees',
      'amount': 'Up to ₹3 lakh at 4% interest',
      'status': 'Active',
    },
    {
      'title': 'Pradhan Mantri Fasal Bima Yojana',
      'description': 'Crop insurance scheme providing financial support to farmers in case of crop failure',
      'eligibility': 'All farmers growing notified crops in notified areas',
      'amount': 'Premium subsidy up to 2% for Kharif and 1.5% for Rabi crops',
      'status': 'Active',
    },
    {
      'title': 'Soil Health Card Scheme',
      'description': 'Provides soil health cards to farmers with recommendations for appropriate nutrients',
      'eligibility': 'All farmers across the country',
      'amount': 'Free soil testing and recommendations',
      'status': 'Active',
    },
    {
      'title': 'National Agriculture Market (e-NAM)',
      'description': 'Online trading platform for agricultural commodities',
      'eligibility': 'Farmers, traders, and buyers registered on the platform',
      'amount': 'Transparent price discovery and better market access',
      'status': 'Active',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Government Subsidies'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: subsidies.length,
        itemBuilder: (context, index) {
          final subsidy = subsidies[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16.0),
            elevation: 4,
            child: ExpansionTile(
              title: Text(
                subsidy['title'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                subsidy['description'],
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: subsidy['status'] == 'Active' ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  subsidy['status'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Eligibility:', subsidy['eligibility']),
                      const SizedBox(height: 8),
                      _buildDetailRow('Benefit Amount:', subsidy['amount']),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                _showApplicationDialog(context, subsidy['title']);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Apply Now'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _showMoreInfoDialog(context, subsidy);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green,
                              ),
                              child: const Text('More Info'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showApplicationStatus(context);
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.assignment, color: Colors.white),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  void _showApplicationDialog(BuildContext context, String subsidyName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Apply for $subsidyName'),
          content: const Text(
            'This will redirect you to the official government portal for application. Make sure you have all required documents ready.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Redirecting to application portal for $subsidyName'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Proceed'),
            ),
          ],
        );
      },
    );
  }

  void _showMoreInfoDialog(BuildContext context, Map<String, dynamic> subsidy) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(subsidy['title']),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Description:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(subsidy['description']),
                const SizedBox(height: 16),
                const Text(
                  'Eligibility Criteria:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(subsidy['eligibility']),
                const SizedBox(height: 16),
                const Text(
                  'Benefit Amount:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(subsidy['amount']),
                const SizedBox(height: 16),
                const Text(
                  'Required Documents:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  '• Aadhaar Card\n'
                  '• Bank Account Details\n'
                  '• Land Records\n'
                  '• Passport Size Photo\n'
                  '• Mobile Number',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showApplicationStatus(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Application Status'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.pending, color: Colors.orange),
                title: Text('PM-KISAN'),
                subtitle: Text('Application under review'),
              ),
              ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('Soil Health Card'),
                subtitle: Text('Approved - Card issued'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}