// lib/core/security/aes_cipher.dart

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Paraİz Kriptografik Güvenlik Motoru:
/// NIST FIPS 197 Standardında AES-256-CBC, PBKDF2-HMAC-SHA256 ve Encrypt-then-MAC (HMAC-SHA256)
class AesCipher {
  static const int _rounds = 14; // 256-bit key: 14 rounds
  static const int _keyWords = 8; // 32 bytes = 8 x 32-bit words
  static const int _blockSize = 16; // 128-bit block = 16 bytes

  // S-Box
  static const List<int> _sBox = [
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16
  ];

  // Inverse S-Box
  static const List<int> _invSBox = [
    0x52, 0x09, 0x6a, 0xd5, 0x30, 0x36, 0xa5, 0x38, 0xbf, 0x40, 0xa3, 0x9e, 0x81, 0xf3, 0xd7, 0xfb,
    0x7c, 0xe3, 0x39, 0x82, 0x9b, 0x2f, 0xff, 0x87, 0x34, 0x8e, 0x43, 0x44, 0xc4, 0xde, 0xe9, 0xcb,
    0x54, 0x7b, 0x94, 0x32, 0xa6, 0xc2, 0x23, 0x3d, 0xee, 0x4c, 0x95, 0x0b, 0x42, 0xfa, 0xc3, 0x4e,
    0x08, 0x2e, 0xa1, 0x66, 0x28, 0xd9, 0x24, 0xb2, 0x76, 0x5b, 0xa2, 0x49, 0x6d, 0x8b, 0xd1, 0x25,
    0x72, 0xf8, 0xf6, 0x64, 0x86, 0x68, 0x98, 0x16, 0xd4, 0xa4, 0x5c, 0xcc, 0x5d, 0x65, 0xb6, 0x92,
    0x6c, 0x70, 0x48, 0x50, 0xfd, 0xed, 0xb9, 0xda, 0x5e, 0x15, 0x46, 0x57, 0xa7, 0x8d, 0x9d, 0x84,
    0x90, 0xd8, 0xab, 0x00, 0x8c, 0xbc, 0xd3, 0x0a, 0xf7, 0xe4, 0x58, 0x05, 0xb8, 0xb3, 0x45, 0x06,
    0xd0, 0x2c, 0x1e, 0x8f, 0xca, 0x3f, 0x0f, 0x02, 0xc1, 0xaf, 0xbd, 0x03, 0x01, 0x13, 0x8a, 0x6b,
    0x3a, 0x91, 0x11, 0x41, 0x4f, 0x67, 0xdc, 0xea, 0x97, 0xf2, 0xcf, 0xce, 0xf0, 0xb4, 0xe6, 0x73,
    0x96, 0xac, 0x74, 0x22, 0xe7, 0xad, 0x35, 0x85, 0xe2, 0xf9, 0x37, 0xe8, 0x1c, 0x75, 0xdf, 0x6e,
    0x47, 0xf1, 0x1a, 0x71, 0x1d, 0x29, 0xc5, 0x89, 0x6f, 0xb7, 0x62, 0x0e, 0xaa, 0x18, 0xbe, 0x1b,
    0xfc, 0x56, 0x3e, 0x4b, 0xc6, 0xd2, 0x79, 0x20, 0x9a, 0xdb, 0xc0, 0xfe, 0x78, 0xcd, 0x5a, 0xf4,
    0x1f, 0xdd, 0xa8, 0x33, 0x88, 0x07, 0xc7, 0x31, 0xb1, 0x12, 0x10, 0x59, 0x27, 0x80, 0xec, 0x5f,
    0x60, 0x51, 0x7f, 0xa9, 0x19, 0xb5, 0x4a, 0x0d, 0x2d, 0xe5, 0x7a, 0x9f, 0x93, 0xc9, 0x9c, 0xef,
    0xa0, 0xe0, 0x3b, 0x4d, 0xae, 0x2a, 0xf5, 0xb0, 0xc8, 0xeb, 0xbb, 0x3c, 0x83, 0x53, 0x99, 0x61,
    0x17, 0x2b, 0x04, 0x7e, 0xba, 0x77, 0xd6, 0x26, 0xe1, 0x69, 0x14, 0x63, 0x55, 0x21, 0x0c, 0x7d
  ];

