// 白噪音半頁（2026-11-17 AG6，比較頁 6A）：主畫面那顆聲音鈕開的。選關／雨／柴火，選了聲音才出現音量三段。
// 改了立刻存、立刻生效，「好」只是關。待機時打開可以邊選邊聽（preview）；計時中本來就在播，由殼管，這裡不碰。
import { useEffect } from 'react';
import { Text } from 'react-native';
import { useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { params } from '../design/params';
import { AMBIENCE_OFF, applyAmbience } from '../core/ambience';
import { BigButton } from './BigButton';
import { Sheet } from './Sheet';
import { Segmented } from './Segmented';

const KINDS = params.ambience.kinds.map((k) => ({ value: k, label: words.ambienceKinds[k] }));
const LEVELS = params.ambience.levels.map((l) => ({ value: l, label: words.ambienceLevels[l] }));

/** 待機時試聽：半頁開著就播選中的那種，關掉就停。換音量不會從頭播（applyAmbience 同一種只換音量）。 */
function usePreview(on, kind, level) {
  useEffect(() => {
    if (on) applyAmbience(kind, level);
  }, [on, kind, level]);
  useEffect(() => {
    if (!on) return undefined;
    return () => applyAmbience(AMBIENCE_OFF);
  }, [on]);
}

export function SoundSheet({ visible, preview, settings, actions, onClose }) {
  const T = useTokens();
  const { ambience, ambienceVolume } = settings;
  usePreview(visible && preview, ambience, ambienceVolume);
  const cap = { ...T.font.caption, color: T.color.textSecondary, marginTop: T.space.l };
  return (
    <Sheet visible={visible} title={words.ambienceTitle} onClose={onClose}>
      <Segmented options={KINDS} value={ambience} onChange={actions.onSetAmbience} />
      {ambience === AMBIENCE_OFF ? null : (
        <>
          <Text style={cap}>{words.ambienceVolumeCap}</Text>
          <Segmented
            options={LEVELS}
            value={ambienceVolume}
            onChange={actions.onSetAmbienceVolume}
            style={{ marginTop: T.space.s }}
          />
        </>
      )}
      <Text style={cap}>{words.ambienceSub}</Text>
      <BigButton label={words.ok} onPress={onClose} style={{ marginTop: T.space.l }} />
    </Sheet>
  );
}
