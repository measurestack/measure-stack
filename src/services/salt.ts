import { createHash } from 'crypto';
import { v4 as uuidv4 } from 'uuid';
import { getFirestore } from './firestore';

let cachedSalt: { date: string; salt: string } | null = null;

/**
 * Get or create daily salt with atomic transaction
 * Salt is stored in Firestore and cached in memory
 */
async function getDailySalt(): Promise<string> {
  const today = new Date().toISOString().split('T')[0];

  // Return cached salt if it's for today
  if (cachedSalt && cachedSalt.date === today) {
    return cachedSalt.salt;
  }

  const firestore = getFirestore();
  const saltDoc = firestore.collection('salts').doc(today);

  const cleanupOldSalts = () => {
    // Delete salts older than yesterday for privacy reasons
    const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().split('T')[0];
    firestore.collection('salts').where('__name__', '<', cutoff).get()
      .then(snapshot => {
        const batch = firestore.batch();
        snapshot.docs.forEach(doc => batch.delete(doc.ref));
        return batch.commit();
      })
      .catch(() => {}); // Silent fail
  };

  const salt = await firestore.runTransaction(async (transaction) => {
    const doc = await transaction.get(saltDoc);
    if (doc.exists) {
      return doc.data()?.salt;
    }

    const newSalt = uuidv4();
    transaction.set(saltDoc, { salt: newSalt });
    cleanupOldSalts();
    return newSalt;
  });

  // Cache the salt for this instance
  cachedSalt = { date: today, salt };
  return salt;
}

/**
 * Generate privacy-preserving hash from IP and user agent
 * Uses daily rotating salt for privacy
 */
export async function getHash(ip: string, userAgent: string): Promise<string> {
  const dailySalt = await getDailySalt();
  const combined = `${ip}${userAgent}${dailySalt}`;
  return createHash('sha256').update(combined).digest('hex');
}

/**
 * Generate simple SHA256 hash from data
 */
export function generateHash(data: string): string {
  return createHash('sha256').update(data).digest('hex');
}
