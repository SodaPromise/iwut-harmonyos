import { deviceInfo } from '@kit.BasicServicesKit';
import { url } from '@kit.ArkTS';
import { Profile } from '../model/Iwut';

const MINI_APP_HOSTS: string[] = [
  'classroom-iwut.tokenteam.net',
  'library-info-iwut.tokenteam.net',
  'cardcare-iwut.tokenteam.net'
];

interface StudentPayload {
  hasProfile: boolean;
  name: string;
  studentId: string;
  cardId: string;
  college: string;
  eduLevel: string;
}

interface AppInfo {
  name: string;
  version: string;
  osType: string;
  osVersion: string;
  device: string;
  bundleId: string;
  buildVersion: string;
}

export function campusMiniAppScripts(address: string, profile: Profile | null, source: string): ScriptItem[] {
  if (!source || !profile) return [];
  try {
    const page = url.URL.parseURL(address);
    if (page.protocol !== 'https:' || page.port || !MINI_APP_HOSTS.includes(page.hostname)) return [];
    const origin = page.origin;
    const student: StudentPayload = {
      hasProfile: true, name: profile.name, studentId: profile.studentId,
      cardId: profile.cardId, college: profile.college, eduLevel: profile.eduLevel
    };
    const app: AppInfo = {
      name: '掌上吾理', version: '0.3.31', osType: 'HarmonyOS', osVersion: deviceInfo.osFullName,
      device: deviceInfo.productModel, bundleId: 'net.tokenteam.iwut.harmony', buildVersion: '0.3.31-331'
    };
    const script = source.trim() + '(' + JSON.stringify(origin) + ',' +
      JSON.stringify(student) + ',' + JSON.stringify(app) + ');';
    return [{ script, scriptRules: [origin] }];
  } catch (_) {
    return [];
  }
}
