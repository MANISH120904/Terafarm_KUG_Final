import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme/tera_farm_theme.dart';
import 'widgets/tera_farm_scaffold.dart';

class SubsidiesPage extends StatefulWidget {
  const SubsidiesPage({super.key});

  @override
  State<SubsidiesPage> createState() => _SubsidiesPageState();
}

class _SubsidiesPageState extends State<SubsidiesPage> {
  final List<Map<String, dynamic>> subsidies = [
    {
      'title': 'Pradhan Mantri Kisan Samman Nidhi',
      'description':
          'Direct income support of ₹6,000 per year to small and marginal farmers',
      'eligibility':
          'Small and marginal farmer families with cultivable land up to 2 hectares',
      'amount': '₹6,000 per year',
      'status': 'Active',
      'applyUrl': 'https://pmkisan.gov.in/',
      'infoUrl': 'https://pmkisan.gov.in/',
    },
    {
      'title': 'Kisan Credit Card (KCC)',
      'description':
          'Credit facility for farmers to meet production credit and investment credit requirements',
      'eligibility':
          'All farmers including tenant farmers, sharecroppers, and oral lessees',
      'amount': 'Up to ₹3 lakh at 4% interest',
      'status': 'Active',
      'applyUrl': 'https://www.myscheme.gov.in/schemes/kcc',
      'infoUrl': 'https://www.myscheme.gov.in/schemes/kcc',
    },
    {
      'title': 'Pradhan Mantri Fasal Bima Yojana',
      'description':
          'Crop insurance scheme providing financial support to farmers in case of crop failure',
      'eligibility': 'All farmers growing notified crops in notified areas',
      'amount': 'Premium subsidy up to 2% for Kharif and 1.5% for Rabi crops',
      'status': 'Active',
      'applyUrl': 'https://pmfby.gov.in/',
      'infoUrl': 'https://pmfby.gov.in/',
    },
    {
      'title': 'Soil Health Card Scheme',
      'description':
          'Provides soil health cards to farmers with recommendations for appropriate nutrients',
      'eligibility': 'All farmers across the country',
      'amount': 'Free soil testing and recommendations',
      'status': 'Active',
      'applyUrl': 'https://www.soilhealth.dac.gov.in/',
      'infoUrl': 'https://www.soilhealth.dac.gov.in/',
    },
    {
      'title': 'National Agriculture Market (e-NAM)',
      'description': 'Online trading platform for agricultural commodities',
      'eligibility': 'Farmers, traders, and buyers registered on the platform',
      'amount': 'Transparent price discovery and better market access',
      'status': 'Active',
      'applyUrl': 'https://www.enam.gov.in/',
      'infoUrl': 'https://www.enam.gov.in/',
    },
  ];

  Future<void> _openOfficialUrl(String url, {String? label}) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid application link')),
      );
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open ${label ?? 'portal'}. Open manually: $url',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open browser: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TeraFarmScaffold(
      mode: TeraFarmScaffoldMode.inner,
      title: 'Subsidies & Schemes',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: subsidy['status'] == 'Active'
                      ? TeraFarmColors.primary
                      : Colors.orange,
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
                                _showApplicationDialog(context, subsidy);
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

  void _showApplicationDialog(
    BuildContext context,
    Map<String, dynamic> subsidy,
  ) {
    final subsidyName = subsidy['title'] as String;
    final applyUrl = subsidy['applyUrl'] as String;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Apply for $subsidyName'),
          content: Text(
            'This opens the official portal:\n$applyUrl\n\n'
            'Keep Aadhaar, bank, and land documents ready.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _openOfficialUrl(applyUrl, label: subsidyName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Open Official Site'),
            ),
          ],
        );
      },
    );
  }

  void _showMoreInfoDialog(BuildContext context, Map<String, dynamic> subsidy) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
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
                  'Official portal:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(subsidy['infoUrl'] ?? subsidy['applyUrl'] ?? ''),
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
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final url =
                    (subsidy['infoUrl'] ?? subsidy['applyUrl']) as String;
                await _openOfficialUrl(url, label: subsidy['title'] as String);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Visit Site'),
            ),
          ],
        );
      },
    );
  }

  void _showApplicationStatus(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Quick links'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.open_in_new, color: Colors.green),
                title: const Text('PM-KISAN portal'),
                subtitle: const Text('Check application status'),
                onTap: () async {
                  Navigator.of(dialogContext).pop();
                  await _openOfficialUrl('https://pmkisan.gov.in/');
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new, color: Colors.green),
                title: const Text('myScheme.gov.in'),
                subtitle: const Text('Browse all farmer schemes'),
                onTap: () async {
                  Navigator.of(dialogContext).pop();
                  await _openOfficialUrl('https://www.myscheme.gov.in/');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
