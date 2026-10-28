import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String kUrl = 'http://172.20.10.4:5000/mobile';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: WebPage(),
      );
}

class WebPage extends StatefulWidget {
  const WebPage({super.key});
  @override
  State<WebPage> createState() => _WebPageState();
}

class _WebPageState extends State<WebPage> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(kUrl));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: WebViewWidget(controller: controller)),
      );
}