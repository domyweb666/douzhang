// 豆帳 備份：匯出（系統分享選單）、匯入（系統檔案選取器）、匯入前的自動備份。包 expo-file-system／expo-sharing／expo-document-picker。
// 安全標準：S3 匯入前自動備份到 documentDirectory；S7 匯出走分享、分享完刪暫存；I3 大小上限；I5 檔名由 app 產；P5 清空時刪自動備份。
// 只碰檔案，不決定要不要覆蓋（確認框與換狀態在殼）。每個系統呼叫都包 try：失敗回旗標，不丟到畫面。
import { File, Paths } from 'expo-file-system';
import * as Sharing from 'expo-sharing';
import * as DocumentPicker from 'expo-document-picker';
import { dayKey, parseBackup } from './store';
import { params } from '../design/params';

const AUTO_PREFIX = 'auto-backup-';
const AUTO_SUFFIX = '.json';
const JSON_MIME = 'application/json';

/** 匯出檔名：豆帳備份-YYYY-MM-DD.json（跟 PWA 同名，I5 不接受自訂）。 */
export const backupName = (now) => `豆帳備份-${dayKey(now)}.json`;

/** 匯出：寫到暫存 → 系統分享選單 → 刪掉暫存（S7）。被取消不算錯。回 true／false。 */
export async function exportBackup(text, now) {
  let file = null;
  try {
    file = new File(Paths.cache, backupName(now));
    if (file.exists) file.delete();
    file.create();
    await file.write(text);
    await Sharing.shareAsync(file.uri, { mimeType: JSON_MIME, UTI: 'public.json' });
    return true;
  } catch {
    return false;
  } finally {
    try {
      if (file?.exists) file.delete();
    } catch {
      // 暫存刪不掉，系統清快取時會清
    }
  }
}

/**
 * 匯入：選一個檔 → 看大小（I3）→ 讀字 → parseBackup（I1、I2、I4）。
 * 回 { canceled } ｜ { error: 'tooBig'｜'unreadable' } ｜ { state }。這一步不碰現在的資料。
 */
export async function pickImport() {
  let picked;
  try {
    picked = await DocumentPicker.getDocumentAsync({ type: JSON_MIME, copyToCacheDirectory: true });
  } catch {
    return { error: 'unreadable' };
  }
  if (picked.canceled || !picked.assets?.length) return { canceled: true };
  const asset = picked.assets[0];
  try {
    const file = new File(asset.uri);
    const size = asset.size ?? file.size;
    if (!(size <= params.importMaxBytes)) return { error: 'tooBig' };
    return { state: parseBackup(await file.text()) };
  } catch {
    return { error: 'unreadable' };
  }
}

/** 自動備份：把現在存著的原文寫一份到 documentDirectory/auto-backup-<毫秒>.json（S3）。回 true／false。 */
export async function autoBackup(text, now) {
  try {
    const file = new File(Paths.document, `${AUTO_PREFIX}${now}${AUTO_SUFFIX}`);
    file.create();
    await file.write(text);
    return true;
  } catch {
    return false;
  }
}

function autoBackupFiles() {
  try {
    return Paths.document
      .list()
      .filter(
        (f) => f instanceof File && f.name.startsWith(AUTO_PREFIX) && f.name.endsWith(AUTO_SUFFIX),
      );
  } catch {
    return [];
  }
}

/** 上次自動備份的時刻（毫秒），沒有就 null。設定頁顯示用（S3「設定頁要能看到」）。 */
export function lastAutoBackupAt() {
  const times = autoBackupFiles()
    .map((f) => Number(f.name.slice(AUTO_PREFIX.length, -AUTO_SUFFIX.length)))
    .filter(Number.isFinite);
  return times.length ? Math.max(...times) : null;
}

/** 清空所有資料時連自動備份一起刪（P5）。回 true／false。 */
export function removeAutoBackups() {
  try {
    autoBackupFiles().forEach((f) => f.delete());
    return true;
  } catch {
    return false;
  }
}
