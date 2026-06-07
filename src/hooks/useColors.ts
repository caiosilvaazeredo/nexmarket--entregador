import { useColorScheme } from 'react-native';
import { useDriverStore } from '../store/useDriverStore';
import { lightColors, darkColors, ThemeColors } from '../lib/theme';

/**
 * Resolve the active palette. If the driver has explicitly chosen a theme in
 * settings we honor it; otherwise we follow the OS appearance.
 */
export function useColors(): { colors: ThemeColors; dark: boolean } {
  const scheme = useColorScheme();
  const pref = useDriverStore((s) => s.driver?.preferences?.darkMode);
  const dark = pref === undefined || pref === null ? scheme === 'dark' : pref;
  return { colors: dark ? darkColors : lightColors, dark };
}
