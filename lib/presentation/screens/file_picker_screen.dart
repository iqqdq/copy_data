import 'dart:io';

import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../core/core.dart';
import '../widgets/file_item.dart';

class FilePickerScreen extends StatefulWidget {
  const FilePickerScreen({super.key});

  @override
  State<FilePickerScreen> createState() => _FilePickerScreenState();
}

class _FilePickerScreenState extends State<FilePickerScreen> {
  final List<FileInfo> _selectedFiles = [];
  bool _isLoading = false;

  Future<void> _pickFiles() async {
    try {
      setState(() => _isLoading = true);

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        final newFiles = <FileInfo>[];

        for (final platformFile in result.files) {
          final file = File(platformFile.path!);

          if (FileUtils.isSupportedFile(file.path)) {
            final fileInfo = await FileUtils.createFileInfo(file);
            newFiles.add(fileInfo);
          }
        }

        setState(() {
          _selectedFiles.addAll(newFiles);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка выбора файлов: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _removeFile(String fileId) {
    setState(() {
      _selectedFiles.removeWhere((file) => file.id == fileId);
    });
  }

  void _saveAndReturn() {
    final service = Provider.of<FileTransferService>(context, listen: false);
    service.addFiles(_selectedFiles);
    Navigator.pop(context);
  }

  int get _totalSize {
    return _selectedFiles.fold(0, (sum, file) => sum + file.size);
  }

  @override
  Widget build(BuildContext context) {
    final totalSize = (_totalSize / (1024 * 1024)).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: Text('Выбор файлов'),
        actions: [
          if (_selectedFiles.isNotEmpty)
            TextButton(
              onPressed: _saveAndReturn,
              child: Text('Готово', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Информационная панель
          if (_selectedFiles.isNotEmpty)
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.blue[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_selectedFiles.length} файлов выбрано',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text('Общий размер: $totalSize MB'),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.clear_all),
                    onPressed: () => setState(() => _selectedFiles.clear()),
                    tooltip: 'Очистить все',
                  ),
                ],
              ),
            ),

          // Список файлов или состояние пустоты
          Expanded(
            child: _selectedFiles.isEmpty
                ? _buildEmptyState()
                : _buildFileList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickFiles,
        icon: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(Icons.add),
        label: Text(_isLoading ? 'Загрузка...' : 'Выбрать файлы'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 100, color: Colors.grey[300]),
          SizedBox(height: 20),
          Text(
            'Нет выбранных файлов',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[500],
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              'Нажмите кнопку ниже, чтобы выбрать файлы для отправки',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          SizedBox(height: 30),
          ElevatedButton.icon(
            icon: Icon(Icons.explore),
            label: Text('Просмотреть файлы'),
            onPressed: _pickFiles,
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: _selectedFiles.length,
      itemBuilder: (context, index) {
        final file = _selectedFiles[index];
        return FileItem(
          file: file,
          onRemove: () => _removeFile(file.id),
          showProgress: false,
        );
      },
    );
  }
}
