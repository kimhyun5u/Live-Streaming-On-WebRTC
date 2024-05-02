import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final config = {
  "iceServers": [
    {"urls": "stun:stun.l.google.com:19302"},
    {
      "urls": "turn:api.kimhyun5u.com:3478",
      "username": "username1",
      "credential": "key1"
    }
  ]
};

final sdpConstraints = {
  'mandatory': {
    'OfferToReceiveAudio': true,
    'OfferToReceiveVideo': true,
  },
  'optional': []
};

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key});

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  late WebSocketChannel channel;
  late RTCVideoRenderer _renderer;
  late RTCPeerConnection _pc;
  String id = '';
  @override
  void initState() {
    super.initState();
    _renderer = RTCVideoRenderer();
    _renderer.initialize();

    connect();
  }

  void initializeListeners() {
    channel.stream.listen((message) async {
      final json = jsonDecode(message);
      if (json['joined'] != null) {
        log('joined: ${json['joined']}');
        id = json['joined'];

        sendOffer();
      }
      if (json['answer'] != null) {
        setState(() {});
        final answer = RTCSessionDescription(
            json['answer']['sdp'], json['answer']['type']);
        _pc.setRemoteDescription(answer);
      } else if (json['ice'] != null) {
        final candidate = RTCIceCandidate(json['ice']['candidate'],
            json['ice']['sdpMid'], json['ice']['sdpMLineIndex']);
        _pc.addCandidate(candidate);
      }
    });
  }

  void connect() async {
    channel = WebSocketChannel.connect(Uri.parse('ws://localhost:3001/watch'));
    initializeListeners();
    channel.sink.add(jsonEncode({"join": true}));

    await addPeerConnection();
  }

  Future<void> sendOffer() async {
    RTCSessionDescription offer = await _pc.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    _pc.setLocalDescription(offer);
    channel.sink.add(jsonEncode({"offer": offer.toMap(), "from": id}));
  }

  Future<void> addPeerConnection() async {
    _pc = await createPeerConnection(config, sdpConstraints);
    _pc.onIceCandidate = (candidate) {
      setState(() {});
      log('onIceCandidate: $candidate');
      channel.sink.add(jsonEncode({"ice": candidate.toMap(), "from": id}));
    };
    _pc.onTrack = (event) {
      _renderer.srcObject = event.streams[0];
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("livestreaming with WebRTC"),
      ),
      body: Center(
        child: RTCVideoView(_renderer),
      ),
    );
  }
}
