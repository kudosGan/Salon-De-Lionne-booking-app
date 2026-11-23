// One-time helper that shrinks big photos so the app loads fast on phones.
//
// Run from the project folder:  dart run tool/optimize_images.dart
//
// The original files are moved to design_source/ (NOT bundled in the app),
// and a smaller copy is written to the same place in assets/.
import 'dart:io';
import 'package:image/image.dart' as img;

class Job {
  final String path; // file inside the project
  final int maxWidth;
  final bool toJpg; // false keeps PNG (needed for logos with transparency)
  const Job(this.path, this.maxWidth, {this.toJpg = true});
}

const jobs = [
  Job('assets/images/backgrounds/landing_bg.png', 1600),
  Job('assets/images/hairstyles/balayage.png', 1000),
  Job('assets/images/logo/logo.png', 600, toJpg: false),
];

void main() {
  final backup = Directory('design_source')..createSync();
  for (final job in jobs) {
    final file = File(job.path);
    if (!file.existsSync()) {
      stdout.writeln('skip (not found): ${job.path}');
      continue;
    }
    final before = file.lengthSync();
    final original = img.decodeImage(file.readAsBytesSync());
    if (original == null) {
      stdout.writeln('skip (cannot read): ${job.path}');
      continue;
    }
    final small = original.width > job.maxWidth
        ? img.copyResize(original,
            width: job.maxWidth, interpolation: img.Interpolation.cubic)
        : original;

    final name = file.uri.pathSegments.last;
    // Keep the untouched original safe.
    final saved = File('${backup.path}/$name');
    if (!saved.existsSync()) file.copySync(saved.path);

    final List<int> out;
    final String outPath;
    if (job.toJpg) {
      out = img.encodeJpg(small, quality: 82);
      outPath = job.path.replaceAll(RegExp(r'\.png$'), '.jpg');
    } else {
      out = img.encodePng(small, level: 9);
      outPath = job.path;
    }
    File(outPath).writeAsBytesSync(out);
    if (outPath != job.path) file.deleteSync();

    stdout.writeln(
        '$outPath: ${(before / 1024).round()} KB -> ${(out.length / 1024).round()} KB '
        '(${original.width}x${original.height} -> ${small.width}x${small.height})');
  }
}