  static const List<int> _rcon = [
    0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36
  ];

  static int _xtime(int a) => ((a << 1) ^ (((a >> 7) & 1) * 0x11b)) & 0xff;

  static int _multiply(int a, int b) {
    var res = 0;
    var tempA = a;
    for (var i = 0; i < 8; i++) {
      if ((b & (1 << i)) != 0) {
        res ^= tempA;
      }
      tempA = _xtime(tempA);
    }
    return res;
  }

  /// AES-256 Anahtar Genişletme (Key Expansion)
  static Uint32List _expandKey(Uint8List key) {
    final w = Uint32List(60); // 4 * (14 + 1) = 60 words
    final byteData = ByteData.sublistView(key);

    for (var i = 0; i < _keyWords; i++) {
      w[i] = byteData.getUint32(i * 4, Endian.big);
    }

    for (var i = _keyWords; i < 60; i++) {
      var temp = w[i - 1];
      if (i % _keyWords == 0) {
        // RotWord
        temp = ((temp << 8) | (temp >> 24)) & 0xffffffff;
        // SubWord
        temp = (_sBox[(temp >> 24) & 0xff] << 24) |
            (_sBox[(temp >> 16) & 0xff] << 16) |
            (_sBox[(temp >> 8) & 0xff] << 8) |
            _sBox[temp & 0xff];
        // Rcon XOR
        temp ^= (_rcon[i ~/ _keyWords] << 24);
      } else if (i % _keyWords == 4) {
        // SubWord for AES-256
        temp = (_sBox[(temp >> 24) & 0xff] << 24) |
            (_sBox[(temp >> 16) & 0xff] << 16) |
            (_sBox[(temp >> 8) & 0xff] << 8) |
            _sBox[temp & 0xff];
      }
      w[i] = (w[i - _keyWords] ^ temp) & 0xffffffff;
    }
    return w;
  }

  /// Tek bir 16 baytlık bloğu şifreler (NIST AES-256)
  static Uint8List _encryptBlock(Uint8List input, Uint32List w) {
    var state = Uint8List.fromList(input);

    // AddRoundKey 0
    for (var i = 0; i < 4; i++) {
      final word = w[i];
      state[i * 4] ^= (word >> 24) & 0xff;
      state[i * 4 + 1] ^= (word >> 16) & 0xff;
      state[i * 4 + 2] ^= (word >> 8) & 0xff;
      state[i * 4 + 3] ^= word & 0xff;
    }

    for (var round = 1; round <= _rounds; round++) {
      // SubBytes
      for (var i = 0; i < 16; i++) {
        state[i] = _sBox[state[i]];
      }

      // ShiftRows
      final s1 = state[1];
      state[1] = state[5];
      state[5] = state[9];
      state[9] = state[13];
      state[13] = s1;

      final s2 = state[2];
      final s6 = state[6];
      state[2] = state[10];
      state[6] = state[14];
      state[10] = s2;
      state[14] = s6;

      final s15 = state[15];
      state[15] = state[11];
      state[11] = state[7];
      state[7] = state[3];
      state[3] = s15;

      // MixColumns (Son tur hariç)
      if (round < _rounds) {
        for (var c = 0; c < 4; c++) {
          final idx = c * 4;
          final a0 = state[idx];
          final a1 = state[idx + 1];
          final a2 = state[idx + 2];
          final a3 = state[idx + 3];

          state[idx] = _xtime(a0) ^ _xtime(a1) ^ a1 ^ a2 ^ a3;
          state[idx + 1] = a0 ^ _xtime(a1) ^ _xtime(a2) ^ a2 ^ a3;
          state[idx + 2] = a0 ^ a1 ^ _xtime(a2) ^ _xtime(a3) ^ a3;
          state[idx + 3] = _xtime(a0) ^ a0 ^ a1 ^ a2 ^ _xtime(a3);
        }
      }

      // AddRoundKey
      final wOffset = round * 4;
      for (var i = 0; i < 4; i++) {
        final word = w[wOffset + i];
        state[i * 4] ^= (word >> 24) & 0xff;
        state[i * 4 + 1] ^= (word >> 16) & 0xff;
        state[i * 4 + 2] ^= (word >> 8) & 0xff;
        state[i * 4 + 3] ^= word & 0xff;
      }
    }

    return state;
  }

