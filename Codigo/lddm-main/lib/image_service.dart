import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';

class ImageService {
  static final ImageService _instance = ImageService._internal();
  factory ImageService() => _instance;
  ImageService._internal();

  final ImagePicker _imagePicker = ImagePicker();

  /// Seleciona uma imagem da galeria ou câmera
  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source);
      return image;
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao selecionar imagem: $e');
      return null;
    }
  }

  /// Salva a imagem na pasta de documentos do app e retorna o path
  Future<String?> saveImage(XFile imageFile, {String? customName}) async {
    try {
      if (kIsWeb) {
        // Em Web, converte para Base64 corretamente
        final bytes = await imageFile.readAsBytes();
        final base64String = base64Encode(bytes);
        return 'data:image/jpeg;base64,$base64String';
      } else {
        // Em dispositivos nativos, salva no disco
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String imageDirPath = path.join(appDir.path, 'images');
        final Directory imageDir = Directory(imageDirPath);

        // Cria a pasta se não existir
        if (!await imageDir.exists()) {
          await imageDir.create(recursive: true);
        }

        // Define o nome do arquivo
        String fileName = customName ?? 
            'recipe_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
        
        final String imagePath = path.join(imageDirPath, fileName);
        
        // Copia a imagem para a pasta
        await File(imageFile.path).copy(imagePath);
        
        // ignore: avoid_print
        print('✅ Imagem salva em: $imagePath');
        return imagePath;
      }
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao salvar imagem: $e');
      return null;
    }
  }

  /// Deleta a imagem do dispositivo
  Future<bool> deleteImage(String imagePath) async {
    try {
      if (kIsWeb || imagePath.isEmpty) {
        // Em Web, nada a fazer
        return true;
      }

      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        // ignore: avoid_print
        print('✅ Imagem deletada: $imagePath');
        return true;
      }
      return false;
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao deletar imagem: $e');
      return false;
    }
  }
}