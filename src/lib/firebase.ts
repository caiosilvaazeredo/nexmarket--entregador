import { initializeApp, getApps, getApp } from 'firebase/app';
import {
  initializeAuth,
  getAuth,
  signInWithCustomToken,
  signInAnonymously,
  signOut,
} from 'firebase/auth';

// getReactNativePersistence is exported only from Firebase's React Native
// entry point — Metro resolves it at runtime, but the web-entry TS types omit
// it, so we access it via require to keep type-checking happy.
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { getReactNativePersistence } = require('firebase/auth') as any;
import { getFirestore } from 'firebase/firestore';
import { getStorage, ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import AsyncStorage from '@react-native-async-storage/async-storage';

import firebaseConfig from '../../firebase-config.json';

// Reuse the SAME Firebase project + named Firestore database as the loja app,
// so both apps share one integrated backend.
const app = getApps().length ? getApp() : initializeApp(firebaseConfig);

// React Native needs explicit AsyncStorage-backed auth persistence,
// otherwise the user is logged out on every cold start.
export const auth = (() => {
  try {
    return initializeAuth(app, {
      persistence: getReactNativePersistence(AsyncStorage),
    });
  } catch {
    // initializeAuth throws if already initialized (Fast Refresh) -> fall back.
    return getAuth(app);
  }
})();

export const db = getFirestore(app, firebaseConfig.firestoreDatabaseId);
export const storage = getStorage(app, `gs://${firebaseConfig.storageBucket}`);

export { app };

/* -------------------------- Auth helpers -------------------------- *
 * Login/senha NÃO usam mais o Firebase Authentication nativo (nem e-mail/
 * senha nativo, nem Google) — vivem no Firestore, validados pelo backend
 * compartilhado (repo nexmarket--empresa, pasta server/), que emite um
 * Firebase Custom Token. O Firebase Auth aqui é usado SÓ como mecanismo de
 * sessão, para as Security Rules continuarem funcionando (request.auth). */

const AUTH_API_URL = (process.env.EXPO_PUBLIC_AUTH_API_URL || 'http://localhost:8787').replace(/\/$/, '');

async function requestCustomToken(path: string, body: Record<string, unknown>) {
  const res = await fetch(`${AUTH_API_URL}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw Object.assign(new Error(data?.error || 'Falha na autenticação.'), { code: 'auth/server' });
  }
  return data as { customToken: string; uid: string };
}

export const loginWithEmail = async (email: string, pass: string) => {
  const { customToken } = await requestCustomToken('/api/auth/login', {
    app: 'entregador',
    email: email.trim(),
    password: pass,
  });
  return (await signInWithCustomToken(auth, customToken)).user;
};

export const registerWithEmail = async (email: string, pass: string) => {
  const { customToken } = await requestCustomToken('/api/auth/register', {
    app: 'entregador',
    email: email.trim(),
    password: pass,
  });
  return (await signInWithCustomToken(auth, customToken)).user;
};

export const loginAsVisitor = async () => {
  if (auth.currentUser) return auth.currentUser;
  return (await signInAnonymously(auth)).user;
};

export const logout = async () => {
  try {
    await signOut(auth);
  } catch (e) {
    console.warn('Logout failed', e);
  }
};

/* -------------------------- Storage helpers -------------------------- */

/**
 * Uploads a local file (file://...) to Firebase Storage and returns its
 * public download URL. Uses the XHR->Blob workaround which is the reliable
 * way to turn a RN local uri into a Blob for upload.
 */
export async function uploadImageAsync(localUri: string, path: string): Promise<string> {
  const blob: Blob = await new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.onload = () => resolve(xhr.response);
    xhr.onerror = () => reject(new Error('Falha ao ler o arquivo de imagem.'));
    xhr.responseType = 'blob';
    xhr.open('GET', localUri, true);
    xhr.send(null);
  });

  const storageRef = ref(storage, path);
  await uploadBytes(storageRef, blob);
  // @ts-ignore RN Blob has close() to free memory
  if (typeof (blob as any).close === 'function') (blob as any).close();
  return getDownloadURL(storageRef);
}

/* -------------------------- Error handling -------------------------- */

export enum OperationType {
  CREATE = 'create',
  UPDATE = 'update',
  DELETE = 'delete',
  LIST = 'list',
  GET = 'get',
  WRITE = 'write',
}

export function handleFirestoreError(
  error: unknown,
  operationType: OperationType,
  path: string | null,
) {
  const info = {
    error: error instanceof Error ? error.message : String(error),
    operationType,
    path,
    uid: auth.currentUser?.uid ?? null,
  };
  console.error('Firestore Error:', JSON.stringify(info));
}

/** Map error codes to friendly Portuguese messages. Server errors (our
 * shared auth backend) already come with a ready-to-show message. */
export function authErrorMessage(err: any): string {
  if (err?.code === 'auth/server' && err?.message) return err.message;
  const code = err?.code || '';
  switch (code) {
    case 'auth/invalid-email':
      return 'E-mail inválido.';
    case 'auth/user-not-found':
    case 'auth/wrong-password':
    case 'auth/invalid-credential':
      return 'Credenciais inválidas. Verifique e-mail e senha.';
    case 'auth/email-already-in-use':
      return 'Este e-mail já está em uso.';
    case 'auth/weak-password':
      return 'A senha deve ter ao menos 6 caracteres.';
    case 'auth/too-many-requests':
      return 'Muitas tentativas. Tente novamente em instântes.';
    case 'auth/network-request-failed':
      return 'Sem conexão. Verifique sua internet.';
    case 'auth/admin-restricted-operation':
      return 'Modo de teste desativado no Firebase (ative o login anônimo).';
    default:
      return 'Ocorreu um erro. Tente novamente.';
  }
}
