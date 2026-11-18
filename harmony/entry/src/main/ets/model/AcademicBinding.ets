export const BIND_PROFILE_ROOT = 'https://talent.whut.edu.cn/';
export const BIND_PROFILE_PAGE = BIND_PROFILE_ROOT + 'information-center/center/index.html?appId=2';

export function bindingHttpsRedirect(url: string): string {
  if (url.startsWith('http://zhlgd.whut.edu.cn/tpass/') || url.startsWith('http://talent.whut.edu.cn/')) {
    return 'https:' + url.slice('http:'.length);
  }
  return '';
}
