import { MenuGroup, MenuGroups, MenuRow } from './Menu';
import { connectCampusWlan, readWlanAccount, removeWlanAccount, saveWlanAccount } from '../services/Wlan';

@Component
export struct WlanPage {
  t: (key: string) => string = (key: string) => key;
  openPortal: () => void = () => {};
  @Prop ink: string = '#172136';
  @Prop muted: string = '#52627A';
  @Prop card: string = '#FFFFFF';
  @Prop line: string = '#E8EDF4';
  @State savedUsername: string = '';
  @State username: string = '';
  @State password: string = '';
  @State editing: boolean = false;
  @State busy: boolean = false;
  @State status: string = '';

  aboutToAppear(): void {
    void this.refreshSavedAccount();
  }

  aboutToDisappear(): void {
    this.password = '';
  }

  private async refreshSavedAccount(): Promise<void> {
    const account = await readWlanAccount();
    this.savedUsername = account?.username ?? '';
  }

  private async connect(): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    this.status = '';
    try {
      const account = await readWlanAccount();
      if (!account) {
        this.editing = true;
        return;
      }
      const connected = await connectCampusWlan(account);
      this.status = this.t(connected ? 'wlan.connectSuccess' : 'wlan.connectOk');
    } catch (error) {
      this.status = (error as Error).message || this.t('wlan.connectFail');
    } finally {
      this.busy = false;
    }
  }

  private async save(): Promise<void> {
    const username = this.username.trim();
    if (!username || !this.password) {
      this.status = this.t('wlan.needCreds');
      return;
    }
    try {
      await saveWlanAccount({ username, password: this.password });
      this.savedUsername = username;
      this.status = '';
      this.editing = false;
    } catch (_) {
      this.status = '未能保存账号，请确认设备已解锁后重试。';
    } finally {
      this.password = '';
    }
  }

  private action(id: string): void {
    if (id === 'new' || id === 'edit') {
      this.username = this.savedUsername;
      this.password = '';
      this.editing = true;
      return;
    }
    if (id === 'clear') {
      this.getUIContext().getPromptAction().showDialog({
        title: this.t('wlan.clearTitle'), message: this.t('wlan.clearDesc'),
        buttons: [
          { text: this.t('common.cancel'), color: this.muted },
          { text: this.t('wlan.clearConfirm'), color: '#2459C4' }
        ]
      }).then(response => {
        if (response.index === 1) {
          removeWlanAccount().then(() => {
            this.savedUsername = '';
            this.status = this.t('wlan.accountCleared');
          }).catch(() => { this.status = '账号清除失败，请重试。'; });
        }
      }).catch(() => {});
      return;
    }
    this.status = id === 'shortcut'
      ? '长按桌面上的掌上吾理图标，选择「校园网连接」。支持固定的桌面可将该入口拖至桌面。'
      : '校园网快捷入口由鸿蒙桌面管理。';
  }

  private groups(): MenuGroup[] {
    const accounts: MenuRow[] = this.savedUsername ? [
      new MenuRow('current', this.t('wlan.currentAccount'), this.savedUsername, undefined, false),
      new MenuRow('edit', this.t('wlan.editAccount')),
      new MenuRow('clear', this.t('wlan.clearAccount'))
    ] : [new MenuRow('new', this.t('wlan.setupAccount'))];
    return [
      new MenuGroup(this.t('wlan.accountGroup'), accounts),
      new MenuGroup(this.t('wlan.shortcutGroup'), [
        new MenuRow('shortcut', this.t('wlan.addShortcut')),
        new MenuRow('shortcutSettings', this.t('wlan.shortcutSettings'))
      ])
    ];
  }

  build() {
    Column({ space: 17 }) {
      Row({ space: 10 }) {
        Button(this.busy ? '连接中' : this.t('wlan.title')).enabled(!this.busy).layoutWeight(1)
          .onClick(() => { void this.connect(); })
        Button('登录网页', { type: ButtonType.Normal }).onClick(() => this.openPortal())
      }.width('100%')
      MenuGroups({
        groups: this.groups(), textColor: this.ink, muted: this.muted, card: this.card, divider: this.line,
        onAction: (id: string) => this.action(id)
      })
      if (this.editing) {
        Column({ space: 12 }) {
          Text(this.t('wlan.sheetTitle')).fontWeight(FontWeight.Bold).fontColor(this.ink).width('100%')
          TextInput({ text: this.username, placeholder: this.t('wlan.username') })
            .onChange(text => { this.username = text; })
          TextInput({ text: this.password, placeholder: this.t('wlan.password') }).type(InputType.Password)
            .onChange(text => { this.password = text; })
          Row({ space: 10 }) {
            Button(this.t('common.cancel'), { type: ButtonType.Normal }).layoutWeight(1)
              .onClick(() => { this.editing = false; this.password = ''; })
            Button(this.t('wlan.save')).layoutWeight(1).onClick(() => { void this.save(); })
          }.width('100%')
        }.width('100%').padding(14).borderRadius(14).backgroundColor(this.card)
      }
      if (this.status) Text(this.status).width('100%').fontSize(14).fontColor(this.muted)
    }.width('100%')
  }
}
