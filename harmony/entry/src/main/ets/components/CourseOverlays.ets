import { Course, Period, courseTime } from '../model/Iwut';
import { COURSE_WEEKS, CourseSlotRange, QuickCourseDraft, sectionLabel } from '../model/CourseDraft';

@Component
struct CoursePanelHeading {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop color: string = '#317CF4';
  close: () => void = () => {};

  build() {
    Row({ space: 10 }) {
      Column({ space: 7 }) {
        Text(this.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
        Text(this.subtitle).fontSize(13).fontColor('#F5FFFFFF')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.xmark')).fontSize(14).fontColor([this.color])
      }.width(32).height(32).padding(0).backgroundColor(Color.White).accessibilityText('关闭')
        .onClick(() => this.close())
    }.width('100%').alignItems(VerticalAlign.Top).padding(20).backgroundColor(this.color)
  }
}

@Component
export struct CourseDetailCard {
  course: Course = { name: '', teacher: '', room: '', day: 1, sectionStart: 1, sectionEnd: 1, weekStart: 1, weekEnd: 1 };
  @Prop periods: Period[] = [];
  @Prop weekday: string = '';
  @Prop color: string = '#317CF4';
  @Prop textColor: string = '#172136';
  @Prop muted: string = '#52627A';
  @Prop card: string = '#FFFFFF';
  @Prop tile: string = '#F2F5FA';
  t: (key: string) => string = (key: string): string => key;
  onClose: () => void = () => {};
  onEdit: () => void = () => {};
  onShare: () => void = () => {};
  onAdd: () => void = () => {};
  @Prop addAvailable: boolean = true;

  @Builder
  private detailRow(icon: Resource, label: string, value: string) {
    Row({ space: 13 }) {
      Stack() {
        SymbolGlyph(icon).fontSize(20).fontColor([this.muted])
      }.width(38).height(38).backgroundColor(this.tile).borderRadius(11)
      Column({ space: 3 }) {
        Text(label).width('100%').fontSize(11).fontColor(this.muted)
        Text(value).width('100%').fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.textColor)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%')
  }

  @Builder
  private action(icon: Resource, label: string, run: () => void) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 5 }) {
        SymbolGlyph(icon).fontSize(16).fontColor([this.textColor])
        Text(label).fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.textColor)
      }
    }.layoutWeight(1).height(43).backgroundColor(this.tile).borderRadius(12).padding(0)
      .onClick(() => run())
  }

  build() {
    Scroll() {
      Column() {
        CoursePanelHeading({
          title: this.course.name, color: this.color, close: () => this.onClose(),
          subtitle: sectionLabel(this.t('schedule.weekdayWithSection'), this.weekday,
            this.course.sectionStart, this.course.sectionEnd)
        })
        Column({ space: 13 }) {
          if (this.course.room) this.detailRow($r('sys.symbol.position'), this.t('schedule.room'), this.course.room)
          if (this.course.teacher) this.detailRow($r('sys.symbol.person'), this.t('schedule.teacher'), this.course.teacher)
          this.detailRow($r('sys.symbol.calendar'), this.t('schedule.weeks'),
            sectionLabel(this.t('schedule.weeksValue'), '', this.course.weekStart, this.course.weekEnd))
          this.detailRow($r('sys.symbol.clock'), this.t('schedule.time'), courseTime(this.course, this.periods))
          if (this.course.note || this.course.seat !== undefined) {
            this.detailRow($r('sys.symbol.text_alignleft'), this.t('schedule.labProject'),
              [this.course.note ?? '', this.course.seat === undefined ? '' :
                this.t('schedule.seatValue').replace('{n}', this.course.seat.toString())].filter(value => value.length > 0).join(' · '))
          }
          Row({ space: 8 }) {
            this.action($r('sys.symbol.square_and_pencil'), this.t('common.edit'), () => this.onEdit())
            this.action($r('sys.symbol.qrcode'), this.t('common.share'), () => this.onShare())
            if (this.addAvailable) {
              this.action($r('sys.symbol.plus_circle'), this.t('common.add'), () => this.onAdd())
            }
          }.width('100%').margin({ top: 8 })
        }.width('100%').padding(17)
      }.width('100%')
    }.width('86%').constraintSize({ maxWidth: 420, maxHeight: '88%' }).scrollBar(BarState.Off)
      .backgroundColor(this.card).borderRadius(23).clip(true)
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }))
        .animation({ duration: 240, curve: Curve.Friction }))
      .defaultFocus(true)
  }
}

