import { Firestore } from '@google-cloud/firestore';

let firestoreInstance: Firestore | null = null;

export function getFirestore(): Firestore {
  if (!firestoreInstance) {
    const projectId = process.env.GCP_PROJECT_ID || '';
    const databaseId = process.env.GCP_FIRESTORE_DATABASE || '(default)';

    firestoreInstance = new Firestore({
      projectId,
      databaseId,
    });
  }
  return firestoreInstance;
}
