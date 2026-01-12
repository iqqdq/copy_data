import 'package:flutter/material.dart';

import '../../core/core.dart';

class FileItem extends StatelessWidget {
  final FileInfo file;
  final VoidCallback? onRemove;
  final VoidCallback? onOpen;
  final bool showProgress;

  const FileItem({
    super.key,
    required this.file,
    this.onRemove,
    this.onOpen,
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: _buildFileIcon(),
        title: Text(
          file.name,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${file.formattedSize} • ${_getFileType(file.mimeType)}'),
            if (showProgress && file.status == FileTransferStatus.transferring)
              _buildProgressBar(),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onOpen != null && file.status == FileTransferStatus.completed)
              IconButton(
                icon: Icon(Icons.open_in_browser, size: 20),
                onPressed: onOpen,
                tooltip: 'Открыть файл',
              ),
            if (onRemove != null)
              IconButton(
                icon: Icon(Icons.close, size: 20),
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileIcon() {
    final icon = FileOpener.getFileIcon(file.path);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _getFileColor(file.mimeType),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: Text(icon, style: TextStyle(fontSize: 20))),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        SizedBox(height: 4),
        LinearProgressIndicator(
          value: file.progress / 100,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
        SizedBox(height: 2),
        Text(
          '${file.progress.toStringAsFixed(1)}%',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  String _getFileType(String mimeType) {
    if (mimeType.startsWith('image/')) return 'Изображение';
    if (mimeType.startsWith('video/')) return 'Видео';
    if (mimeType.startsWith('audio/')) return 'Аудио';
    if (mimeType.contains('pdf')) return 'PDF документ';
    if (mimeType.contains('word')) return 'Word документ';
    if (mimeType.contains('excel')) return 'Excel таблица';
    if (mimeType.contains('zip')) return 'Архив';
    return 'Файл';
  }

  Color _getFileColor(String mimeType) {
    if (mimeType.startsWith('image/')) return Colors.red[100]!;
    if (mimeType.startsWith('video/')) return Colors.purple[100]!;
    if (mimeType.startsWith('audio/')) return Colors.blue[100]!;
    if (mimeType.contains('pdf')) return Colors.red[100]!;
    if (mimeType.contains('office')) return Colors.green[100]!;
    return Colors.grey[200]!;
  }
}
