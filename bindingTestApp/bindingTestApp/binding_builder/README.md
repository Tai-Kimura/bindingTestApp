# binding_builder - SwiftJsonUI開発ツール

このプロジェクトは**binding_builderの利用法解説**を目的としたサンプルプロジェクトです。実際のアプリ開発ではなく、binding_builderツールの使い方を理解するためのリファレンス実装です。

## 概要

binding_builderは、SwiftJsonUIを使用したiOSアプリ開発を効率化するための汎用ツールです。JSONレイアウトファイルから自動的にSwiftコードを生成し、UIとロジックのバインディングを自動化します。

## プロジェクト構造

```
bindingTestApp/
├── binding_builder/          # メインツール（汎用）
│   ├── sjui                 # コマンドラインツール
│   ├── xcode_project/       # Xcodeプロジェクト管理
│   │   ├── generators/      # コード生成クラス
│   │   ├── adders/         # Xcodeプロジェクト追加クラス
│   │   ├── setup/          # 初期設定クラス
│   │   └── destroyers/     # ファイル削除クラス
│   └── CLAUDE.md           # 設計方針・制約事項
├── Core/                   # 自動生成されるベースクラス
│   ├── Base/              # BaseViewController, BaseBinding等
│   └── UI/                # UIViewCreator等
├── View/                  # ViewController群
├── Layouts/               # JSONレイアウトファイル群
├── Bindings/              # 自動生成バインディングクラス群
└── Styles/                # スタイル定義群
```

## 主要コンポーネント

### 1. コマンドラインツール (sjui)

```bash
# 初期設定
sjui init      # config.json作成
sjui setup     # ディレクトリ構造とBaseクラス生成

# View開発
sjui g view sample          # Viewファイル群生成
sjui g view splash --root   # ルートViewController指定
sjui d view sample          # Viewファイル群削除

# バインディング生成
sjui build     # JSONからBindingクラス自動生成
```

### 2. 自動生成システム

#### JSONレイアウト → Bindingクラス
```json
// splash.json
{
  "type": "SafeAreaView",
  "id": "main_view",
  "width": "matchParent",
  "height": "matchParent",
  "background": "FFFFFF",
  "child": [
    {
      "type": "Label",
      "id": "title_label",
      "text": "Welcome!",
      "textAlignment": "center"
    }
  ]
}
```

↓ 自動生成

```swift
// SplashBinding.swift
@MainActor
class SplashBinding: BaseBinding {
    weak var mainView: SJUIView!
    weak var titleLabel: SJUILabel!
    
    override func bindView() {
        super.bindView()
        // 自動バインディング処理
    }
}
```

### 3. アーキテクチャパターン

#### ViewController
```swift
class SplashViewController: BaseViewController {
    override var layoutPath: String { "splash" }
    private lazy var _binding = SplashBinding(viewHolder: self)
    override var binding: BaseBinding { _binding }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(UIViewCreator.createView(layoutPath, target: self)!)
        attachViewToProperty()
    }
}
```

#### BaseBinding継承構造
```
Binding (SwiftJsonUI)
└── BaseBinding (共通ベース)
    └── SplashBinding (自動生成)
```

## 実際の利用手順

### 1. 初期セットアップ
```bash
cd binding_builder
./sjui init    # config.json作成
./sjui setup   # 必要ディレクトリとBaseクラス生成
```

### 2. 新しいView作成
```bash
./sjui g view sample
# 以下が自動生成される:
# - View/Sample/SampleViewController.swift
# - Layouts/sample.json
# - Bindings/SampleBinding.swift (buildコマンド実行時)
```

### 3. レイアウト定義
```json
// Layouts/sample.json を編集
{
  "type": "SafeAreaView",
  "id": "main_view",
  "child": [
    {
      "type": "Button", 
      "id": "submit_button",
      "text": "送信",
      "action": "onSubmit"
    }
  ]
}
```

### 4. バインディング生成
```bash
./sjui build
# SampleBinding.swift が自動更新される
```

### 5. ビジネスロジック実装
```swift
// SampleViewController.swift
class SampleViewController: BaseViewController {
    // bindingプロパティで自動生成されたUIにアクセス可能
    override func viewDidLoad() {
        super.viewDidLoad()
        // UIViewCreator.createViewで自動レイアウト
        // _binding.submitButton でUIアクセス可能
    }
}
```

## 汎用性設計

### プロジェクト非依存
- 絶対パス指定なし
- プロジェクト名ハードコード回避
- 動的プロジェクト検索

### 設定ファイル駆動
config.jsonで全体の動作をカスタマイズ可能：

