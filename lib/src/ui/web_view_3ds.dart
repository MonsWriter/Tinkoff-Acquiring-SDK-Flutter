import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:webview_flutter/webview_flutter.dart';

import '../core/constants.dart';
import '../core/tinkoff_acquiring.dart';
import '../core/models/submit_3ds_authorization/submit_3ds_authorization_response.dart';
import '../core/utils/crypto_utils.dart';

/// WebView для прохождения 3-D Secure
class WebView3DS extends StatefulWidget {
  /// Конструктор WebView для прохождения 3-D Secure
  const WebView3DS({
    Key key,
    @required this.onFinished,
    @required this.onLoad,
    @required this.acquiring,
    @required this.is3DsVersion2,
    @required this.acsUrl,
    this.md,
    this.paReq,
    this.acsTransId,
    this.version,
    this.serverTransId,
  })  : assert(onFinished != null),
        assert(onLoad != null),
        assert(acquiring != null),
        assert(is3DsVersion2 != null),
        assert(acsUrl != null),
        super(key: key);

  /// Конфигуратор SDK
  final TinkoffAcquiring acquiring;

  /// URL обработчик на стороне мерчанта, принимающий результаты прохождения 3-D Secure
  final String acsUrl;

  /// Уникальный идентификатор транзакции, присвоенный ACS
  final String acsTransId;

  /// Уникальный идентификатор транзакции в системе Банка (возвращается в ответе на FinishAuthorize)
  final String md;

  /// Результат аутентификации 3-D Secure (возвращается в ответе на FinishAuthorize)
  final String paReq;

  /// Проверка 3DS версии протокола
  final bool is3DsVersion2;

  /// Версия протокола 3DS
  final String version;

  /// Уникальный идентификатор транзакции, генерируемый 3DS-Server,
  /// обязательный параметр для 3DS второй версии
  final String serverTransId;

  /// Результат 3-D Secure
  final void Function(Submit3DSAuthorizationResponse) onFinished;

  /// Загрузка 3-D Secure
  final void Function(bool) onLoad;

  String get _termUrl => Uri.encodeFull((acquiring.debug
          ? NetworkSettings.apiUrlDebug
          : NetworkSettings.apiUrlRelease) +
      (is3DsVersion2
          ? ApiMethods.submit3DSAuthorizationV2
          : ApiMethods.submit3DSAuthorization));

  String get _createCreq {
    final Map<String, String> params = <String, String>{
      WebViewKeys.threeDSServerTransId: serverTransId,
      WebViewKeys.acsTransId: acsTransId,
      WebViewKeys.messageVersion: version,
      WebViewKeys.challengeWindowSize: WebViewSettings.challengeWindowSize,
      WebViewKeys.messageType: WebViewSettings.messageType,
    };

    return CryptoUtils.base64(Uint8List.fromList(jsonEncode(params).codeUnits))
        .trim();
  }

  String get _v1 => '''
      <html>
        <body onload="document.f.submit();">
          <form name="payForm" action="$acsUrl" method="POST">
            <input type="hidden" name="PaReq" value="$paReq">
            <input type="hidden" name="MD" value="$md">
            <input type="hidden" name="TermUrl" value="$_termUrl">
          </form>
          <script>
            window.onload = submitForm;
            function submitForm() { payForm.submit(); }
          </script>
        </body>
      </html>
    ''';

  String get _v2 => '''
      <html>
        <body onload="document.f.submit();">
          <form name="payForm" action="$acsUrl" method="POST">
            <input type="hidden" name="creq" value="$_createCreq">
          </form>
          <script>
            window.onload = submitForm;
            function submitForm() { payForm.submit(); }
          </script>
        </body>
      </html>
    ''';

  @override
  _WebView3DSState createState() => _WebView3DSState();
}

class _WebView3DSState extends State<WebView3DS> {
  final Completer<WebViewController> _controller =
      Completer<WebViewController>();

  @override
  Widget build(BuildContext context) {
    return WebView(
      initialUrl: '',
      gestureNavigationEnabled: true,
      javascriptMode: JavascriptMode.unrestricted,
      onWebViewCreated: (WebViewController webViewController) {
        _controller.complete(webViewController);
        _loadHTML(widget.is3DsVersion2 ? widget._v2 : widget._v1);
      },
      onPageStarted: (String url) {
        if (url == widget._termUrl) {
          widget.onLoad(true);
        }
      },
      onPageFinished: (String url) async {
        // Отмена проверки 3-D Secure
        for (final String action in WebViewSettings.cancelActions) {
          if (url.contains(action)) {
            widget.onFinished(null);
            return;
          }
        }

        if (url == widget._termUrl) {
          await _response();
        } else {
          widget.onLoad(false);
        }
      },
    );
  }

  void _loadHTML(String content) {
    _controller.future.then((WebViewController v) {
      v.loadUrl(Uri.dataFromString(
        content,
        mimeType: 'text/html',
        encoding: Encoding.getByName('utf-8'),
      ).toString());
    });
  }

  Future<void> _response() async {
    final String rawResponse =
        await _controller.future.then((WebViewController v) async {
      final String document =
          await v.evaluateJavascript('document.documentElement.innerHTML');
      final String response = RegExp('{.+}').firstMatch(document).group(0);
      return response.replaceAll(RegExp('\\"').pattern, '"');
    });

    widget.acquiring.logger.log(rawResponse, name: 'RawResponse');

    final Submit3DSAuthorizationResponse response =
        Submit3DSAuthorizationResponse.fromJson(
            jsonDecode(rawResponse) as Map<String, dynamic>);

    widget.acquiring.logger.log(response.toString(), name: 'Response');
    widget.onFinished(response);
  }
}
