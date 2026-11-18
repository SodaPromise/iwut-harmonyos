import {
  ButtonModifier, ColorMetrics, LengthMetrics, SegmentButtonV2ItemOptions, SegmentButtonV2Items, TabSegmentButtonV2
} from '@kit.ArkUI';
import lazy { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { CampusDay, Exam, campusDay } from '../model/Iwut';
import { examEnd, examStart } from '../services/AcademicSchedule';

const SUMMARY_HEIGHT = 154;
const FILTER_HEIGHT = 44;
const FILTER_PADDING = 4;
const FILTER_EFFECT_INSET = 6;
const CONTROLS_HEIGHT = SUMMARY_HEIGHT + 14 + FILTER_HEIGHT + FILTER_EFFECT_INSET;
const DAY_MS = 86400000;
const CAMPUS_OFFSET_MS = 8 * 3600000;

enum ExamStatus {
  Upcoming,
  Ongoing,
  Finished,
  Unknown
}

@Component
export struct ExamSchedule {
  @Prop exams: Exam[] = [];
  @Prop notArranged: Exam[] = [];
  @Prop term: string = '';
  @Prop refreshedAt: string = '';
  @Prop now: number = 0;
  @Prop tab: number = 0;
  @Prop reminderEnabled: boolean = false;
  @Prop darkMode: boolean = false;
  @Prop immersive: boolean = false;
  @Prop ink: string = '#172136';
  @Prop muted: string = '#52627A';
  @Prop blue: string = '#2459C4';
  @Prop card: string = '#FFFFFF';
  @Prop pageBackground: string = '#F2F5FA';
  @Prop divider: string = '#E8EDF4';
  @Prop weekdays: string[] = [];
  buttonStyle: ButtonModifier = new ButtonModifier();
  t: (key: string) => string = (key: string) => key;
  onTab: (tab: number) => void = () => {};
  onReminder: () => void = () => {};
  onRefresh: () => void = () => {};
  private readonly tabs: string[] = ['exam.tabUpcoming', 'exam.tabFinished', 'exam.tabNotArranged'];
  private filterBackdropMaterial?: uiMaterial.Material;

  aboutToAppear(): void {
    if (this.immersive && deviceInfo.apiAvailable('26.0.0')) {
      this.filterBackdropMaterial = new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
        materialColor: Color.Transparent,
        applyShadow: false,
        colorInvert: true,
        interactive: true,
        lightEffect: {}
      });
    }
  }

  private status(exam: Exam): ExamStatus {
    const raw = this.rawStatus(exam);
    const start = examStart(exam);
    const end = examEnd(exam);
    if (raw === '2' || raw.includes('完成') || raw.includes('已结束')) return ExamStatus.Finished;
    const upcoming = raw === '0' || raw.includes('未开始');
    const ongoing = raw === '1' || raw.includes('进行');
    if (raw && !upcoming && !ongoing) return ExamStatus.Unknown;
    if (Number.isFinite(end) && end <= this.now) return ExamStatus.Finished;
    if (Number.isFinite(start)) {
      if (start > this.now) return ExamStatus.Upcoming;
      if (end > this.now) return ExamStatus.Ongoing;
    }
    if (upcoming) return ExamStatus.Upcoming;
    return ongoing ? ExamStatus.Ongoing : ExamStatus.Unknown;
  }

  private rawStatus(exam: Exam): string {
    const value = exam.rawStatus?.trim() ?? '';
    return value === '-' || value === 'null' ? '' : value;
  }

  private examsFor(tab: number): Exam[] {
    if (tab === 2) return this.notArranged;
    const direction = tab === 1 ? -1 : 1;
    return this.exams.filter(exam => (this.status(exam) === ExamStatus.Finished) === (tab === 1))
      .sort((left, right) => direction * (examStart(left) - examStart(right)));
  }

  private statusLabel(exam: Exam, status: ExamStatus): string {
    switch (status) {
      case ExamStatus.Ongoing: return this.t('exam.statusOngoing');
      case ExamStatus.Finished: return this.t('exam.statusFinished');
      case ExamStatus.Upcoming: {
        const days = Math.floor((examStart(exam) + CAMPUS_OFFSET_MS) / DAY_MS) -
          Math.floor((this.now + CAMPUS_OFFSET_MS) / DAY_MS);
        if (!Number.isFinite(days)) return this.t('exam.statusUpcoming');
        if (days <= 0) return this.t('exam.countdownToday');
        if (days === 1) return this.t('exam.countdownTomorrow');
        return this.t('exam.countdownDays').replace('{n}', days.toString());
      }
      default: return this.rawStatus(exam) || this.t('exam.statusUnknown');
    }
  }

  private statusColor(status: ExamStatus): string {
    switch (status) {
      case ExamStatus.Finished: return this.muted;
      case ExamStatus.Ongoing: return this.darkMode ? '#85DDBA' : '#166A4C';
      case ExamStatus.Unknown: return this.darkMode ? '#FFCF82' : '#815200';
      default: return this.blue;
    }
  }

  private statusBackground(status: ExamStatus): string {
    switch (status) {
      case ExamStatus.Finished: return this.pageBackground;
      case ExamStatus.Ongoing: return this.darkMode ? '#12382C' : '#DDF7E9';
      case ExamStatus.Unknown: return this.darkMode ? '#3C2D17' : '#FFF0D5';
      default: return this.darkMode ? '#203956' : '#DCEAFF';
    }
  }

  private timeText(exam: Exam, day: CampusDay): string {
    const range = [exam.startTime ?? '', exam.endTime ?? ''].filter(time => time.length > 0).join('–');
    const weekday = this.weekdays[day.weekday - 1] ?? '';
    if (range) return weekday ? weekday + ' ' + range : range;
    return exam.date || this.t('exam.statusUnknown');
  }

  private refreshText(): string {
    const timestamp = Date.parse(this.refreshedAt);
    if (!Number.isFinite(timestamp)) return this.t('exam.lastRefreshed').replace('{time}', this.refreshedAt);
    const date = new Date(timestamp);
    const time = date.getHours().toString().padStart(2, '0') + ':' + date.getMinutes().toString().padStart(2, '0');
    const value = date.getFullYear() + '/' + (date.getMonth() + 1).toString().padStart(2, '0') + '/' +
      date.getDate().toString().padStart(2, '0') + ' ' + time;
    return this.t('exam.lastRefreshed').replace('{time}', value);
  }

  private filterItems(): SegmentButtonV2Items {
    const items = this.tabs.map((key, index): SegmentButtonV2ItemOptions => {
      const count = this.examsFor(index).length;
      const label = this.t(key);
      return { text: count > 0 ? label + ' ' + count.toString() : label };
    });
    return new SegmentButtonV2Items(items);
  }

  @Builder
  private summary() {
    Column({ space: 9 }) {
      Row({ space: 10 }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.calendar')).fontSize(24).fontColor([this.blue])
        }.width(44).height(44).borderRadius(14).backgroundColor(this.statusBackground(ExamStatus.Upcoming))
        Column({ space: 3 }) {
          Text(this.term || this.t('exam.noTerm')).fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.ink)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.refreshedAt ? this.t('exam.importedCount').replace('{n}', this.exams.length.toString()) :
            this.t('exam.notImported')).fontSize(12).fontColor(this.muted)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph(this.reminderEnabled ? $r('sys.symbol.bell_fill') : $r('sys.symbol.bell'))
            .fontSize(22).fontColor([this.reminderEnabled ? this.blue : this.muted])
        }.width(44).height(44).padding(0).backgroundColor(Color.Transparent)
          .attributeModifier(this.buttonStyle).accessibilityText(this.t('exam.reminderEntry'))
          .onClick(() => this.onReminder())
        if (this.refreshedAt) {
          Button({ type: ButtonType.ROUNDED_RECTANGLE }) {
            SymbolGlyph($r('sys.symbol.arrow_2_circlepath')).fontSize(21).fontColor([Color.White])
          }.width(44).height(44).padding(0).borderRadius(13)
            .attributeModifier(this.buttonStyle).backgroundColor(this.immersive ? '#D12167D4' : '#286EDB')
            .accessibilityText(this.t('exam.reimport')).onClick(() => this.onRefresh())
        }
      }.width('100%').height(44)
      if (this.refreshedAt) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.clock')).fontSize(16).fontColor([this.muted])
          Text(this.refreshText()).layoutWeight(1).fontSize(12).fontColor(this.muted)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.height(38).width('100%').padding({ left: 12, right: 12 }).backgroundColor(this.pageBackground).borderRadius(12)
      } else {
        Button(this.t('exam.importNow'), { type: ButtonType.ROUNDED_RECTANGLE })
          .width('100%').height(38).fontSize(14).fontColor(Color.White).borderRadius(12)
          .attributeModifier(this.buttonStyle).backgroundColor(this.immersive ? '#D12167D4' : '#286EDB')
          .onClick(() => this.onRefresh())
      }
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.info_circle')).fontSize(13).fontColor([this.muted])
        Text(this.t('exam.disclaimer')).fontSize(11).fontColor(this.muted)
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.width('100%').constraintSize({ minHeight: 22 }).justifyContent(FlexAlign.Center)
    }.width('100%').height(SUMMARY_HEIGHT).padding(14)
      .justifyContent(FlexAlign.Center).backgroundColor(this.card).borderRadius(16)
  }

  @Builder
  private filters() {
    TabSegmentButtonV2({
      items: this.filterItems(),
      selectedIndex: this.tab,
      $selectedIndex: (index: number) => this.onTab(index),
      buttonMinHeight: LengthMetrics.vp(FILTER_HEIGHT),
      buttonPadding: LengthMetrics.vp(FILTER_PADDING),
      itemMinHeight: LengthMetrics.vp(FILTER_HEIGHT - 2 * FILTER_PADDING),
      itemFontSize: LengthMetrics.fp(13),
      itemSelectedFontSize: LengthMetrics.fp(13),
      itemSelectedFontWeight: FontWeight.Bold,
      itemFontColor: ColorMetrics.resourceColor(
        this.filterBackdropMaterial ? $r('sys.color.font_secondary') : this.muted),
      itemSelectedFontColor: ColorMetrics.resourceColor(
        this.filterBackdropMaterial ? $r('sys.color.font_primary') : this.ink),
      buttonBackgroundColor: ColorMetrics.resourceColor(Color.Transparent),
      itemSelectedBackgroundColor: ColorMetrics.resourceColor(
        this.filterBackdropMaterial ? (this.darkMode ? '#26FFFFFF' : '#1F000000') : this.card),
      backgroundSystemMaterial: this.filterBackdropMaterial,
      enableStateAnimation: true
    }).width('100%').height(FILTER_HEIGHT)
  }

  @Builder
  private controls() {
    Column({ space: 14 }) {
      this.summary()
      this.filters()
    }.width('100%').height(CONTROLS_HEIGHT).padding({ bottom: FILTER_EFFECT_INSET })
  }

  @Builder
  private meta(icon: Resource, value: string) {
    Row({ space: 8 }) {
      SymbolGlyph(icon).fontSize(15).fontColor([this.muted])
      Text(value).layoutWeight(1).fontSize(13).fontColor(this.muted)
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  @Builder
  private scheduledCard(exam: Exam, day: CampusDay, status: ExamStatus) {
    Row({ space: 12 }) {
      Column({ space: 1 }) {
        if (Number.isFinite(day.day)) {
          Text(day.day.toString()).fontSize(23).fontWeight(FontWeight.Bold).fontColor(this.statusColor(status))
          Text(day.month.toString() + this.t('common.monthSuffix')).fontSize(11).fontWeight(FontWeight.Medium)
            .fontColor(this.statusColor(status))
        } else {
          SymbolGlyph($r('sys.symbol.calendar')).fontSize(21).fontColor([this.statusColor(status)])
        }
      }.width(52).height(52).justifyContent(FlexAlign.Center).borderRadius(14)
        .backgroundColor(this.statusBackground(status))
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Column({ space: 4 }) {
            Text(exam.courseName || this.t('exam.unknownCourse')).fontSize(16).fontWeight(FontWeight.Bold)
              .fontColor(this.ink)
            if (exam.courseCode) Text(exam.courseCode).fontSize(12).fontColor(this.muted)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Text(this.statusLabel(exam, status)).fontSize(11).fontWeight(FontWeight.Bold)
            .fontColor(this.statusColor(status)).backgroundColor(this.statusBackground(status))
            .padding({ top: 4, bottom: 4, left: 9, right: 9 }).borderRadius(12)
            .constraintSize({ maxWidth: '44%' }).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.width('100%').alignItems(VerticalAlign.Top)
        Divider().color(this.divider)
        Column({ space: 7 }) {
          this.meta($r('sys.symbol.clock'), this.timeText(exam, day))
          this.meta($r('sys.symbol.position'), exam.place || this.t('exam.noPlace'))
          this.meta($r('sys.symbol.square_grid_2x2'),
            this.t('exam.seatNo') + ' · ' + (exam.seatNo || this.t('exam.seatPending')))
          if (exam.teacher) this.meta($r('sys.symbol.person'), exam.teacher)
          if (exam.description) Text(exam.description).fontSize(12).fontColor(this.muted).width('100%')
        }.width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').alignItems(VerticalAlign.Top).padding(14).borderRadius(16).backgroundColor(this.card)
  }

  @Builder
  private unscheduledCard(exam: Exam) {
    Row({ space: 12 }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.hourglass')).fontSize(20).fontColor([this.statusColor(ExamStatus.Unknown)])
      }.width(44).height(44).borderRadius(14).backgroundColor(this.statusBackground(ExamStatus.Unknown))
      Column({ space: 5 }) {
        Text(exam.courseName || this.t('exam.unknownCourse')).fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.ink)
        if (exam.courseCode || exam.teacher) {
          Text([exam.courseCode, exam.teacher].filter(value => value.length > 0).join(' · '))
            .fontSize(12).fontColor(this.muted)
        }
        if (exam.description) Text(exam.description).fontSize(12).fontColor(this.muted)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').padding(14).borderRadius(16).backgroundColor(this.card)
  }

  @Builder
  private emptyState(title: string, subtitle: string) {
    Column({ space: 8 }) {
      Text(this.t(title)).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.ink).textAlign(TextAlign.Center)
      Text(this.t(subtitle)).fontSize(13).fontColor(this.muted).textAlign(TextAlign.Center)
    }.width('100%').padding(25).backgroundColor(this.card).borderRadius(16)
  }

  build() {
    Column({ space: 16 - FILTER_EFFECT_INSET }) {
      Navigation()
        .mode(NavigationMode.Stack).hideBackButton(true).hideToolBar(true)
        .title({ builder: this.controls, height: CONTROLS_HEIGHT }, { backgroundColor: Color.Transparent })
        .width('100%').height(CONTROLS_HEIGHT)
      if (!this.refreshedAt && this.exams.length === 0 && this.notArranged.length === 0) {
        this.emptyState('exam.emptyTitle', 'exam.emptySub')
      } else if (this.examsFor(this.tab).length === 0) {
        this.emptyState(this.tab === 0 ? 'exam.emptyUpcoming' : this.tab === 1 ?
          'exam.emptyFinished' : 'exam.emptyNotArranged',
          this.tab === 2 ? 'exam.emptyNotArrangedSub' : 'exam.emptyCurrentSub')
      } else {
        ForEach(this.examsFor(this.tab), (exam: Exam, index: number) => {
          if (this.tab === 2) {
            this.unscheduledCard(exam)
          } else {
            this.scheduledCard(exam, campusDay('', examStart(exam)), this.status(exam))
          }
        }, (exam: Exam, index: number) => this.tab + ':' + exam.id + ':' + index)
      }
    }.width('100%')
  }
}
