// 收工半頁（06 狀態表「收工」）：明天的第一句預填現在那句、可改；今天沒豆子也沒作廢時多一句＋「掛一片葉子」。
// 只收字與按鈕，狀態機在 core/machine.js（closeDay、hangLeaf）。主畫面與豆棚共用。
import { useState } from 'react';
import { Text, View } from 'react-native';
import { useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { params } from '../design/params';
import { BigButton } from './BigButton';
import { Sheet } from './Sheet';
import { LineInput } from './LineInput';
import { TextButton } from './TextButton';

export function CloseSheet({ visible, clueText, leafOk, onClose, onCloseDay, onHangLeaf }) {
  const T = useTokens();
  const [text, setText] = useState(clueText || '');
  return (
    <Sheet visible={visible} title={words.close} sub={words.closeSub} onClose={onClose}>
      <Text style={{ ...T.font.caption, color: T.color.textSecondary }}>
        {words.closeTomorrowCap}
      </Text>
      <LineInput
        multiline
        value={text}
        onChange={setText}
        maxLength={params.firstLineMaxChars}
        style={{ marginTop: T.space.xs }}
      />
      <View style={{ flexDirection: 'row', gap: T.space.m, marginTop: T.space.m }}>
        <BigButton second label={words.notYet} onPress={onClose} style={{ flex: 1 }} />
        <BigButton
          label={words.close}
          onPress={() => {
            onClose();
            onCloseDay(text);
          }}
          style={{ flex: 1 }}
        />
      </View>
      {leafOk ? (
        <View style={{ marginTop: T.space.l }}>
          <Text style={{ ...T.font.sub, color: T.color.textSecondary }}>{words.leafLine}</Text>
          <TextButton
            flush
            label={words.hangLeaf}
            onPress={() => {
              onClose();
              onHangLeaf();
            }}
            style={{ minHeight: T.shape.tapPrimary }}
          />
        </View>
      ) : null}
    </Sheet>
  );
}
