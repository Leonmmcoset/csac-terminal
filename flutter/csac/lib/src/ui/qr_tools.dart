part of '../../main.dart';

const _sharedQrImageSize = 1024.0;

Future<Uint8List> renderCsacQrPng(String link) async {
  final painter = QrPainter(
    data: link,
    version: QrVersions.auto,
    errorCorrectionLevel: QrErrorCorrectLevel.M,
    gapless: true,
  );
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, _sharedQrImageSize, _sharedQrImageSize),
    ui.Paint()..color = Colors.white,
  );
  painter.paint(canvas, const ui.Size.square(_sharedQrImageSize));
  final image = await recorder.endRecording().toImage(
    _sharedQrImageSize.toInt(),
    _sharedQrImageSize.toInt(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List() ?? Uint8List(0);
}

Future<void> shareCsacQrPng(
  BuildContext context, {
  required String link,
  required String title,
  required String subject,
  required String fileName,
}) async {
  final renderObject = context.findRenderObject();
  final box = renderObject is RenderBox ? renderObject : null;
  final bytes = await renderCsacQrPng(link);
  if (bytes.isEmpty) {
    throw StateError('QR image is empty');
  }
  await SharePlus.instance.share(
    ShareParams(
      title: title,
      subject: subject,
      text: link,
      files: [XFile.fromData(bytes, name: fileName, mimeType: 'image/png')],
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    ),
  );
}

String? firstQrBarcodeValue(BarcodeCapture? capture) {
  if (capture == null) {
    return null;
  }
  for (final barcode in capture.barcodes) {
    final value = (barcode.rawValue ?? barcode.displayValue ?? '').trim();
    if (value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

Future<String?> firstQrValueInImagePath(
  String path, {
  MobileScannerController? scanner,
}) async {
  final ownsScanner = scanner == null;
  final activeScanner =
      scanner ??
      MobileScannerController(
        autoStart: false,
        formats: const [BarcodeFormat.qrCode],
      );
  try {
    final capture = await activeScanner.analyzeImage(
      path,
      formats: const [BarcodeFormat.qrCode],
    );
    return firstQrBarcodeValue(capture);
  } finally {
    if (ownsScanner) {
      unawaited(activeScanner.dispose());
    }
  }
}

Future<String> cacheQrScanImageUrl(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('HTTP ${response.statusCode}');
  }
  return writeTemporaryQrScanImage(
    response.bodyBytes,
    Uri.tryParse(url)?.path ?? 'image.png',
  );
}

class UserQrScreen extends StatefulWidget {
  const UserQrScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<UserQrScreen> createState() => _UserQrScreenState();
}

class _UserQrScreenState extends State<UserQrScreen> {
  bool sharing = false;

  CsacUser? get user => widget.state.user;

  String get profileLink {
    final uid = user?.uid ?? 0;
    return uid <= 0 ? '' : csacUserProfileDeepLink(uid);
  }

  Future<void> copyLink() async {
    final link = profileLink;
    if (link.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Profile link copied.'))),
      );
    }
  }

  Future<void> shareQr() async {
    final link = profileLink;
    final current = user;
    if (link.isEmpty || current == null || sharing) {
      return;
    }
    setState(() => sharing = true);
    final strings = context.strings;
    try {
      await shareCsacQrPng(
        context,
        link: link,
        title: strings.text('Share my user QR code'),
        subject: strings.text('CsAC user QR code'),
        fileName: 'csac-user-${current.uid}.png',
      );
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.strings.format('Share failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => sharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = Theme.of(context).colorScheme;
    final current = user;
    final link = profileLink;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('My QR code'))),
      body: SafeArea(
        child: current == null || link.isEmpty
            ? _EmptyPanel(message: strings.text('Not logged in'))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          _Avatar(
                            url: widget.state.currentUserAvatar,
                            fallback: Icons.person_rounded,
                            radius: 34,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            current.nickname,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'UID ${current.uid}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 18),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.outlineVariant),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: QrImageView(
                                data: link,
                                version: QrVersions.auto,
                                errorCorrectionLevel: QrErrorCorrectLevel.M,
                                size: 220,
                                backgroundColor: Colors.white,
                                semanticsLabel: strings.text(
                                  'My CsAC user profile QR code',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SelectableText(
                            link,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontFamily: 'monospace',
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: sharing ? null : shareQr,
                    icon: sharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.ios_share_outlined),
                    label: Text(strings.text('Share QR code')),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: copyLink,
                    icon: const Icon(Icons.link),
                    label: Text(strings.text('Copy profile link')),
                  ),
                ],
              ),
      ),
    );
  }
}

class GroupQrScreen extends StatefulWidget {
  const GroupQrScreen({super.key, required this.group});

  final GroupProfile group;

  @override
  State<GroupQrScreen> createState() => _GroupQrScreenState();
}

