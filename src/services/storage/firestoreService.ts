import { Firestore } from '@google-cloud/firestore';
import { config } from '../../config/environment';

let firestoreInstance: Firestore | null = null;

export function getFirestore(): Firestore {
  if (!firestoreInstance) {
    firestoreInstance = new Firestore({
      projectId: config.gcp.projectId,
      databaseId: config.gcp.firestoreDatabase,
    });
  }
  return firestoreInstance;
}
