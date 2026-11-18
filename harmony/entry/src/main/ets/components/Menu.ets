export class MenuRow {
  id: string;
  label: string;
  value: string;
  checked?: boolean;
  slider?: number;
  maximum: number = 100;
  available: boolean;

  constructor(id: string, label: string, value: string = '', checked?: boolean, available: boolean = true) {
    this.id = id;
    this.label = label;
    this.value = value;
    this.checked = checked;
    this.available = available;
  }
}

export class MenuGroup {
  title: string;
  rows: MenuRow[];

  constructor(title: string, rows: MenuRow[]) {
    this.title = title;
    this.rows = rows;
  }
}

@Component
export struct MenuGroups {
  @Prop groups: MenuGroup[] = [];
  @Prop textColor: string = '#172136';
  @Prop muted: string = '#52627A';
  @Prop card: string = '#FFFFFF';
  @Prop divider: string = '#E8EDF4';
  onAction: (id: string) => void = () => {};
  onToggle: (id: string, checked: boolean) => void = () => {};
  onSlide: (id: string, value: number) => void = () => {};

  @Builder
  private menuRow(entry: MenuRow) {
    if (entry.slider !== undefined) {
      Column() {
        Row() {
          Text(entry.label).fontSize(15).fontColor(this.textColor).layoutWeight(1)
          Text(entry.value).fontSize(13).fontColor(this.muted)
        }.width('100%').padding({ left: 16, right: 16, top: 14 })
        Slider({ value: entry.slider, min: 0, max: entry.maximum, step: 1 })
          .onChange((value, mode) => {
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) this.onSlide(entry.id, value);
          })
      }.width('100%')
    } else {
      Row({ space: 8 }) {
        Text(entry.label).fontSize(15).fontColor(this.textColor).layoutWeight(1)
        if (entry.value) {
          Text(entry.value).fontSize(12).fontColor(this.muted).maxLines(2).constraintSize({ maxWidth: '52%' })
            .textOverflow({ overflow: TextOverflow.Ellipsis }).textAlign(TextAlign.End)
        }
        if (entry.checked !== undefined) {
          Toggle({ type: ToggleType.Switch, isOn: entry.checked })
            .enabled(entry.available)
            .onChange(value => this.onToggle(entry.id, value))
        } else if (entry.id === 'pastePalette') {
          PasteButton().onClick((_, result) => {
            if (result === PasteButtonOnClickResult.SUCCESS) this.onAction(entry.id);
          })
        } else if (entry.available) {
          Text('›').fontSize(22).fontColor(this.muted)
        }
      }.constraintSize({ minHeight: 54 }).padding({ left: 16, right: 16, top: 9, bottom: 9 })
        .width('100%').opacity(entry.available ? 1 : 0.65)
        .onClick(() => {
          if (entry.available && entry.checked === undefined && entry.id !== 'pastePalette') this.onAction(entry.id);
        })
    }
  }

  build() {
    Column({ space: 20 }) {
      ForEach(this.groups, (group: MenuGroup) => {
        Column({ space: 7 }) {
          if (group.title) Text(group.title).fontSize(12).fontWeight(FontWeight.Medium)
            .fontColor(this.muted).padding({ left: 12 })
          Column() {
            ForEach(group.rows, (entry: MenuRow, index: number) => {
              if (index > 0) {
                Divider().color(this.divider).margin({ left: 16, right: 16 })
              }
              this.menuRow(entry)
            }, (entry: MenuRow) => entry.id + ':' + entry.value + ':' + entry.checked + ':' + entry.slider + ':' + entry.available)
          }.width('100%').backgroundColor(this.card).borderRadius(16).clip(true)
        }.width('100%').alignItems(HorizontalAlign.Start)
      }, (group: MenuGroup) => group.title + ':' +
        group.rows.map(entry => entry.id + '=' + entry.value + '=' + entry.checked + '=' + entry.slider + '=' +
          entry.available).join(','))
    }.width('100%')
  }
}
