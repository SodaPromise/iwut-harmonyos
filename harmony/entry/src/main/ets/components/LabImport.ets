import { Course, Period } from '../model/Iwut';
import { importLab, labCaptcha } from '../services/Lab';

@Component
export struct LabImport {
  termStart: string = '';
  profileStudentId: string = '';
  periods: Period[] = [];
  onImported: (courses: Course[]) => void = () => {};
  @Prop textColor: string = '#172136';
  @Prop muted: string = '#52627A';
  @State studentId: string = '';
  @State password: string = '';
  @State answer: string = '';
  @State captchaKey: string = '';
  @State captchaImage: string = '';
  @State working: boolean = false;
  @State error: string = '';
  private active: boolean = false;

  aboutToAppear(): void {
    this.active = true;
    this.studentId = this.profileStudentId;
    void this.reload();
  }

  aboutToDisappear(): void {
    this.active = false;
    this.password = '';
    this.answer = '';
  }

  private async reload(): Promise<void> {
    this.working = true;
    this.captchaKey = '';
    this.answer = '';
    try {
      const captcha = await labCaptcha();
      if (this.active) {
        this.captchaKey = captcha.key;
        this.captchaImage = captcha.image;
      }
    } catch (_) {
      if (this.active) this.error = '获取验证码失败，请检查网络后刷新。';
    } finally {
      if (this.active) this.working = false;
    }
  }

  private async submit(): Promise<void> {
    if (!this.studentId.trim() || !this.password || !this.answer.trim() || !this.captchaKey) {
      this.error = '请输入学号、密码和图片验证码。';
      return;
    }
    this.working = true;
    this.error = '';
    try {
      const courses = await importLab({
        studentNumber: this.studentId.trim(), password: this.password,
        captcha: this.answer.trim(), captchaKey: this.captchaKey
      }, this.termStart, this.periods);
      if (this.active) {
        this.password = '';
        this.onImported(courses);
      }
    } catch (error) {
      if (this.active) {
        const failure = error as Error;
        this.error = failure.message || '实验课导入失败，请重试。';
        await this.reload();
      }
    } finally {
      if (this.active) this.working = false;
    }
  }

  build() {
    Column({ space: 13 }) {
      Text('使用学校实验教学系统账号登录。验证码由学校系统提供。')
        .fontSize(14).fontColor(this.muted).width('100%')
      TextInput({ text: this.studentId, placeholder: '学号' }).fontColor(this.textColor)
        .onChange(text => { this.studentId = text; })
      TextInput({ text: this.password, placeholder: '密码' }).type(InputType.Password).fontColor(this.textColor)
        .onChange(text => { this.password = text; })
      Row({ space: 12 }) {
        if (this.captchaImage) Image(this.captchaImage).width(120).height(50).objectFit(ImageFit.Contain)
        Button('换一张', { type: ButtonType.Normal }).enabled(!this.working).onClick(() => { void this.reload(); })
      }.width('100%')
      TextInput({ text: this.answer, placeholder: '图片验证码' }).fontColor(this.textColor)
        .onChange(text => { this.answer = text; })
      if (this.error) Text(this.error).fontSize(13).fontColor('#B72E3B').width('100%')
      Button('登录并导入').enabled(!this.working && this.captchaKey.length > 0).width('100%')
        .onClick(() => { void this.submit(); })
    }.width('100%')
  }
}
