# dp_train_new

DeepMD-kit 深度神經網絡勢能（DLP）自動化訓練系統（新版）。

本系統提供從訓練數據準備到模型訓練的完整自動化流程，整合 Quantum ESPRESSO（DFT）和 LAMMPS（MD）作為數據源，使用 DeePMD-kit 進行神經網絡訓練。

---

## 程式功能說明

### 完整工作流程

```
結構生成 → QE 計算 (DFT) → 輸出解析 → npy 數據集 → dp_train 訓練 → 品質評估
     ↑                                                              ↓
     └──────────────── LAMMPS 驗證 ───────────────────────────────┘
```

### 核心模組

| 腳本 | 功能 |
|---|---|
| `scripts/main.pl` | 主控制腳本，協調完整 DLP 訓練流程 |
| `scripts/all_settings.pm` | 全域配置（job type、力學上界、路徑等） |
| `scripts/dp_train.pl` | dp_train JSON 生成與訓練啟動 |
| `scripts/DFTout2npy_QE.pl` | QE 輸出 → npy 訓練數據轉換 |
| `scripts/QEin2data.pl` | QE 輸入 → LAMMPS data 格式轉換 |
| `scripts/iso_energy.pm` | 孤立原子能量計算模組 |
| `scripts/findBadfiles.pl` | 異常文件偵測 |
| `scripts/slurm_dft.sh` | Slurm DFT 工作提交 |
| `scripts/slurm_dp.sh` | Slurm DLP 訓練工作提交 |
| `scripts/slurm_lmp.sh` | Slurm LAMMPS 驗證工作提交 |
| `scripts/dptest_matplot.pl` | DLP 測試品質圖表生成 |
| `scripts/dp_plots.py` | Python 品質評估圖表 |

### 支援的作業類型

| jobtype | 說明 |
|---|---|
| `npy_only` | 僅生成 npy 數據（不訓練） |
| `full` | 完整訓練流程（QE → npy → dp_train → LAMMPS 驗證） |

---

## 依賴環境

| 項目 | 需求 |
|---|---|
| 語言 | Perl 5.x, Python 3.x |
| Perl 模組 | `JSON::PP`, `Parallel::ForkManager`, `List::Util`, `Cwd`, `POSIX` |
| DFT | Quantum ESPRESSO（pw.x） |
| MD | LAMMPS（含 deepmd 插件） |
| DLP | DeePMD-kit（dp, dp_train） |
| 排程 | Slurm（squeue, sbatch） |
| 繪圖 | Python matplotlib, gnuplot |

---

## 使用方法

### 1. 配置設定

編輯 `scripts/all_settings.pm`：

```perl
# 主要路徑設定
$system_setting{script_dir} = '/path/to/dp_train_new/scripts';
$system_setting{main_dir} = '/path/to/dp_train_new';

# 軟體路徑
# 設定 DeePMD-kit 和 QE 的安裝路徑

# 訓練參數
$system_setting{jobtype} = 'full';  # 或 'npy_only'
$system_setting{force_upperbound} = 0.1;  # 力學上界 (eV/Å)
$system_setting{ratio4val} = 0.1;  # 驗證集比例
$system_setting{doDFT4dpgen} = 1;  # 是否執行 DFT 計算
$system_setting{doiniTrain} = 1;  # 是否執行初始訓練
```

### 2. 準備初始結構

在 `initial/` 目錄下放置 QE 輸入文件（`.in`）：

```bash
mkdir -p initial
cp *.in initial/
```

### 3. 執行訓練流程

```bash
cd /path/to/dp_train_new
nohup perl scripts/main.pl &
tail -f nohup.out
```

### 4. 檢查訓練品質

```bash
# 檢查最大力（力學誤差）
grep "Max force" nohup.out | awk '{print $NF}' | sort -nr

# 生成品質圖表
perl scripts/dptest_matplot.pl
```

---

## 輸入/輸出格式

### 輸入

| 檔案 | 格式 | 說明 |
|---|---|---|
| `initial/*.in` | QE pw.x 輸入 | 初始結構的 DFT 計算 |
| `scripts/all_settings.pm` | Perl | 全域配置 |
| `scripts/QE_script.in` | QE pw.x 輸入 | QE 計算參數範本 |
| `scripts/input_v2_compat.json` | JSON | dp_train 配置範本 |

### 輸出

| 路徑 | 內容 |
|---|---|
| `npy_*/*/` | npy 訓練數據集 |
| `train*/` | 訓練權重（graph-*） |
| `test*/` | 測試結果 |
| `plottest*/` | 品質評估圖表 |

---

## AI Agent 操控指南

### 啟動 DLP 訓練流程

```
任務: 為新材料建立 DLP 模型
步驟:
1. 準備初始結構（QE 輸入文件）
2. 配置 all_settings.pm（路徑、參數）
3. 檢查: 確認 QE 和 DeePMD-kit 路徑正確
4. 執行: perl scripts/main.pl
5. 監控: tail -f nohup.out
6. 檢查品質: grep "Max force" nohup.out | awk '{print $NF}' | sort -nr
7. 若 max force 超過 force_upperbound → 調整訓練週期後重新訓練
```

### 檢查訓練狀態

```bash
# 訓練進度
tail -50 nohup.out

# 品質檢查
grep "Max force" nohup.out | awk '{print $NF}' | sort -nr | head -10

# Slurm 工作狀態
squeue -u $(whoami)
```

### 僅生成 npy 數據

```perl
# 修改 all_settings.pm:
$system_setting{jobtype} = 'npy_only';
```
