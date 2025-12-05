# win22jp

Windows Server 2022 を日本語環境にセットアップするための PowerShell スクリプト集です。Azure VM の CustomScriptExtension を利用することで、デプロイ時に自動的に日本語化を実行できます。

## 概要

このリポジトリには、Windows Server 2022 (英語版) を日本語環境に変更するための PowerShell スクリプトが含まれています。以下の設定を自動的に行います：

- 日本語言語パックのインストール
- 日本語フォントのインストール
- 日本語 OCR、手書き認識、音声認識機能の追加
- タイムゾーンの設定（日本標準時）
- システムロケールの変更
- ユーザーロケールとキーボード設定の変更

## 機能

### スクリプトの説明

- **japaneseSetupScript.ps1**: メインスクリプト。CustomScriptExtension から実行され、以下の処理を行います
  - Step1/Step2 スクリプトを永続的なフォルダにコピー
  - タスクスケジューラに再起動後も実行されるタスクを登録
  - 段階的な日本語化処理を開始

- **change-ws2022-lang-ja-step1-noreboot.ps1**: 第一段階の日本語化処理
  - 日本語言語パックのダウンロードとインストール
  - 日本語関連の機能追加
  - タイムゾーンの設定

- **change-ws2022-lang-ja-step2-noreboot.ps1**: 第二段階の日本語化処理
  - システムロケールの設定
  - ユーザーロケールとキーボード設定の変更
  - デフォルトユーザーとシステムアカウントへの設定の適用

## 利用方法

### Azure Bicep での CustomScriptExtension の利用

Azure VM を Bicep でデプロイする際に、CustomScriptExtension を使用して自動的に日本語化を実行できます。

```bicep
resource customScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: vm
  name: 'CustomScriptExtension'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {}
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File japaneseSetupScript.ps1'
      fileUris: [
        // 実環境では、Blob Storage等にアップロードしてご利用ください
        'https://raw.githubusercontent.com/tbuchi888/win22jp/refs/heads/main/scripts/japaneseSetupScript.ps1'
        'https://raw.githubusercontent.com/tbuchi888/win22jp/refs/heads/main/scripts/change-ws2022-lang-ja-step1-noreboot.ps1'
        'https://raw.githubusercontent.com/tbuchi888/win22jp/refs/heads/main/scripts/change-ws2022-lang-ja-step2-noreboot.ps1'
      ]
    }
  }
}
```

### 動作の流れ

1. **初回実行**: `japaneseSetupScript.ps1` が実行され、Step1 スクリプトを実行後、自動的に再起動
2. **再起動後 (1回目)**: タスクスケジューラにより Step2 スクリプトが実行され、再度再起動
3. **再起動後 (2回目)**: 日本語化が完了し、タスクスケジューラのタスクが自動削除

### ログの確認

セットアップログは以下の場所に保存されます：

```
C:\WindowsAzure\Logs\JapaneseSetup\setup.log
```

## 前提条件

- Windows Server 2022 (英語版)
- インターネット接続（言語パックのダウンロードに必要）
- 管理者権限での実行
- Azure 環境での利用を想定（CustomScriptExtension 使用時）

## 重要な注意事項

- ⚠️ **本番環境での利用**: GitHub の raw コンテンツを直接参照するのではなく、スクリプトを Azure Blob Storage などの信頼できるストレージにアップロードしてご利用ください
- ⚠️ **再起動**: セットアップには**2回の自動再起動**が必要です
- ⚠️ **所要時間**: 完了まで約20〜30分かかります（ネットワーク速度により変動）
- ⚠️ **言語パックのダウンロード**: Microsoft の公式サイトから約52MBの言語パックをダウンロードします

## トラブルシューティング

セットアップが正常に完了しない場合は、以下を確認してください：

1. ログファイルの確認: `C:\WindowsAzure\Logs\JapaneseSetup\setup.log`
2. ステータスファイルの確認:
   - `C:\JapaneseLangSetup\step1.done` - Step1 完了の印
   - `C:\JapaneseLangSetup\step2.done` - Step2 完了の印
3. タスクスケジューラで `JapaneseLanguageSetup` タスクの状態を確認

## ライセンス

このプロジェクトは自由に使用できます。Microsoft の言語パックは Microsoft のライセンスに従います。

## 参考情報

- [Windows Server 2022 - Evaluation Center](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2022)
- [Default Input Profiles (Input Locales) in Windows](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/default-input-locales-for-windows-language-packs)
- [Guide to Windows Vista Multilingual User Interface](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-vista/cc721887(v=ws.10))