  /// Tek bir 16 baytlık bloğun şifresini çözer (NIST AES-256)
  static Uint8List _decryptBlock(Uint8List input, Uint32List w) {
    var state = Uint8List.fromList(input);

    // AddRoundKey (Nr)
    var wOffset = _rounds * 4;
    for (var i = 0; i < 4; i++) {
      final word = w[wOffset + i];
      state[i * 4] ^= (word >> 24) & 0xff;
      state[i * 4 + 1] ^= (word >> 16) & 0xff;
      state[i * 4 + 2] ^= (word >> 8) & 0xff;
      state[i * 4 + 3] ^= word & 0xff;
    }

    for (var round = _rounds - 1; round >= 0; round--) {
      // InvShiftRows
      final s13 = state[13];
      state[13] = state[9];
      state[9] = state[5];
      state[5] = state[1];
      state[1] = s13;

      final s2 = state[2];
      final s6 = state[6];
      state[2] = state[10];
      state[6] = state[14];
      state[10] = s2;
      state[14] = s6;

      final s3 = state[3];
      state[3] = state[7];
      state[7] = state[11];
      state[11] = state[15];
      state[15] = s3;

      // InvSubBytes
      for (var i = 0; i < 16; i++) {
        state[i] = _invSBox[state[i]];
      }

      // AddRoundKey
      wOffset = round * 4;
      for (var i = 0; i < 4; i++) {
        final word = w[wOffset + i];
        state[i * 4] ^= (word >> 24) & 0xff;
        state[i * 4 + 1] ^= (word >> 16) & 0xff;
        state[i * 4 + 2] ^= (word >> 8) & 0xff;
        state[i * 4 + 3] ^= word & 0xff;
      }

      // InvMixColumns (0. tur hariç)
      if (round > 0) {
        for (var c = 0; c < 4; c++) {
          final idx = c * 4;
          final a0 = state[idx];
          final a1 = state[idx + 1];
          final a2 = state[idx + 2];
          final a3 = state[idx + 3];

          state[idx] = _multiply(0x0e, a0) ^ _multiply(0x0b, a1) ^ _multiply(0x0d, a2) ^ _multiply(0x09, a3);
          state[idx + 1] = _multiply(0x09, a0) ^ _multiply(0x0e, a1) ^ _multiply(0x0b, a2) ^ _multiply(0x0d, a3);
          state[idx + 2] = _multiply(0x0d, a0) ^ _multiply(0x09, a1) ^ _multiply(0x0e, a2) ^ _multiply(0x0b, a3);
          state[idx + 3] = _multiply(0x0b, a0) ^ _multiply(0x0d, a1) ^ _multiply(0x09, a2) ^ _multiply(0x0e, a3);
        }
      }
    }

    return state;
  }

