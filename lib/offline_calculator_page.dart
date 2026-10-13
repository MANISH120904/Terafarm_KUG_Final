import 'package:flutter/material.dart';

class OfflineCalculatorPage extends StatefulWidget {
  const OfflineCalculatorPage({Key? key}) : super(key: key);

  @override
  _OfflineCalculatorPageState createState() => _OfflineCalculatorPageState();
}

class _OfflineCalculatorPageState extends State<OfflineCalculatorPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCrop;
  String? _selectedStage;
  final TextEditingController _areaController = TextEditingController();
  String _waterResult = '';
  String _fertilizerResult = '';

  final List<String> _crops = ['Tomato', 'Beans', 'Onion', 'Strawberry'];
  final List<String> _stages = ['Seedling', 'Flowering', 'Fruiting'];

  void _calculate() {
    if (_formKey.currentState!.validate()) {
      double area = double.tryParse(_areaController.text) ?? 1.0;
      
      // Placeholder calculations. In a real app, this data would come from the Agri-Pack.
      setState(() {
        _waterResult = 'For a $area acre plot of $_selectedCrop at the $_selectedStage stage, apply approximately ${(area * 1500).toStringAsFixed(0)} liters of water today.';
        _fertilizerResult = 'Recommended: Apply ${(area * 2).toStringAsFixed(1)} kg of a balanced NPK fertilizer (10-10-10) this week.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Calculators'),
        backgroundColor: const Color(0xFF246B40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedCrop,
                hint: const Text('Select Crop'),
                items: _crops.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setState(() => _selectedCrop = val),
                validator: (val) => val == null ? 'Please select a crop' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedStage,
                hint: const Text('Select Growth Stage'),
                items: _stages.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setState(() => _selectedStage = val),
                validator: (val) => val == null ? 'Please select a stage' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _areaController,
                decoration: const InputDecoration(labelText: 'Farm Area (in acres)'),
                keyboardType: TextInputType.number,
                validator: (val) => val == null || val.isEmpty ? 'Please enter area' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _calculate,
                child: const Text('Calculate'),
              ),
              const SizedBox(height: 24),
              if (_waterResult.isNotEmpty) ...[
                const Text('Watering Advice:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(_waterResult),
                const SizedBox(height: 16),
                const Text('Fertilizer Advice:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(_fertilizerResult),
              ]
            ],
          ),
        ),
      ),
    );
  }
}