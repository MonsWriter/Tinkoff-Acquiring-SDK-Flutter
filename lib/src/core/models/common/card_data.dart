import 'package:json_annotation/json_annotation.dart';

import '../../constants.dart';
import '../../utils/crypto_utils.dart';

/// Данные карты
///
/// [CardData](https://oplata.tinkoff.ru/develop/api/payments/finishAuthorize-request/#CardData)
class CardData {
  /// Создает экземпляр данных кард
  CardData(
    this.pan,
    this.expDate,
    this.cvv, {
    this.cardHolder,
    this.eci,
    this.cavv,
  });

  /// Номер карты
  @JsonKey(name: JsonKeys.pan)
  final int pan;

  /// Месяц и год срока действия карты
  ///
  /// В формате MMYY
  @JsonKey(name: JsonKeys.expDate)
  final String expDate;

  /// Имя и фамилия держателя карты (как на карте)
  @JsonKey(name: JsonKeys.cardHolder)
  final String cardHolder;

  /// Код защиты
  @JsonKey(name: JsonKeys.cvv)
  final String cvv;

  /// Electronic Commerce Indicator.
  /// Индикатор, показывающий степень защиты, применяемую при предоставлении покупателем своих данных ТСП.
  ///
  /// Используется и является обязательным для Apple Pay или Google Pay.
  @JsonKey(name: JsonKeys.eci)
  final String eci;

  /// Cardholder Authentication Verification Value или Accountholder Authentication Value.
  ///
  /// Используется и является обязательным для Apple Pay или Google Pay
  @JsonKey(name: JsonKeys.cavv)
  final String cavv;

  @override
  String toString() {
    return 'CardData{pan: $pan, expDate: $expDate, cardHolder: $cardHolder, cvv: $cvv, eci: $eci, cavv: $cavv}';
  }

  /// Метод шифрует данные карты
  String encode(String publicKey) {
    final String mergedData =
        '${JsonKeys.pan}=$pan;${JsonKeys.expDate}=$expDate;${JsonKeys.cardHolder}=$cardHolder;${JsonKeys.cvv}=$cvv';

    return CryptoUtils.base64(CryptoUtils.rsa(mergedData, publicKey));
  }
}