class _GroupQrScreenState extends State<GroupQrScreen> {
  bool sharing = false;

  String get groupLink => csacGroupChatDeepLink(widget.group.id);

  Future<void> copyLink() async {
    final link = groupLink;
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Group link copied.'))),
      );
    }
  }

  Future<void> shareQr() async {
    final group = widget.group;
    if (sharing) {
      return;
    }
    setState(() => sharing = true);
    final strings = context.strings;
    try {
      await shareCsacQrPng(
        context,
        link: groupLink,
        title: strings.text('Share group QR code'),
        subject: strings.text('CsAC group QR code'),
        fileName: 'csac-group-${group.id}.png',
      );
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.strings.format('Share failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => sharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = Theme.of(context).colorScheme;
    final group = widget.group;
    final link = groupLink;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('Group QR code'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _Avatar(
                      url: group.avatar,
                      fallback: Icons.groups_rounded,
                      radius: 34,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      group.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.format('Room {id}', {'id': group.id}),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      strings.text('Scan to open this group chat in CsAC.'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: QrImageView(
                          data: link,
                          version: QrVersions.auto,
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                          size: 220,
                          backgroundColor: Colors.white,
                          semanticsLabel: strings.text('CsAC group QR code'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      link,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: sharing ? null : shareQr,
              icon: sharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_outlined),
              label: Text(strings.text('Share QR code')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: copyLink,
              icon: const Icon(Icons.link),
              label: Text(strings.text('Copy group link')),
            ),
          ],
        ),
      ),
    );
  }
}

class CsacQrScannerScreen extends StatefulWidget {
  const CsacQrScannerScreen({super.key});

  @override
  State<CsacQrScannerScreen> createState() => _CsacQrScannerScreenState();
}

class _CsacQrScannerScreenState extends State<CsacQrScannerScreen> {
  late final MobileScannerController controller;
  bool handling = false;
  bool pickingImage = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    unawaited(controller.dispose());
    super.dispose();
  }

  void showInvalidQrSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.strings.text('This is not a CsAC QR code.')),
      ),
    );
  }

  bool handleScannedValue(String value, {bool showInvalid = true}) {
    final uri = Uri.tryParse(value);
    if (uri == null || !isCsacDeepLink(uri)) {
      if (showInvalid) {
        showInvalidQrSnack();
      }
      return false;
    }
    Navigator.of(context).pop(uri);
    return true;
  }

  Future<void> restartAfterInvalidScan() async {
    showInvalidQrSnack();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      return;
    }
    setState(() => handling = false);
    unawaited(controller.start());
  }

  void handleDetect(BarcodeCapture capture) {
    if (handling) {
      return;
    }
    final value = firstQrBarcodeValue(capture);
    if (value == null) {
      return;
    }
    setState(() => handling = true);
    unawaited(controller.stop());
    if (!handleScannedValue(value, showInvalid: false)) {
      unawaited(restartAfterInvalidScan());
    }
  }

  Future<void> pickImageQr() async {
    if (pickingImage || handling) {
      return;
    }
    setState(() => pickingImage = true);
    var stoppedCamera = false;
    var completed = false;
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) {
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() => handling = true);
      await controller.stop();
      stoppedCamera = true;
      final value = await firstQrValueInImagePath(
        picked.path,
        scanner: controller,
      );
      if (!mounted) {
        return;
      }
      if (value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.strings.text('No QR code found in this image.'),
            ),
          ),
        );
        return;
      }
      completed = handleScannedValue(value);
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.strings.format('QR scan failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    } finally {
      if (mounted && !completed) {
        setState(() {
          pickingImage = false;
          handling = false;
        });
        if (stoppedCamera) {
          unawaited(controller.start());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = Theme.of(context).colorScheme;
    if (!isMobilePlatform) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.text('Scan QR code'))),
        body: _EmptyPanel(
          message: strings.text('QR scanning is only available on mobile.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.text('Scan QR code')),
        actions: [
          IconButton(
            tooltip: strings.text('Choose from album'),
            onPressed: pickingImage || handling ? null : pickImageQr,
            icon: pickingImage
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_library_outlined),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: controller, onDetect: handleDetect),
          Center(
            child: IgnorePointer(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              color: Colors.black.withValues(alpha: 0.62),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner, color: colors.primaryContainer),
                  const SizedBox(height: 8),
                  Text(
                    strings.text(
                      'Scan a CsAC user or group QR code or link QR code',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strings.text('Only CsAC URL scheme links will be opened.'),
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          if (handling)
            const Center(
              child: SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

Future<Uri?> openCsacQrScanner(BuildContext context) {
  return Navigator.of(context).push<Uri>(
    MaterialPageRoute<Uri>(builder: (_) => const CsacQrScannerScreen()),
  );
}
