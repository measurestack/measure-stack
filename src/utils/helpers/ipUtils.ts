export function truncateIP(ip: string): string {
  if (!ip) return '';

  // Handle IPv6
  if (ip.includes(':')) {
    const parts = ip.split(':');
    // For IPv6, take first 4 segments and add ::
    // But if the original IP already has ::, we need to handle it differently
    if (ip.includes('::')) {
      const beforeDoubleColon = ip.split('::')[0];
      const segments = beforeDoubleColon.split(':').filter(Boolean);
      return segments.slice(0, 4).join(':') + '::';
    } else {
      return parts.slice(0, 4).join(':') + '::';
    }
  }

  // Handle IPv4
  const parts = ip.split('.');
  return parts.slice(0, 3).join('.') + '.0';
}

export function sanitizeIP(ip: string): string {
  // For local testing
  if (ip.includes("127.0.0.1")) return "2a02:3100:1da8:1d00:d575:624d:f65a:e8ae" // "141.20.2.3";
  if (ip === "::1") return "2a02:3100:1da8:1d00:d575:624d:f65a:e8ae" //  "141.20.2.3";
  return ip;
}