```json
// config.json
{
  "project_file_name": "MyApp",
  "layouts_directory": "Layouts",
  "bindings_directory": "Bindings",
  "view_directory": "View"
}
```

### 自動Xcodeプロジェクト管理
- ファイル作成時の自動プロジェクト追加
- テスト系ターゲット除外
- グループ構造維持

## 主要機能

### AppDelegate自動設定
```swift
// 自動追加される
func application(_:didFinishLaunchingWithOptions:) -> Bool {
    UIViewCreator.prepare()
    UIViewCreator.copyResourcesToDocuments()
    #if DEBUG
    HotLoader.instance.isHotLoadEnabled = true
    #endif
    return true
}
```

### テスト系ターゲット除外
- BindingファイルはメインAppターゲットのみに追加
- テスト重複エラー回避

### HotReload対応（自動設定）
- **完全自動化** - Build Phaseで自動的にNode.jsサーバー起動
- **IP自動検出** - WiFiネットワークのIPアドレスを自動検出・設定
- **レイアウトファイル変更検知** - JSONファイル保存と同時にアプリ更新
- **実機対応** - WiFi経由で実機でも利用可能

## カスタマイズポイント

### BaseBinding拡張
```swift
// サンプル実装（コメントアウト済み）
class BaseBinding: Binding {
    // var isInitialized: Bool = true
    // var naviTitle: String?
    // weak var navi: UIView!
    // weak var titleLabel: SJUILabel!
    
    // func invalidateNavi() { ... }
}
```

### UIViewCreator設定
```swift
class UIViewCreator: SJUIViewCreator {
    class func prepare() {
        // フォント、色などの共通設定
        String.currentLanguage = "ja-JP"
        defaultFont = "System"
        defaultFontSize = 14.0
        // サンプル設定がコメントで記載
    }
}
```

## デバッグ・開発支援

### ビルドキャッシュ
- 更新されたJSONファイルのみ処理
- 高速な増分ビルド

### エラーハンドリング
- 不正なJSON検出
- 重複ファイルチェック
- プロジェクト整合性確認

## config.json設定リファレンス

### 基本設定

```json
{
  "project_name": "MyApp",
  "project_file_name": "MyApp", 
  "source_directory": "",
  "layouts_directory": "Layouts",
  "bindings_directory": "Bindings",
  "view_directory": "View",
  "styles_directory": "Styles",
  "hot_loader_directory": "MyApp"
}
```

#### プロジェクト設定
- **`project_name`**: プロジェクト表示名
- **`project_file_name`**: .xcodeprojファイル名（拡張子なし）
- **`source_directory`**: ソースコードの配置ディレクトリ（空文字列=プロジェクト直下）

#### ディレクトリ設定
- **`layouts_directory`**: JSONレイアウトファイルの配置先
- **`bindings_directory`**: 自動生成Bindingクラスの配置先  
- **`view_directory`**: ViewControllerクラスの配置先
- **`styles_directory`**: スタイル定義ファイルの配置先
- **`hot_loader_directory`**: HotLoadサーバーファイルの配置先（デフォルト: プロジェクト名）

### ビルド設定

```json
{
  "build_settings": {
    "auto_build": false,
    "clean_before_build": false
  }
}
```

- **`auto_build`**: ファイル変更時の自動ビルド有効化
- **`clean_before_build`**: ビルド前のキャッシュクリア

### ジェネレータ設定

```json
{
  "generator_settings": {
    "create_layout_file": true,
    "create_binding_file": true,
    "add_to_xcode_project": true
  }
}
```

- **`create_layout_file`**: JSONレイアウトファイル自動生成
- **`create_binding_file`**: Bindingクラス自動生成
- **`add_to_xcode_project`**: 生成ファイルのXcodeプロジェクト自動追加

### カスタムビュータイプ設定

```json
{
  "custom_view_types": {
    "_comment": "カスタムビュータイプの設定例:",
    "_example": {
      "Map": {
        "class_name": "GMSMapView",
        "import_module": "GoogleMaps"
      }
    }
  }
}
```

サードパーティUIコンポーネントを使用する場合は、`_example`を参考に実際の設定を追加：

```json
{
  "custom_view_types": {
    "Map": {
      "class_name": "GMSMapView",
      "import_module": "GoogleMaps"
    },
    "Chart": {
      "class_name": "LineChartView", 
      "import_module": "Charts"
    },
    "WebView": {
      "class_name": "WKWebView",
      "import_module": "WebKit"
    }
  }
}
```

#### カスタムビュータイプ使用例