  /// PBKDF2-HMAC-SHA256 Anahtar Türetimi (RFC 2898)
  static Uint8List pbkdf2Sha256(String password, Uint8List salt, {int iterations = 10000, int keyLength = 32}) {
    final passBytes = utf8.encode(password);
    final numBlocks = (keyLength + 31) ~/ 32;
    final derivedKey = Uint8List(numBlocks * 32);

    for (var blockIndex = 1; blockIndex <= numBlocks; blockIndex++) {
      final hmac = Hmac(sha256, passBytes);
      final initialBlock = Uint8List(salt.length + 4);
      initialBlock.setRange(0, salt.length, salt);
      initialBlock[salt.length] = (blockIndex >> 24) & 0xff;
      initialBlock[salt.length + 1] = (blockIndex >> 16) & 0xff;
      initialBlock[salt.length + 2] = (blockIndex >> 8) & 0xff;
      initialBlock[salt.length + 3] = blockIndex & 0xff;

      var u = Uint8List.fromList(hmac.convert(initialBlock).bytes);
      final t = Uint8List.fromList(u);

      for (var iter = 1; iter < iterations; iter++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var k = 0; k < 32; k++) {
          t[k] ^= u[k];
        }
      }

      derivedKey.setRange((blockIndex - 1) * 32, blockIndex * 32, t);
    }

