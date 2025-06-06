import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:task_tracker/models/task_validate.dart';
import 'package:task_tracker/screens/correction_screen.dart';
import 'package:task_tracker/widgets/customPlayer.dart';

import '../models/task.dart';
import '../models/task_status.dart';
import '../services/request_operation.dart';
import '../task_screens/TaskDescriptionTab.dart';

class TaskValidateDetailsScreen extends StatelessWidget {
  final TaskValidate validate;
  final Task task;

  const TaskValidateDetailsScreen({super.key, required this.validate, required this.task});

  bool _isImage(String fileName) {
    return fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') || fileName.endsWith('.png');
  }

  bool _isVideo(String fileName) {
    return fileName.endsWith('.mp4') || fileName.endsWith('.mov');
  }

  Future<Uint8List?> _generateThumbnail(String videoUrl) async {
    return await VideoThumbnail.thumbnailData(
      video: videoUrl,
      imageFormat: ImageFormat.PNG,
      maxWidth: 128,
      quality: 75,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Проверка задачи'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ссылка',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              validate.link ?? 'Нет ссылки',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Описание',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              validate.description ?? 'Нет описания',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text('Фотографии', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${validate.attachments?.where((file) => _isImage(file)).length ?? 0}',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (validate.attachments?.where((file) => _isImage(file)).isEmpty ?? true)
              const Text('Нет фотографий')
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                ),
                itemCount: validate.attachments!.where((file) => _isImage(file)).length,
                itemBuilder: (context, index) {
                  final photo = validate.attachments!.where((file) => _isImage(file)).toList()[index];
                  return GestureDetector(
                    onTap: () => _openPhotoGallery(
                      context,
                      index,
                      validate.attachments!.where((file) => _isImage(file)).toList(),
                    ),
                    child: Hero(
                      tag: 'correction_photo_$index',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Container(
                          color: Colors.white,
                          child: Image.network(
                            RequestService().getAttachment(photo),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image, size: 32),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            Text('Аудиозаписи', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (validate.audioMessage != null)
              Container(
                color: Colors.white,
                child: AudioPlayerWidget(
                  audioUrl: RequestService().getValidateAttachment(validate.audioMessage!),
                ),
              )
            else
              const Text('Нет аудиозаписей'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text('Видео', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${validate.videoMessage?.where((file) => _isVideo(file)).length ?? 0}',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (validate.videoMessage?.where((file) => _isVideo(file)).isEmpty ?? true)
              const Text('Нет видео')
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                ),
                itemCount: validate.videoMessage!.where((file) => _isVideo(file)).length,
                itemBuilder: (context, index) {
                  final video = validate.videoMessage!.where((file) => _isVideo(file)).toList()[index];
                  final videoUrl = RequestService().getValidateAttachment(video);

                  return FutureBuilder<Uint8List?>(
                    future: _generateThumbnail(videoUrl),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          color: Colors.white,
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError || snapshot.data == null) {
                        return Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, size: 32),
                        );
                      }
                      return GestureDetector(
                        onTap: () => _openVideoGallery(
                          context,
                          index,
                          validate.videoMessage!.where((file) => _isVideo(file)).toList(),
                        ),
                        child: Container(
                          color: Colors.white,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                              const Icon(
                                Iconsax.play_circle,
                                color: Color(0xFF049FFF),
                                size: 48.0,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ElevatedButton(
            onPressed: () {
              RequestService().updateValidate(validate..isDone = true);
              task.changeStatus(TaskStatus.completed);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              side: BorderSide(color: Colors.orange, width: 1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 8),
                Text(
                  'Принять',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => CorrectionScreen(task: task, validate: validate)));
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.orange, width: 1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 8),
                Text(
                  'Отправить на доработку',
                  style: TextStyle(color: Colors.black, fontSize: 16),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  void _openPhotoGallery(BuildContext context, int initialIndex, List<String> files) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoGalleryScreen(
          photos: files.map(RequestService().getAttachment).toList(),
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _openVideoGallery(BuildContext context, int initialIndex, List<String> videoUrls) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoGalleryScreen(
          videoUrls: videoUrls.map(RequestService().getValidateAttachment).toList(),
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}