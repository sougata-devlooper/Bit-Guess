import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/logo.png');
  if (!file.existsSync()) {
    print('logo.png not found');
    return;
  }
  
  final original = img.decodeImage(file.readAsBytesSync());
  if (original == null) {
    print('failed to decode');
    return;
  }
  int newWidth = (original.width * 1.1).toInt();
  int newHeight = (original.height * 1.1).toInt();
  
  final padded = img.Image(width: newWidth, height: newHeight);
  
  int dstX = (newWidth - original.width) ~/ 2;
  int dstY = (newHeight - original.height) ~/ 2;
  
  img.compositeImage(padded, original, dstX: dstX, dstY: dstY);
  
  File('assets/logo_padded.png').writeAsBytesSync(img.encodePng(padded));
  print('Saved logo_padded.png');
}
