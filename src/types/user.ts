import { ConsentSettings } from './events';

export interface User {
  clientId: string;
  hash: string;
  consent: ConsentSettings;
}

export interface UserAgentInfo {
  family: string;
  toVersion: () => string;
  os: {
    family: string;
    toVersion: () => string;
  };
  device: {
    family: string;
    brand: string;
    model: string;
    isBot: boolean;
  };
}

export interface GeoLocationInfo {
  continent: string | null;
  country: string | null;
  country_code: string | null;
  city: string | null;
}
