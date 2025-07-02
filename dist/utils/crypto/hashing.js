import { createHash } from 'crypto';
import { config } from '../../config/environment';
export function getHashh(ip, userAgent) {
    const combined = `${ip}${userAgent}${config.dailySalt}`;
    return createHash('sha256').update(combined).digest('hex');
}
export function generateHash(data) {
    return createHash('sha256').update(data).digest('hex');
}
