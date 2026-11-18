import { Course, Period, validCourses } from '../model/Iwut';
import { COURSE_WEEKS, QuickCourseDraft, sectionLabel, timeToSections, weekList, weekRanges } from '../model/CourseDraft';

interface DraftSlot {
  id: number;
  day: number;
  start: string;
  end: string;
  weeks: number[];
  room: string;
  directTime: boolean;
  timingChanged: boolean;
  startTime: string;
  endTime: string;
  note: string;
  seat?: number;
}

interface EditorField {
  label: string;
  value: string;
  change: (value: string) => void;
  locked?: boolean;
  inputType?: InputType;
}

function emptySlot(id: number): DraftSlot {
  return {
    id, day: 1, start: '1', end: '2', weeks: [], room: '', directTime: false, timingChanged: false,
    startTime: '', endTime: '', note: ''
  };
}

@Component
export struct CourseEditor {
  initial: Course[] = [];
  prefill: QuickCourseDraft | null = null;
  onSave: (records: Course[]) => void = () => {};
  onShare: (records: Course[]) => void = () => {};
  onDelete: () => void = () => {};
  t: (key: string) => string = (key: string): string => key;
  @Prop weekdays: string[] = [];
  @Prop periods: Period[] = [];
  @Prop ink: string = '#172136';
  @Prop muted: string = '#52627A';
  @Prop blue: string = '#2459C4';
  @Prop tile: string = '#F2F5FA';
  @Prop card: string = '#FFFFFF';
  @Prop line: string = '#E8EDF4';
  @State name: string = '';
  @State teacher: string = '';
  @State slots: DraftSlot[] = [];
  @State expanded: number = -1;
  @State problem: string = '';
  private nextId: number = 1;

  aboutToAppear(): void {
    const first = this.initial[0];
    this.name = first?.name ?? this.prefill?.name ?? '';
    this.teacher = first?.teacher ?? this.prefill?.teacher ?? '';
    const groups = new Map<string, DraftSlot>();
    for (const record of this.initial) {
      const directTime = record.timeMode === 'time' || (Boolean(record.startTime) && Boolean(record.endTime));
      const key = JSON.stringify([record.day, record.sectionStart, record.sectionEnd, record.room, directTime,
        record.startTime, record.endTime, record.note, record.seat]);
      let slot = groups.get(key);
      if (!slot) {
        slot = {
          id: this.nextId++, day: record.day, start: record.sectionStart.toString(), end: record.sectionEnd.toString(),
          weeks: [], room: record.room, directTime, timingChanged: false,
          startTime: record.startTime ?? '', endTime: record.endTime ?? '', note: record.note ?? '', seat: record.seat
        };
        groups.set(key, slot);
      }
      const weeks = slot.weeks.concat(COURSE_WEEKS.filter(week => week >= record.weekStart && week <= record.weekEnd));
      slot.weeks = COURSE_WEEKS.filter(week => weeks.includes(week));
    }
    this.slots = Array.from(groups.values());
    if (this.slots.length === 0) {
      const slot = emptySlot(this.nextId++);
      if (this.prefill) {
        slot.day = this.prefill.slot.day;
        slot.start = this.prefill.slot.sectionStart.toString();
        slot.end = this.prefill.slot.sectionEnd.toString();
        slot.room = this.prefill.room;
        slot.weeks = this.prefill.weeks.slice();
      }
      this.slots = [slot];
      this.expanded = slot.id;
    }
  }

  private slot(id: number): DraftSlot {
    return this.slots.find(slot => slot.id === id) ?? emptySlot(id);
  }

  private change(id: number, update: (slot: DraftSlot) => void): void {
    this.slots = this.slots.map(slot => {
      if (slot.id !== id) return slot;
      const next: DraftSlot = {
        id: slot.id, day: slot.day, start: slot.start, end: slot.end, weeks: slot.weeks, room: slot.room,
        directTime: slot.directTime, timingChanged: slot.timingChanged, startTime: slot.startTime,
        endTime: slot.endTime, note: slot.note, seat: slot.seat
      };
      update(next);
      return next;
    });
    this.problem = '';
  }

