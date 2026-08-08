import 'dart:io';

import 'package:video_player/video_player.dart';

/// Native: galeriden seçilen videonun YEREL dosyasını oynatır
/// (`VideoPlayerController.file` yalnız dart:io olan platformlarda var).
VideoPlayerController? yerelVideo(String yol) =>
    VideoPlayerController.file(File(yol));
