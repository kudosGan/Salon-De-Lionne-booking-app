import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models.dart';

/// Lets the client upload their own hairstyle reference photos.
class ReferencePhotosField extends StatelessWidget {
  final List<ReferencePhoto> photos;
  final ValueChanged<List<ReferencePhoto>> onChanged;

  const ReferencePhotosField({
    super.key,
    required this.photos,
    required this.onChanged,
  });

  static const maxPhotos = 5;

  Future<void> _pick(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final files = await ImagePicker()
          .pickMultiImage(imageQuality: 80, maxWidth: 1600);
      if (files.isEmpty) return;
      final added = <ReferencePhoto>[];
      for (final f in files) {
        added.add(ReferencePhoto(f.name, await f.readAsBytes()));
      }
      final all = [...photos, ...added];
      if (all.length > maxPhotos) {
        messenger.showSnackBar(
            const SnackBar(content: Text('You can add up to 5 photos.')));
      }
      onChanged(all.take(maxPhotos).toList());
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not open your photos.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < photos.length; i++)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(photos[i].bytes,
                        width: 86, height: 86, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => onChanged([...photos]..removeAt(i)),
                      child: const CircleAvatar(
                        radius: 11,
                        backgroundColor: AppColors.charcoal,
                        child:
                            Icon(Icons.close, size: 14, color: AppColors.white),
                      ),
                    ),
                  ),
                ],
              ),
            if (photos.length < maxPhotos)
              InkWell(
                onTap: () => _pick(context),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: AppColors.blush,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.softPink),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          color: AppColors.brown),
                      SizedBox(height: 4),
                      Text('Add photo',
                          style: TextStyle(fontSize: 12, color: AppColors.brown)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