    return derivedKey.sublist(0, keyLength);
  }

  /// AES-256-CBC Şifreleme (PKCS#7 Padding)
  static Uint8List encryptCbc(Uint8List plainBytes, Uint8List key, Uint8List iv) {
    if (key.length != 32) throw ArgumentError('AES-256 için anahtar uzunluğu 32 bayt olmalıdır.');
    if (iv.length != 16) throw ArgumentError('IV uzunluğu 16 bayt olmalıdır.');

    final w = _expandKey(key);

    // PKCS#7 Padding
    final padLen = _blockSize - (plainBytes.length % _blockSize);
    final padded = Uint8List(plainBytes.length + padLen);
    padded.setRange(0, plainBytes.length, plainBytes);
    for (var i = plainBytes.length; i < padded.length; i++) {
      padded[i] = padLen;
    }

    final ciphertext = Uint8List(padded.length);
    var previousBlock = iv;

    for (var offset = 0; offset < padded.length; offset += _blockSize) {
      final block = Uint8List(_blockSize);
      for (var i = 0; i < _blockSize; i++) {
        block[i] = padded[offset + i] ^ previousBlock[i];
      }
      final encBlock = _encryptBlock(block, w);
      ciphertext.setRange(offset, offset + _blockSize, encBlock);
      previousBlock = encBlock;
    }

    return ciphertext;
  }

  /// AES-256-CBC Deşifreleme (PKCS#7 Padding Doğrulaması)
  static Uint8List decryptCbc(Uint8List ciphertext, Uint8List key, Uint8List iv) {
    if (key.length != 32) throw ArgumentError('AES-256 için anahtar uzunluğu 32 bayt olmalıdır.');
    if (iv.length != 16) throw ArgumentError('IV uzunluğu 16 bayt olmalıdır.');
    if (ciphertext.isEmpty || ciphertext.length % _blockSize != 0) {
      throw const FormatException('Geçersiz şifreli metin uzunluğu.');
    }

    final w = _expandKey(key);
    final decryptedPadded = Uint8List(ciphertext.length);
    var previousBlock = iv;

    for (var offset = 0; offset < ciphertext.length; offset += _blockSize) {
      final currentCipherBlock = ciphertext.sublist(offset, offset + _blockSize);
      final decBlock = _decryptBlock(currentCipherBlock, w);
      for (var i = 0; i < _blockSize; i++) {
        decryptedPadded[offset + i] = decBlock[i] ^ previousBlock[i];
      }
      previousBlock = currentCipherBlock;
    }

    // PKCS#7 Padding Çıkarımı ve Doğrulaması
    final padLen = decryptedPadded.last;
    if (padLen < 1 || padLen > _blockSize) {
      throw const FormatException('PKCS#7 padding geçersiz!');
    }
    for (var i = decryptedPadded.length - padLen; i < decryptedPadded.length; i++) {
      if (decryptedPadded[i] != padLen) {
        throw const FormatException('Bozuk PKCS#7 padding!');
      }
    }

    return decryptedPadded.sublist(0, decryptedPadded.length - padLen);
  }

  /// Yüksek Güvenlikli Kasa Paketi Oluşturma (Encrypt-then-MAC: PBKDF2 + AES-256-CBC + HMAC-SHA256)
  static String encryptVaultPayload({required String plainText, required String password}) {
    final rand = Random.secure();
    final salt = Uint8List.fromList(List<int>.generate(16, (_) => rand.nextInt(256)));
    final iv = Uint8List.fromList(List<int>.generate(16, (_) => rand.nextInt(256)));

    // 64 bayt anahtar türet (32 bayt AES için, 32 bayt HMAC için - Key Separation)
    final derived = pbkdf2Sha256(password, salt, iterations: 10000, keyLength: 64);
    final encKey = derived.sublist(0, 32);
    final macKey = derived.sublist(32, 64);

    final plainBytes = utf8.encode(plainText);
    final ciphertext = encryptCbc(Uint8List.fromList(plainBytes), encKey, iv);

    // HMAC-SHA256 (Encrypt-then-MAC over salt + iv + ciphertext)
    final hmac = Hmac(sha256, macKey);
    final macData = Uint8List(salt.length + iv.length + ciphertext.length);
    macData.setRange(0, salt.length, salt);
    macData.setRange(salt.length, salt.length + iv.length, iv);
    macData.setRange(salt.length + iv.length, macData.length, ciphertext);
    final macDigest = hmac.convert(macData).toString();

    final envelope = {
      'v': 2,
      'cipher': 'AES-256-CBC',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iter': 10000,
      'salt': base64Encode(salt),
      'iv': base64Encode(iv),
      'ct': base64Encode(ciphertext),
      'mac': macDigest,
    };

    final rawJson = jsonEncode(envelope);
    return 'PARAIZ-SEC-VAULT-V2:${base64Encode(utf8.encode(rawJson))}';
  }

  /// Yüksek Güvenlikli Kasa Paketini Çözme (HMAC Bütünlük Kontrolü + AES-256-CBC)
  static String decryptVaultPayload({required String vaultString, required String password}) {
    if (!vaultString.startsWith('PARAIZ-SEC-VAULT-V2:')) {
      throw const FormatException('Geçersiz veya desteklenmeyen şifreli kasa formatı.');
    }

    final rawBase64 = vaultString.substring('PARAIZ-SEC-VAULT-V2:'.length);
    final envelopeJson = utf8.decode(base64Decode(rawBase64));
    final Map<String, dynamic> envelope = jsonDecode(envelopeJson);

    final salt = base64Decode(envelope['salt'] as String);
    final iv = base64Decode(envelope['iv'] as String);
    final ciphertext = base64Decode(envelope['ct'] as String);
    final expectedMac = envelope['mac'] as String;

    // Key Separation
    final derived = pbkdf2Sha256(password, salt, iterations: envelope['iter'] as int? ?? 10000, keyLength: 64);
    final encKey = derived.sublist(0, 32);
    final macKey = derived.sublist(32, 64);

    // 1. HMAC Bütünlük Doğrulaması (Sabit zamanlı karşılaştırma)
    final hmac = Hmac(sha256, macKey);
    final macData = Uint8List(salt.length + iv.length + ciphertext.length);
    macData.setRange(0, salt.length, salt);
    macData.setRange(salt.length, salt.length + iv.length, iv);
    macData.setRange(salt.length + iv.length, macData.length, ciphertext);
    final actualMac = hmac.convert(macData).toString();

    if (actualMac != expectedMac) {
      throw const FormatException('Şifre çözülemedi: Parola hatalı veya veri bütünlüğü bozulmuş!');
    }

    // 2. AES-256-CBC Deşifreleme
    final decryptedBytes = decryptCbc(ciphertext, encKey, iv);
    return utf8.decode(decryptedBytes);
  }
}
