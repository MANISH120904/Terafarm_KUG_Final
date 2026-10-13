import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({Key? key}) : super(key: key);

  @override
  _QRScannerPageState createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = true;

  // --- Blockchain Configuration using your QuickNode Endpoint ---
  final String _rpcUrl = "https://evocative-few-star.ethereum-sepolia.quiknode.pro/8fb17df7a82f0ea66a655d1d5e97c7cbc0d22e6c/";
  final String _privateKey = "51a5cd39beb3d2b143dac24a1878b860906929df89901b53d369075eab88dd24"; // <-- REPLACE with your private key
  final String _contractAddress = "0xf8171E6EA9b855B38CA57e8E571ca8a36D738a03"; // <-- REPLACE with your contract address

  late Web3Client _web3client;
  late Credentials _credentials;
  late DeployedContract _contract;
  late ContractFunction _deliverOrderFunction;

  @override
  void initState() {
    super.initState();
    _web3client = Web3Client(_rpcUrl, Client());
    _credentials = EthPrivateKey.fromHex(_privateKey);
    _loadContract();
  }

  Future<void> _loadContract() async {
    // The ABI is the same as before. You can copy it from Remix.
    final String abiJson = '''
    [
      {
        "inputs": [
          {
            "internalType": "string",
            "name": "orderId",
            "type": "string"
          }
        ],
        "name": "deliverOrder",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
      },
      {
        "anonymous": false,
        "inputs": [
          {
            "indexed": false,
            "internalType": "string",
            "name": "orderId",
            "type": "string"
          }
        ],
        "name": "OrderDelivered",
        "type": "event"
      },
      {
        "inputs": [
          {
            "internalType": "string",
            "name": "orderId",
            "type": "string"
          }
        ],
        "name": "setOrderPending",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
      },
      {
        "inputs": [
          {
            "internalType": "string",
            "name": "orderId",
            "type": "string"
          }
        ],
        "name": "getOrderStatus",
        "outputs": [
          {
            "internalType": "enum DeliveryVerification.OrderStatus",
            "name": "",
            "type": "uint8"
          }
        ],
        "stateMutability": "view",
        "type": "function"
      },
      {
        "inputs": [
          {
            "internalType": "string",
            "name": "",
            "type": "string"
          }
        ],
        "name": "orderStatuses",
        "outputs": [
          {
            "internalType": "enum DeliveryVerification.OrderStatus",
            "name": "",
            "type": "uint8"
          }
        ],
        "stateMutability": "view",
        "type": "function"
      }
    ]
    ''';

    _contract = DeployedContract(
      ContractAbi.fromJson(abiJson, 'DeliveryVerification'),
      EthereumAddress.fromHex(_contractAddress),
    );

    _deliverOrderFunction = _contract.function('deliverOrder');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan QR Code")),
      body: MobileScanner(
        controller: cameraController,
        onDetect: (capture) {
          if (_isScanning) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                _isScanning = false;
                _verifyAndProcessDelivery(barcode.rawValue!);
                break;
              }
            }
          }
        },
      ),
    );
  }

  Future<void> _verifyAndProcessDelivery(String orderId) async {
    // Ensure user is signed in
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showResultDialog("Error", "User not signed in.");
      return;
    }
    final orderDoc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();

    if (!orderDoc.exists) {
      _showResultDialog("Error", "Invalid Order ID.");
      return;
    }

    final orderData = orderDoc.data() as Map<String, dynamic>;
    // Authorization: ensure current user is the seller of this order
    if (orderData['sellerId'] != currentUser.uid) {
      _showResultDialog("Error", "You are not authorized to confirm this order.");
      return;
    }
    if (orderData['status'] == 'delivered') {
      _showResultDialog("Error", "This order has already been delivered.");
      return;
    }

    try {
      final transactionHash = await _sendDeliveryTransaction(orderId);
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': 'delivered',
        'transactionHash': transactionHash,
      });
      _showResultDialog("Success", "Product delivered! Transaction Hash: $transactionHash");
    } catch (e) {
      _showResultDialog("Error", "Blockchain transaction failed: $e");
    }
  }

  Future<String> _sendDeliveryTransaction(String orderId) async {
    final transaction = Transaction.callContract(
      contract: _contract,
      function: _deliverOrderFunction,
      parameters: [orderId],
    );

    // The chainId for Ethereum Sepolia Testnet is 11155111
    final transactionHash = await _web3client.sendTransaction(
      _credentials,
      transaction,
      chainId: 11155111,
    );

    return transactionHash;
  }

  void _showResultDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _isScanning = true);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}