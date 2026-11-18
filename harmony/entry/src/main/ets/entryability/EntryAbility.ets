import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    this.onConfigurationUpdate(this.context.config);
    this.queueLink(want);
  }

  onConfigurationUpdate(config: Configuration): void {
    if (config.colorMode !== undefined) {
      AppStorage.setOrCreate('iwutSystemDark', config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    }
  }

  onNewWant(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    this.queueLink(want);
  }

  private queueLink(want: Want): void {
    if (want.uri?.startsWith('iwut://share?data=')) {
      AppStorage.setOrCreate('iwutSharedLink', want.uri);
    }
    if (want.parameters?.['iwutShortcut'] === 'wlan') {
      AppStorage.setOrCreate('iwutShortcut', 'wlan');
    }
  }

  onWindowStageCreate(stage: window.WindowStage): void {
    stage.loadContent('pages/Index', error => {
      if (error.code) hilog.error(0, 'IWUT', 'Unable to load ArkUI: %{public}d', error.code);
    });
  }
}