  private setWeek(id: number, week: number): void {
    this.change(id, draft => {
      draft.weeks = draft.weeks.includes(week) ? draft.weeks.filter(value => value !== week) : draft.weeks.concat(week);
    });
  }

  private switchTime(id: number): void {
    this.change(id, draft => {
      if (draft.directTime) {
        const range = timeToSections(this.periods, draft.day, draft.startTime, draft.endTime);
        if (range) {
          draft.start = range.sectionStart.toString();
          draft.end = range.sectionEnd.toString();
        }
      } else if (!draft.startTime && !draft.endTime) {
        draft.startTime = this.periods.find(period => period.number === Number(draft.start))?.start ?? '';
        draft.endTime = this.periods.find(period => period.number === Number(draft.end))?.end ?? '';
      }
      draft.directTime = !draft.directTime;
      draft.timingChanged = true;
    });
  }

  private slotProblem(key: string, index: number): Course[] {
    this.expanded = this.slots[index].id;
    this.problem = this.t(key).replace('{n}', (index + 1).toString());
    return [];
  }

  private records(): Course[] {
    if (!this.name.trim()) {
      this.problem = this.t('courseAdd.needCourseName');
      return [];
    }
    const output: Course[] = [];
    for (let index = 0; index < this.slots.length; index++) {
      const draft = this.slots[index];
      const ranges = weekRanges(draft.weeks);
      if (!ranges.length) return this.slotProblem('courseAdd.slotNoWeeks', index);
      const timeRange = draft.directTime ? timeToSections(this.periods, draft.day, draft.startTime, draft.endTime) : null;
      if (draft.directTime && !timeRange) return this.slotProblem('courseAdd.slotInvalidTime', index);
      const updatedSections = draft.timingChanged ? timeRange : null;
      for (const range of ranges) {
        const wanted: Course = {
          name: this.name.trim(), teacher: this.teacher.trim(), room: draft.room.trim(), day: draft.day,
          sectionStart: updatedSections?.sectionStart ?? Number(draft.start),
          sectionEnd: updatedSections?.sectionEnd ?? Number(draft.end),
          weekStart: range.start, weekEnd: range.end, timeMode: draft.directTime ? 'time' : 'sections',
          startTime: draft.directTime ? draft.startTime.trim() : undefined,
          endTime: draft.directTime ? draft.endTime.trim() : undefined,
          note: draft.note.trim() || undefined, seat: draft.seat, source: 'manual'
        };
        const verified = validCourses([wanted]);
        if (verified.length !== 1) return this.slotProblem('courseAdd.slotInvalidRange', index);
        output.push(verified[0]);
      }
    }
    this.problem = '';
    return validCourses(output);
  }

  private submit(share: boolean): void {
    const records = this.records();
    if (!records.length) return;
    if (share) this.onShare(records);
    else this.onSave(records);
  }

  private sectionText(id: number): string {
    const slot = this.slot(id);
    const timeRange = slot.directTime && slot.timingChanged ?
      timeToSections(this.periods, slot.day, slot.startTime, slot.endTime) : null;
    return sectionLabel(this.t('schedule.weekdayWithSection'), this.weekdays[slot.day - 1] ?? '',
      timeRange?.sectionStart ?? (Number(slot.start) || 1), timeRange?.sectionEnd ?? (Number(slot.end) || 1));
  }

  private description(id: number): string {
    const slot = this.slot(id);
    const start = slot.directTime ? slot.startTime : this.periods.find(period => period.number === Number(slot.start))?.start;
    const end = slot.directTime ? slot.endTime : this.periods.find(period => period.number === Number(slot.end))?.end;
    return [slot.room, start && end ? start + ' – ' + end : ''].filter(value => value.length > 0).join(' · ');
  }

