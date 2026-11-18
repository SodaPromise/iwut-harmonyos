import { asset } from '@kit.AssetStoreKit';
import { url, util } from '@kit.ArkTS';
import { connection } from '@kit.NetworkKit';
import { rcp } from '@kit.RemoteCommunicationKit';

export interface WlanAccount {
  username: string;
  password: string;
}

interface CsrfResponse {
  csrf_token?: string;
}

interface LoginResponse {
  code?: number;
}

const GATEWAY = 'http://172.30.21.100';

function bytes(text: string): Uint8Array { return new util.TextEncoder().encodeInto(text); }

function selector(): asset.AssetMap {
  const attributes: asset.AssetMap = new Map();
  attributes.set(asset.Tag.ALIAS, bytes('iwut-wlan-account'));
  return attributes;
}

export async function saveWlanAccount(account: WlanAccount): Promise<void> {
  const attributes = selector();
  attributes.set(asset.Tag.SECRET, bytes(JSON.stringify(account)));
  attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED);
  attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
  await asset.add(attributes);
}

export async function readWlanAccount(): Promise<WlanAccount | null> {
  const attributes = selector();
  attributes.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
  try {
    const result = await asset.query(attributes);
    const secret = result[0]?.get(asset.Tag.SECRET) as Uint8Array | undefined;
    if (!secret) return null;
    return JSON.parse(util.TextDecoder.create('utf-8').decodeToString(secret)) as WlanAccount;
  } catch (_) {
    return null;
  }
}

export async function removeWlanAccount(): Promise<void> {
  await asset.remove(selector());
}

export async function connectCampusWlan(account: WlanAccount): Promise<boolean> {
  const net = await connection.getDefaultNet();
  const capabilities = await connection.getNetCapabilities(net);
  if (!capabilities.bearerTypes.includes(connection.NetBearType.BEARER_WIFI) ||
    capabilities.bearerTypes.includes(connection.NetBearType.BEARER_VPN)) {
    throw new Error('请先连接校园 Wi-Fi，然后重试。');
  }
  const session = rcp.createSession({
    requestConfiguration: { transfer: { autoRedirect: false, timeout: { connectMs: 8000, transferMs: 12000 } } },
    cookieRepository: rcp.CookieRepository.create()
  });
  try {
    const probeHeaders: rcp.RequestHeaders = { 'host': 'connect.rom.miui.com', 'cache-control': 'no-cache' };
    const probe = await session.fetch(new rcp.Request('http://223.5.5.5/generate_204', 'GET', probeHeaders));
    if (probe.statusCode === 204) return false;
    const redirect = probe.headers['location'] ?? probe.headers['Location'];
    if (typeof redirect !== 'string') throw new Error('没有检测到校园网认证入口。');
    const portal = url.URL.parseURL(redirect, GATEWAY);
    if (portal.hostname !== '172.30.21.100') throw new Error('当前 Wi-Fi 未跳转至学校认证网关。');
    const segment = portal.pathname.split('/').filter(item => item.length > 0).pop() ?? '';
    const nas = portal.params.get('nasId') || segment;
    if (!nas || nas.length > 128) throw new Error('校园网认证参数缺失。');
    const csrfReply = await session.get(GATEWAY + '/api/csrf-token');
    if (csrfReply.statusCode !== 200) throw new Error('无法获取校园网认证令牌。');
    const csrf = csrfReply.toJSON() as CsrfResponse;
    if (!csrf?.csrf_token) throw new Error('校园网认证令牌无效。');
    const parameters: Record<string, string> = {
      'username': account.username, 'password': account.password, 'nasId': nas,
      'switchip': portal.params.get('switchip') ?? '', 'userIpv4': '', 'userMac': '', 'captcha': '', 'captchaId': ''
    };
    const fields = ['username', 'password', 'nasId', 'switchip', 'userIpv4', 'userMac', 'captcha', 'captchaId'];
    const body = fields.map(key => encodeURIComponent(key) + '=' + encodeURIComponent(parameters[key])).join('&');
    const headers: rcp.RequestHeaders = {
      'content-type': 'application/x-www-form-urlencoded', 'x-csrf-token': csrf.csrf_token
    };
    const reply = await session.fetch(new rcp.Request(GATEWAY + '/api/account/login', 'POST', headers, body));
    if (reply.statusCode !== 200 || (reply.toJSON() as LoginResponse)?.code !== 0) {
      throw new Error('校园网认证失败，请核对账号和密码。');
    }
    return true;
  } finally {
    session.close();
  }
}
