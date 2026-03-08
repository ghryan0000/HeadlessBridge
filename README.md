# HeadlessBridge

> 專為 headless Mac + iPad Air 設計的一站式連線管理 App

---

## 功能特色

- 🔌 **有線 Sidecar**：USB-C 直連，最低延遲
- 📡 **無線 Sidecar**：同網路 Wi-Fi 連線
- 🌐 **遠距 VNC**：透過 Tailscale 跨網路連線
- 🤖 **智慧自動選擇**：自動偵測最佳連線方式
- 🔐 **安全儲存**：密碼存入 iOS Keychain
- 📊 **系統診斷**：一鍵檢查所有連線元件
- 📋 **連線記錄**：追蹤使用統計

---

## 開發環境需求

- Xcode 15+
- iOS 17+（iPad Air 5th gen）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（用於產生專案檔）

---

## 安裝與產生專案

本專案採用 `XcodeGen` 進行管理，以確保專案結構的一致性並簡化 Git 衝突。

### 1. 安裝 XcodeGen

```bash
brew install xcodegen
```

### 2. 產生專案檔

在專案根目錄執行：

```bash
xcodegen generate
```

這會根據 `project.yml` 自動產生 `HeadlessBridge.xcodeproj`。

### 3. SSH 套件 (Citadel)

專案已整合 **Citadel** (純 Swift 實作的 SSH 庫)。Xcode 在開啟專案後會透過 Swift Package Manager 自動下載相關依賴（包括 SwiftNIO）。

---

## Info.plist 與權限設定

專案已透過 `project.yml` 設定好必要的權限：

- ✅ **Keychain Sharing**：用於安全儲存 SSH 密碼 (Group: `com.headlessbridge.keychain`)
- ✅ **Local Network**：允許連線至區域網路設備
- ✅ **Bonjour Services**：支援 `_ssh._tcp` 與 `_rfb._tcp` 服務偵測

> [!NOTE]
> 由於免費開發者帳號的限制，Wi-Fi SSID 偵測功能 (NEHotspotNetwork) 需要手動在 Xcode 的 Signing & Capabilities 頁面確認 Team 設定正確後才能正常運作。

---

## 使用說明

### Mac 前置設定

1. **開啟 SSH**：系統設定 > 一般 > 共享 > 遠端登入 ✅
2. **安裝 BetterDisplay**：確認 HTTP server 在 port 55777
3. **安裝 Tailscale**（遠距用）：記下 100.x.x.x IP

### iPad App 設定

1. 開啟 HeadlessBridge
2. 前往「設定」頁面
3. 填入 Mac hostname、SSH 帳號密碼
4. 點「自動取得 UUID」或手動輸入 iPad UUID
5. （選用）填入 Tailscale IP
6. 點「儲存設定」

### 日常使用

1. iPad 接 USB-C 線到 Mac（有線方案）
   或確認兩台在同一 Wi-Fi（無線方案）
2. 點「智慧連線」
3. 等待 iPad 顯示 Mac 桌面

---

## 技術架構

```text
HeadlessBridge/
├── Models/
│   └── Models.swift          # 資料模型
├── ViewModels/
│   └── ConnectionManager.swift  # 核心連線邏輯
├── Services/
│   ├── SSHService.swift      # SSH 連線服務
│   ├── NetworkService.swift  # 網路偵測服務
│   └── KeychainService.swift # 安全儲存
└── Views/
    ├── ContentView.swift     # 主畫面（Tab）
    ├── HomeView.swift        # 連線主頁
    ├── SettingsView.swift    # 設定頁面
    ├── DiagnosticView.swift  # 診斷頁面
    └── HistoryView.swift     # 記錄頁面
```

---

## Roadmap

| 版本 | 功能 |
| --- | --- |
| **v1.0 MVP** | 有線/無線 Sidecar + 設定 + 診斷 |
| **v1.1** | Tailscale VNC 整合 |
| **v1.2** | iPad Widget |
| **v1.3** | 情境感知自動連線 |
| **v2.0** | App Store 上架 |

---

## License

MIT License - 個人使用和學習用途