  @Builder
  private field($$: EditorField) {
    Column({ space: 6 }) {
      Text($$.label).width('100%').fontSize(13).fontColor(this.muted)
      TextInput({ text: $$.value }).type($$.inputType ?? InputType.Normal)
        .fontSize(15).fontColor($$.locked ? this.muted : this.ink).backgroundColor(this.tile)
        .borderRadius(10).height(44).width('100%').enabled(!$$.locked)
        .onChange(value => $$.change(value))
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private weekGrid(id: number) {
    Row({ space: 8 }) {
      Text(this.t('courseAdd.weeks')).fontSize(13).fontColor(this.muted).layoutWeight(1)
      Button(this.t('courseAdd.selectAll'), { type: ButtonType.Normal }).fontSize(12)
        .fontColor(this.blue).backgroundColor(Color.Transparent)
        .onClick(() => this.change(id, draft => { draft.weeks = COURSE_WEEKS.slice(); }))
      Button(this.t('courseAdd.clear'), { type: ButtonType.Normal }).fontSize(12)
        .fontColor(this.blue).backgroundColor(Color.Transparent)
        .onClick(() => this.change(id, draft => { draft.weeks = []; }))
    }.width('100%')
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(COURSE_WEEKS, (week: number) => {
        Column() {
          Button(week.toString(), { type: ButtonType.Normal }).width('100%').height(34).borderRadius(8).padding(0)
            .backgroundColor(this.slot(id).weeks.includes(week) ? '#317CF4' : this.tile)
            .fontColor(this.slot(id).weeks.includes(week) ? Color.White : this.ink)
            .onClick(() => this.setWeek(id, week))
        }.width('20%').padding(3)
      }, (week: number) => week.toString())
    }.width('100%')
  }

  @Builder
  private slotFields(id: number) {
    Column({ space: 10 }) {
      Text(this.t('courseAdd.weekday')).fontSize(13).fontColor(this.muted).width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.weekdays, (day: string, index: number) => {
          Column() {
            Button(day, { type: ButtonType.Normal }).width('100%').height(34).borderRadius(8).padding(0).fontSize(12)
              .backgroundColor(this.slot(id).day === index + 1 ? '#317CF4' : this.tile)
              .fontColor(this.slot(id).day === index + 1 ? Color.White : this.ink)
              .onClick(() => this.change(id, draft => { draft.day = index + 1; }))
          }.width('25%').padding(3)
        }, (day: string) => day)
      }.width('100%')
      this.field({
        label: this.t('courseAdd.room'), value: this.slot(id).room,
        change: (value: string) => this.change(id, draft => { draft.room = value; })
      })
      this.weekGrid(id)
      Text(this.t(this.slot(id).directTime ? 'courseAdd.directTime' : 'courseAdd.sectionRange'))
        .fontSize(13).fontColor(this.muted).width('100%')
      if (this.slot(id).directTime) {
        Row({ space: 8 }) {
          TextInput({ text: this.slot(id).startTime, placeholder: this.t('courseAdd.startTime') })
            .layoutWeight(1).height(42).fontColor(this.ink).backgroundColor(this.tile)
            .onChange(value => this.change(id, draft => { draft.startTime = value; draft.timingChanged = true; }))
          TextInput({ text: this.slot(id).endTime, placeholder: this.t('courseAdd.endTime') })
            .layoutWeight(1).height(42).fontColor(this.ink).backgroundColor(this.tile)
            .onChange(value => this.change(id, draft => { draft.endTime = value; draft.timingChanged = true; }))
        }.width('100%')
      } else {
        Row({ space: 8 }) {
          TextInput({ text: this.slot(id).start, placeholder: '开始节次' }).type(InputType.Number)
            .layoutWeight(1).height(42).fontColor(this.ink).backgroundColor(this.tile)
            .onChange(value => this.change(id, draft => { draft.start = value; }))
          TextInput({ text: this.slot(id).end, placeholder: '结束节次' }).type(InputType.Number)
            .layoutWeight(1).height(42).fontColor(this.ink).backgroundColor(this.tile)
            .onChange(value => this.change(id, draft => { draft.end = value; }))
        }.width('100%')
      }
      Button(this.t(this.slot(id).directTime ? 'courseAdd.switchToSections' : 'courseAdd.switchToTime'),
        { type: ButtonType.Normal }).fontSize(12).fontColor(this.blue).backgroundColor(Color.Transparent)
        .onClick(() => this.switchTime(id))
      this.field({
        label: '备注', value: this.slot(id).note,
        change: (value: string) => this.change(id, draft => { draft.note = value; })
      })
      if (this.slots.length > 1) {
        Button(this.t('courseAdd.deleteSlot'), { type: ButtonType.Normal }).backgroundColor(Color.Transparent)
          .fontColor('#D12D43').width('100%').onClick(() => {
            this.slots = this.slots.filter(slot => slot.id !== id);
            this.expanded = -1;
            this.problem = '';
          })
      }
    }.width('100%').padding({ left: 14, right: 14, bottom: 14 })
  }

  @Builder
  private slotCard(id: number) {
    Column() {
      Row({ space: 11 }) {
        Text((this.slots.findIndex(slot => slot.id === id) + 1).toString()).width(31).height(31)
          .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Color.White).textAlign(TextAlign.Center)
          .borderRadius(16).backgroundColor('#317CF4')
        Column({ space: 5 }) {
          Text(this.sectionText(id)).fontSize(15).fontColor(this.ink).fontWeight(FontWeight.Bold).width('100%')
          if (this.description(id)) {
            Text(this.description(id)).fontSize(12).fontColor(this.muted).width('100%')
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }.layoutWeight(1)
        Text(this.slot(id).weeks.length ? weekList(this.slot(id).weeks) + this.t('courseAdd.weeksUnit') :
          this.t('courseAdd.weeksNotSelected')).fontSize(11).fontColor(this.blue).maxLines(2)
          .constraintSize({ maxWidth: 76 }).padding({ left: 7, right: 7, top: 4, bottom: 4 })
          .backgroundColor(this.tile).borderRadius(8)
        SymbolGlyph(this.expanded === id ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
          .fontSize(15).fontColor([this.muted])
      }.width('100%').constraintSize({ minHeight: 65 }).padding(14)
        .onClick(() => { this.expanded = this.expanded === id ? -1 : id; })
      if (this.expanded === id) {
        this.slotFields(id)
      }
    }.width('100%').backgroundColor(this.card).borderRadius(15)
  }

  @Builder
  private action(icon: Resource, label: string, fg: ResourceColor, bg: ResourceColor, run: () => void) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 5 }) {
        SymbolGlyph(icon).fontSize(17).fontColor([fg])
        Text(label).fontSize(14).fontWeight(FontWeight.Medium).fontColor(fg)
      }
    }.layoutWeight(1).height(46).padding(0).borderRadius(12).backgroundColor(bg).onClick(() => run())
  }

  build() {
    Column({ space: 13 }) {
      Column({ space: 12 }) {
        this.field({
          label: this.t('courseAdd.courseName'), value: this.name, locked: this.initial.length > 0,
          change: (value: string) => { this.name = value; this.problem = ''; }
        })
        Divider().color(this.line)
        this.field({
          label: this.t('courseAdd.teacher'), value: this.teacher,
          change: (value: string) => { this.teacher = value; }
        })
      }.width('100%').backgroundColor(this.card).borderRadius(15).padding(14)
      ForEach(this.slots, (slot: DraftSlot) => { this.slotCard(slot.id) }, (slot: DraftSlot) => slot.id.toString())
      Button('+  ' + this.t('courseAdd.addSlot'), { type: ButtonType.ROUNDED_RECTANGLE }).width('100%').height(44)
        .backgroundColor(this.card).fontColor(this.blue).borderRadius(12)
        .border({ width: 1, color: this.blue })
        .onClick(() => {
          const slot = emptySlot(this.nextId++);
          this.slots = this.slots.concat(slot);
          this.expanded = slot.id;
        })
      if (this.problem) Text(this.problem).fontSize(13).fontColor('#D12D43').width('100%')
      Row({ space: 8 }) {
        this.action($r('sys.symbol.square_and_arrow_down'), this.t('common.save'), Color.White, '#317CF4',
          () => this.submit(false))
        if (this.initial.length > 0) {
          this.action($r('sys.symbol.qrcode'), this.t('common.share'), this.blue, this.card, () => this.submit(true))
          this.action($r('sys.symbol.trash'), this.t('common.delete'), Color.White, '#D92841', () => this.onDelete())
        }
      }.width('100%')
    }.width('100%')
  }
}
