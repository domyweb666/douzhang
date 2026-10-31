// A1：只證明殼跑得起來、代號接上了。畫面是 A2 以後的事。
import { StatusBar } from 'expo-status-bar';
import { Text, View } from 'react-native';
import { useTokens } from './design/Tokens';
import { words } from './design/words';

export default function App() {
  const T = useTokens();
  return (
    <View
      style={{
        flex: 1,
        backgroundColor: T.color.background,
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <Text style={{ ...T.font.largeTitle, color: T.color.textPrimary }}>{words.appName}</Text>
      <StatusBar style="auto" />
    </View>
  );
}
