import { CampusDay, Course, Palette, Period, TimetableBlock, campusDay, courseColor, localDate, timetableBlocks } from '../model/Iwut';
import { CourseSlotRange } from '../model/CourseDraft';

const DAY_HEADER_HEIGHT = 44;
const PERIOD_ROW_HEIGHT = 56;
const CELL_GAP = 4;

@Component
export struct Timetable {
  @Prop courses: Course[] = [];
  @Prop week: number = 1;
  @Prop termStart: string = '';
  @Prop now: number = Date.now();
  @Prop showMidday: boolean = false;
  @Prop showOtherWeek: boolean = true;
  @Prop weekendScroll: boolean = false;
  @Prop darkMode: boolean = false;
  @Prop surface: string = '#FFFFFF';
  @Prop courseOpacity: number = 100;
  @Prop otherOpacity: number = 14;
  @Prop locatorOpacity: number = 100;
  @Prop weekdays: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  @Prop monthSuffix: string = '月';
  @Prop dayParts: string[] = ['上\n午', '下\n午', '晚\n上'];
  @Prop otherWeekTag: string = '非本周';
  @Prop periods: Period[] = [];
  @Prop palette: Palette = { name: '默认', version: 1, colors: ['#496BE6'] };
  onSelect: (course: Course) => void = () => {};
  onAdd: (slot: CourseSlotRange) => void = () => {};
  private days: number[] = [1, 2, 3, 4, 5, 6, 7];

  private visiblePeriods(): Period[] {
    return this.periods.filter(period => this.showMidday || ![6, 7, 13].includes(period.number));
  }

  private dayPartHeight(first: number, last: number): number {
    return this.visiblePeriods().filter(period => period.number >= first && period.number <= last).length * PERIOD_ROW_HEIGHT;
  }

  private addFromBlock(day: number, block: TimetableBlock): void {
    const periods = this.visiblePeriods();
    const first = periods[block.firstRow];
    const last = periods[block.firstRow + block.rowCount - 1];
    if (first && last) this.onAdd({ day, sectionStart: first.number, sectionEnd: last.number });
  }

  private weekDate(day: number): Date {
    const date = localDate(this.termStart);
    date.setDate(date.getDate() + (this.week - 1) * 7 + day - 1);
    return date;
  }

  private today(day: number): boolean {
    const date = this.weekDate(day);
    if (!Number.isFinite(date.getTime())) return false;
    const current: CampusDay = campusDay(this.termStart, this.now);
    return !current.vacation && this.week === current.week && current.weekday === day;
  }

  private neutralText(): string {
    return this.darkMode ? '#C7C7C7' : '#616161';
  }

  private cardText(course: Course, belongsToWeek: boolean): string {
    if (!belongsToWeek) return this.neutralText();
    const color = courseColor(course, this.palette);
    const red = parseInt(color.slice(1, 3), 16);
    const green = parseInt(color.slice(3, 5), 16);
    const blue = parseInt(color.slice(5, 7), 16);
    return red * 0.299 + green * 0.587 + blue * 0.114 >= 145 ? '#171717' : '#FFFFFF';
  }

