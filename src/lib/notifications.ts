import * as Notifications from 'expo-notifications';
import * as Haptics from 'expo-haptics';
import { Platform } from 'react-native';

// Show banners + play sound even when the app is foregrounded (driver waiting).
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
    shouldShowBanner: true,
    shouldShowList: true,
  }),
});

export async function ensureNotificationPermissions(): Promise<boolean> {
  const { status: existing } = await Notifications.getPermissionsAsync();
  let status = existing;
  if (existing !== 'granted') {
    const req = await Notifications.requestPermissionsAsync();
    status = req.status;
  }
  if (Platform.OS === 'android') {
    await Notifications.setNotificationChannelAsync('offers', {
      name: 'Novas entregas',
      importance: Notifications.AndroidImportance.MAX,
      vibrationPattern: [0, 300, 200, 300],
      lightColor: '#58CC02',
      sound: 'default',
    });
  }
  return status === 'granted';
}

/** Fire a high-priority local alert for a new delivery offer. */
export async function alertNewOffer(opts: {
  earnings: string;
  store: string;
  sound: boolean;
}) {
  try {
    await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
  } catch {}
  try {
    await Notifications.scheduleNotificationAsync({
      content: {
        title: '🛵 Nova entrega disponível!',
        body: `${opts.store} • Ganho ${opts.earnings}. Toque para ver.`,
        sound: opts.sound ? 'default' : undefined,
        priority: Notifications.AndroidNotificationPriority.MAX,
      },
      trigger: null, // immediate
    });
  } catch (e) {
    console.warn('Failed to present offer notification', e);
  }
}

export async function notify(title: string, body: string) {
  try {
    await Notifications.scheduleNotificationAsync({
      content: { title, body, sound: 'default' },
      trigger: null,
    });
  } catch {}
}
