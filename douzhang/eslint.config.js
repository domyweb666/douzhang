// 豆帳正式版 ESLint（flat config）。格式交給 Prettier，這裡只管邏輯複雜度與禁令。
// 依據：expo 官方 eslint-config-expo（npx expo lint 會裝）；數字上限給 AI 當煞車，不是給人背。
const expoConfig = require('eslint-config-expo/flat');
const globals = require('globals');

module.exports = [
  ...expoConfig,
  {
    ignores: ['node_modules/**', '.expo/**'],
  },
  {
    // 測試檔：jest 全域（test、expect、jest、__dirname）
    files: ['__tests__/**/*.js', '**/*.test.js'],
    languageOptions: { globals: { ...globals.jest, ...globals.node } },
  },
  {
    rules: {
      'max-lines-per-function': ['warn', { max: 80, skipBlankLines: true, skipComments: true }],
      'max-depth': ['warn', 3],
      complexity: ['warn', 12],
      'no-console': ['error', { allow: ['warn', 'error'] }],
      'no-restricted-imports': [
        'error',
        {
          paths: [
            { name: 'react-native-webview', message: '安全標準 P7：不用 WebView' },
            { name: 'expo-router', message: '憲法 1：不用 Expo Router' },
          ],
          patterns: [
            {
              group: [
                '@sentry/*',
                'firebase*',
                '@react-native-firebase/*',
                'mixpanel*',
                '@amplitude/*',
                '@segment/*',
                'posthog*',
              ],
              message: '安全標準 P4：不裝第三方分析／崩潰回報',
            },
            {
              group: ['../screens/*', './screens/*'],
              message: '憲法 1：screens 之間與 core 不准 import screens',
            },
          ],
        },
      ],
    },
  },
];