@Component
export struct QuickCourseCard {
  slot: CourseSlotRange = { day: 1, sectionStart: 1, sectionEnd: 2 };
  @Prop week: number = 1;
  @Prop weekday: string = '';
  @Prop time: string = '';
  @Prop textColor: string = '#172136';
  @Prop muted: string = '#52627A';
  @Prop card: string = '#FFFFFF';
  @Prop tile: string = '#F2F5FA';
  @Prop blue: string = '#2459C4';
  t: (key: string) => string = (key: string): string => key;
  onClose: () => void = () => {};
  onSave: (draft: QuickCourseDraft) => void = () => {};
  onCustom: (draft: QuickCourseDraft) => void = () => {};
  @State name: string = '';
  @State room: string = '';
  @State teacher: string = '';
  @State showTeacher: boolean = false;
  @State weekMode: number = 0;

  private draft(): QuickCourseDraft {
    const weeks = this.weekMode === 1 ? [this.week] :
      this.weekMode === 2 ? COURSE_WEEKS.filter(week => week >= this.week) :
      this.weekMode === 3 ? COURSE_WEEKS.slice() : [];
    return { slot: this.slot, name: this.name, room: this.room, teacher: this.teacher, weeks };
  }

  @Builder
  private weekOption(mode: number, label: string) {
    Button(label, { type: ButtonType.Normal }).height(36).borderRadius(9).fontSize(13).layoutWeight(1)
      .backgroundColor(this.weekMode === mode ? '#317CF4' : this.tile)
      .fontColor(this.weekMode === mode ? Color.White : this.textColor)
      .onClick(() => { this.weekMode = mode; })
  }

  build() {
    Scroll() {
      Column() {
        CoursePanelHeading({
          title: this.t('schedule.quickAdd.title'), color: '#317CF4', close: () => this.onClose(),
          subtitle: sectionLabel(this.t('schedule.weekdayWithSection'), this.weekday, this.slot.sectionStart,
            this.slot.sectionEnd) + (this.time ? ' · ' + this.time : '')
        })
        Column({ space: 13 }) {
          TextInput({ text: this.name, placeholder: this.t('schedule.quickAdd.namePlaceholder') })
            .fontSize(17).fontWeight(FontWeight.Medium).height(45).fontColor(this.textColor)
            .backgroundColor(this.tile).onChange(value => { this.name = value; })
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.position')).fontSize(20).fontColor([this.muted])
            TextInput({ text: this.room, placeholder: this.t('schedule.quickAdd.roomPlaceholder') })
              .layoutWeight(1).height(40).backgroundColor(Color.Transparent).fontColor(this.textColor)
              .onChange(value => { this.room = value; })
          }.width('100%')
          Divider().color(this.tile)
          if (this.showTeacher) {
            TextInput({ text: this.teacher, placeholder: this.t('schedule.quickAdd.teacherPlaceholder') })
              .height(40).fontColor(this.textColor).backgroundColor(this.tile)
              .onChange(value => { this.teacher = value; })
          } else {
            Button('+ ' + this.t('schedule.quickAdd.addTeacher'), { type: ButtonType.Normal }).height(35)
              .padding(0).fontColor(this.blue).backgroundColor(Color.Transparent)
              .onClick(() => { this.showTeacher = true; })
          }
          Text(this.t('schedule.quickAdd.weeksLabel')).fontSize(13).fontColor(this.muted).width('100%')
          Row({ space: 6 }) {
            this.weekOption(1, this.t('schedule.quickAdd.weeksOnlyCurrent'))
            this.weekOption(2, this.t('schedule.quickAdd.weeksToEnd'))
            this.weekOption(3, this.t('schedule.quickAdd.weeksAll'))
          }.width('100%')
          Button(this.t('schedule.quickAdd.presetsNotEnough') + ' ›', { type: ButtonType.Normal }).width('100%')
            .fontSize(12).fontColor(this.blue).backgroundColor(Color.Transparent).onClick(() => this.onCustom(this.draft()))
          Button(this.t('schedule.quickAdd.save'), { type: ButtonType.Normal }).width('100%').height(46).borderRadius(12)
            .enabled(this.name.trim().length > 0 && this.weekMode !== 0)
            .backgroundColor(this.name.trim().length > 0 && this.weekMode !== 0 ? '#317CF4' : this.tile)
            .fontColor(this.name.trim().length > 0 && this.weekMode !== 0 ? Color.White : this.muted)
            .onClick(() => this.onSave(this.draft()))
        }.width('100%').padding(18).alignItems(HorizontalAlign.Start)
      }.width('100%')
    }.width('86%').constraintSize({ maxWidth: 420, maxHeight: '88%' }).scrollBar(BarState.Off)
      .backgroundColor(this.card).borderRadius(23).clip(true)
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }))
        .animation({ duration: 240, curve: Curve.Friction }))
  }
}