JSONレイアウトでの利用：
```json
{
  "type": "SafeAreaView",
  "child": [
    {
      "type": "Map",
      "id": "google_map",
      "width": "matchParent", 
      "height": 200
    }
  ]
}
```

自動生成されるBindingクラス：
```swift
import GoogleMaps  // 自動追加

class SampleBinding: BaseBinding {
    weak var googleMap: GMSMapView!  // 自動生成
}
```

### 設定の優先順位

1. **config.json** - プロジェクト固有設定
2. **デフォルト値** - ConfigManager.DEFAULT_CONFIG
3. **コマンドライン引数** - sjuiコマンドオプション

## HotLoad機能（自動開発サーバー）

### 概要

binding_builderは**完全自動化されたHotLoad機能**を提供します。アプリのDebugビルド時に自動的にNode.jsサーバーが起動し、JSONレイアウトファイルの変更を即座にアプリに反映します。

### 自動設定内容

#### 1. Build Phase自動追加
```bash
# Xcodeビルド時に自動実行されるスクリプト
- IPアドレス自動検出（WiFiネットワーク）
- Info.plistへのIP設定
- Node.jsサーバー自動起動
- レイアウトファイルのシンボリックリンク作成
```

#### 2. AppDelegate自動設定
```swift
func application(_:didFinishLaunchingWithOptions:) -> Bool {
    UIViewCreator.prepare()
    UIViewCreator.copyResourcesToDocuments()
    #if DEBUG
    HotLoader.instance.isHotLoadEnabled = true
    
    // Info.plistからIPアドレス自動取得
    if let serverIP = Bundle.main.object(forInfoDictionaryKey: "HotLoadServerIP") as? String {
        HotLoader.instance.serverURL = "http://\(serverIP):3000"
    }
    #endif
}
```

#### 3. Info.plist自動更新
```xml
<!-- Build時に自動追加 -->
<key>HotLoadServerIP</key>
<string>192.168.1.100</string>  <!-- 検出されたIP -->
```

### 開発ワークフロー

#### 従来の開発サイクル
```
JSONファイル編集 → Xcodeビルド → アプリ起動 → 確認
(約30秒〜1分)
```

#### HotLoad使用時
```
JSONファイル編集 → 自動反映 → 即座確認
(約1〜3秒)
```

### 使用方法

#### 1. 初回セットアップ
```bash
cd binding_builder
./sjui setup  # HotLoad機能も自動設定される
```

#### 2. 開発開始
```bash
# 通常通りXcodeでDebugビルド実行
# → Build Phaseで自動的にHotLoadサーバー起動
# → IPアドレス自動設定
```

#### 3. レイアウト編集
```json
// Layouts/sample.json を編集
{
  "type": "Label",
  "text": "リアルタイム更新テスト",  // ← 保存と同時に反映
  "fontSize": 20
}
```

### 技術詳細

#### Node.jsサーバー
- **ポート**: 3000番（固定）
- **サーバー構成**: 
  - `server.js` - WebSocket/HTTP通信サーバー
  - `layout_loader.js` - JSONファイル変更監視
- **監視対象**: Layoutsディレクトリ内の*.jsonファイル
- **通信**: WebSocket + HTTP
- **起動条件**: Debugビルドのみ

#### ネットワーク要件
- **同一WiFiネットワーク** - Mac（開発マシン）とiOS端末
- **ファイアウォール** - ポート3000番への接続許可

#### 自動検出システム
```bash
# IP検出優先順位
1. WiFiインターフェースのアクティブIP
2. デフォルトルートのインターフェースIP  
3. フォールバック: 192.168.1.100
```

### トラブルシューティング

#### HotLoadが動作しない場合
1. **Node.js未インストール**: `brew install node`
2. **ポート3000使用中**: 他のプロセスを確認
3. **WiFi接続確認**: Mac/iOSが同一ネットワーク
4. **コンソール確認**: `HotLoad server configured: http://xxx.xxx.xxx.xxx:3000`

#### Build Phase確認
```bash
# Xcodeプロジェクト設定 → Build Phases → "SwiftJsonUI HotLoad"
# スクリプトが正常に追加されているか確認
```

## このプロジェクトの位置づけ

**binding_testAppプロジェクト**は：
- ✅ binding_builderツールの利用法解説
- ✅ 実装パターンのリファレンス
- ✅ 新規プロジェクト開始時のテンプレート
- ❌ 実際のアプリ開発プロジェクト

他のプロジェクトでbinding_builderを使用する際は、このプロジェクトをリファレンスとして参考にしてください。