  @Builder
  private courseCard(course: Course, block: TimetableBlock) {
    Stack() {
      Row().width('100%').height('100%')
        .backgroundColor(block.belongsToWeek ? courseColor(course, this.palette) :
          (this.darkMode ? '#AAAAAA' : '#808080'))
        .opacity((block.belongsToWeek ? this.courseOpacity : this.otherOpacity) / 100)
      Column({ space: block.rowCount === 1 ? 0 : 2 }) {
        Column({ space: 2 }) {
          Row({ space: 2 }) {
            Text(course.name).layoutWeight(1).fontSize(block.rowCount === 1 ? 10 : 11).fontWeight(FontWeight.Bold)
              .fontColor(this.cardText(course, block.belongsToWeek))
              .lineHeight(block.rowCount === 1 ? 12 : 15)
              .maxLines(block.rowCount === 1 ? 2 : Math.min(6, block.rowCount * 2 - 1))
              .wordBreak(WordBreak.BREAK_ALL).textOverflow({ overflow: TextOverflow.Ellipsis })
            if (block.overlapCount > 0 && block.rowCount === 1) {
              Text('+' + block.overlapCount).fontSize(8).fontColor(this.cardText(course, block.belongsToWeek))
            }
          }.width('100%').alignItems(VerticalAlign.Top)
          if (!block.belongsToWeek && block.rowCount > 1) {
            Text(this.otherWeekTag).fontSize(9).fontColor(this.neutralText()).maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          if (block.overlapCount > 0 && block.rowCount > 1) {
            Text('+' + block.overlapCount).fontSize(9).fontColor(this.cardText(course, block.belongsToWeek))
          }
        }.layoutWeight(1).width('100%').alignItems(HorizontalAlign.Start).clip(true)
        if (course.room) {
          Text(course.room).width('100%').fontSize(block.rowCount === 1 ? 9 : 10)
            .lineHeight(block.rowCount === 1 ? 11 : 13)
            .fontColor(this.cardText(course, block.belongsToWeek))
            .maxLines(block.rowCount === 1 ? 2 : Math.min(6, block.rowCount + 2))
            .wordBreak(WordBreak.BREAK_ALL).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }.width('100%').height('100%')
        .padding({ left: 4, right: 4, top: block.rowCount === 1 ? 3 : 4, bottom: block.rowCount === 1 ? 3 : 5 })
        .alignItems(HorizontalAlign.Start)
    }
    .width('100%').height(PERIOD_ROW_HEIGHT * block.rowCount - CELL_GAP)
    .borderRadius(7).clip(true)
    .border({ width: block.belongsToWeek ? 0 : 1, color: this.darkMode ? '#3B3B3B' : '#ECECEC' })
    .accessibilityText(course.name + (course.room ? '，' + course.room : '') +
      (block.belongsToWeek ? '' : '，' + this.otherWeekTag) + (block.overlapCount > 0 ? '，+' + block.overlapCount : ''))
    .onClick(() => this.onSelect(course))
  }

  @Builder
  private sidebarLabel(label: string, first: number, last: number) {
    if (this.dayPartHeight(first, last) > 0) {
      Column() {
        Text(label).fontSize(10).lineHeight(14).fontWeight(FontWeight.Medium)
          .fontColor(this.neutralText()).textAlign(TextAlign.Center)
      }.height(this.dayPartHeight(first, last)).width('100%').justifyContent(FlexAlign.Center)
    }
  }

  @Builder
  private sidebar() {
    Column() {
      Column({ space: 2 }) {
        if (Number.isFinite(this.weekDate(1).getTime())) {
          Text((this.weekDate(1).getMonth() + 1).toString()).fontSize(13).fontWeight(FontWeight.Bold)
            .fontColor(this.neutralText())
          if (this.monthSuffix) {
            Text(this.monthSuffix).fontSize(9).fontColor(this.neutralText())
          }
        }
      }.width('100%').height(DAY_HEADER_HEIGHT).justifyContent(FlexAlign.Center)
      this.sidebarLabel(this.dayParts[0], 1, 5)
      this.sidebarLabel(this.dayParts[1], 6, 12)
      this.sidebarLabel(this.dayParts[2], 13, 16)
    }.width(27)
  }

  @Builder
  private dateHeader(day: number) {
    Stack() {
      if (this.today(day)) {
        Row().width('92%').constraintSize({ maxWidth: 40 }).height(38).borderRadius(19)
          .backgroundColor(this.darkMode ? '#162E55' : '#E2EEFF')
          .border({ width: 1, color: '#3478E5' }).opacity(this.locatorOpacity / 100)
      }
      Column({ space: 2 }) {
        Text(this.weekdays[day - 1]).fontSize(11).fontWeight(FontWeight.Bold)
          .fontColor(this.today(day) ? (this.darkMode ? '#A5C9FF' : '#164DA5') : this.neutralText())
        if (Number.isFinite(this.weekDate(day).getTime())) {
          Text(this.weekDate(day).getDate().toString()).fontSize(11)
            .fontColor(this.today(day) ? (this.darkMode ? '#A5C9FF' : '#164DA5') : this.neutralText())
        }
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    }.width('100%').height(DAY_HEADER_HEIGHT)
  }

  @Builder
  private dayColumns() {
    Row({ space: CELL_GAP }) {
      ForEach(this.days, (day: number) => {
        Column() {
          this.dateHeader(day)
          ForEach(timetableBlocks(this.courses, this.visiblePeriods(), day, this.week, this.showOtherWeek),
            (block: TimetableBlock) => {
              Stack() {
                if (block.course) {
                  this.courseCard(block.course, block)
                } else {
                  Row().width('100%').height(PERIOD_ROW_HEIGHT * block.rowCount - CELL_GAP)
                    .backgroundColor(this.darkMode ? '#0FFFFFFF' : '#08000000').borderRadius(7)
                    .onClick(() => this.addFromBlock(day, block))
                }
              }.width('100%').height(PERIOD_ROW_HEIGHT * block.rowCount)
            }, (block: TimetableBlock) => JSON.stringify(block))
        }.layoutWeight(1)
      }, (day: number) => day.toString())
    }.alignItems(VerticalAlign.Top).width(this.weekendScroll ? '132%' : '100%')
  }

  build() {
    Row({ space: CELL_GAP }) {
      this.sidebar()
      if (this.weekendScroll) {
        Scroll() {
          this.dayColumns()
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).layoutWeight(1)
      } else {
        Stack() {
          this.dayColumns()
        }.layoutWeight(1)
      }
    }.width('100%').alignItems(VerticalAlign.Top).padding({ left: 2, right: 4, bottom: 4 })
      .backgroundColor(this.surface)
  }
}
