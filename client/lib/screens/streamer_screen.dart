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

class StreamerScreen extends StatefulWidget {
  const StreamerScreen({super.key});

  @override
  State<StreamerScreen> createState() => _StreamerScreenState();
}

class _StreamerScreenState extends State<StreamerScreen> {
  late WebSocketChannel channel;
  late RTCVideoRenderer _renderer;
  late RTCVideoRenderer _reomteRenderer;
  late MediaStream? _stream;

  late Map<String, RTCPeerConnection> pcs = {};

  @override
  void initState() {
    super.initState();
    _renderer = RTCVideoRenderer();
    _renderer.initialize();
    _reomteRenderer = RTCVideoRenderer();
    _reomteRenderer.initialize();

    connect();
  }

  void initializeListeners() {
    channel.stream.listen((message) async {
      final json = jsonDecode(message);

      if (json['offer'] != null) {
        RTCPeerConnection pc = await getPeerConnection(json["from"]);
        final offer =
            RTCSessionDescription(json['offer']['sdp'], json['offer']['type']);
        pc.setRemoteDescription(offer);

        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        channel.sink
            .add(jsonEncode({"answer": answer.toMap(), "to": json["from"]}));
      }
      if (json['ice'] != null) {
        RTCPeerConnection pc = await getPeerConnection(json["from"]);

        final candidate = RTCIceCandidate(json['ice']['candidate'],
            json['ice']['sdpMid'], json['ice']['sdpMLineIndex']);
        await pc.addCandidate(candidate);
      }
    });
  }

  void connect() async {
    await getMedia();

    channel = WebSocketChannel.connect(Uri.parse('ws://localhost:3001/stream'));
    initializeListeners();
  }

  Future<RTCPeerConnection> getPeerConnection(id) async {
    RTCPeerConnection pc;
    if (pcs[id] == null) {
      pc = await createPeerConnection(config, sdpConstraints);
      if (_stream == null) {
        await getMedia();
      }
      _stream!.getTracks().forEach((track) {
        pc.addTrack(track, _stream!);
      });
      pc.onIceCandidate = (candidate) {
        setState(() {});
        log('onIceCandidate: ${candidate.candidate}');
        channel.sink.add(jsonEncode({"ice": candidate.toMap(), "to": id}));
      };
      pcs[id] = pc;
    } else {
      pc = pcs[id]!;
    }

    return pc;
  }

  Future<void> getMedia() async {
    final mediaConstraints = {'audio': false, 'video': true};
    _stream = await navigator.mediaDevices.getDisplayMedia(mediaConstraints);

    _renderer.srcObject = _stream;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Chzzk with WebRTC"),
      ),
      body: Center(
        child: RTCVideoView(_renderer),
      ),
    );
  }
}
