// 番茄圖，五色（2026-11-02 W1：每種類型一個色）。從多米給的扁平紅番茄轉色做的，萼片維持綠色。
// 罐子、番茄架、設定的選色三處共用，所以收在這裡。圖的寬＝本體寬、本體中心＝圖中心，蒂往上露出。
import { Image } from 'react-native';

export const TOMATOES = {
  red: require('../assets/img/tomato-red.webp'),
  orange: require('../assets/img/tomato-orange.webp'),
  yellow: require('../assets/img/tomato-yellow.webp'),
  purple: require('../assets/img/tomato-purple.webp'),
  pink: require('../assets/img/tomato-pink.webp'),
};

/** 不認得的色（舊資料、被刪的類型）一律紅。 */
export const tomatoOf = (color) => TOMATOES[color] || TOMATOES.red;

/** 五張同尺寸，高寬比拿紅的算。 */
export const TOMATO_ASPECT = (() => {
  const { width, height } = Image.resolveAssetSource(TOMATOES.red);
  return height / width;
})();
