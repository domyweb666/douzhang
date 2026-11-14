// 豆帳在 Domy Design System 裡的產品色（2026-11-14 多米：照 E:\domy-design 重新設計，保留 icon 的茄紫）。
// 中性色、畫布、字級、間距、圓角都由 @domy/design 統一給；豆帳只決定這五階加兩個字色。
// 對比由 __tests__/theme.test.js 用 auditTheme 驗，開發模式下 DomyThemeProvider 也會再驗一次。
import { createTheme } from '@domy/design';

export const douzhangTheme = createTheme({
  name: 'eggplant',
  label: '茄紫',
  canvas: 'warm', // 跟原本的微暖米白最接近
  light: {
    accent: '#3B2547', // icon 背景的茄紫：主要按鈕底
    onAccent: '#FFFFFF',
    strong: '#4A2F5A', // 可點的字、選中的字
    soft: '#ECE3F1', // 選中的分頁、選項膠囊、選中的那天
    tint: '#F8F4FA', // 鈴響時「這顆在做」那張小卡的淡底
    bright: '#CDB6DC',
    onBright: '#2A1834',
  },
  dark: {
    accent: '#D9C2E8',
    onAccent: '#2A1A33',
    strong: '#E3D0F0',
    soft: '#3A2B45',
    tint: '#1E1823',
    bright: '#CDB6DC',
    onBright: '#2A1834',
  },
});
