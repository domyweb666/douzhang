// 測試共用：AsyncStorage 換成官方的記憶體版 mock（真機才有原生模組）。
jest.mock('@react-native-async-storage/async-storage', () =>
  require('@react-native-async-storage/async-storage/jest/async-storage-mock'),
);
