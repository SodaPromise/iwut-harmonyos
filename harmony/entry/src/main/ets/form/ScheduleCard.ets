class CourseCardAction {
  action: string = 'router';
  abilityName: string = 'EntryAbility';
}

@Entry(new LocalStorage())
@Component
struct ScheduleCard {
  @LocalStorageProp('caption') caption: string = '今日课程';
  @LocalStorageProp('courseOne') courseOne: string = '今日没有课程';
  @LocalStorageProp('detailOne') detailOne: string = '';
  @LocalStorageProp('courseTwo') courseTwo: string = '';
  @LocalStorageProp('detailTwo') detailTwo: string = '';

  build() {
    Column({ space: 6 }) {
      Text(this.caption).fontSize(12).fontColor('#2959AD').maxLines(1).width('100%')
      Text(this.courseOne).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#172136')
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      if (this.detailOne) Text(this.detailOne).fontSize(11).fontColor('#52627A').maxLines(1).width('100%')
      if (this.courseTwo) {
        Text(this.courseTwo).fontSize(13).fontColor('#172136')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Text(this.detailTwo).fontSize(11).fontColor('#52627A').maxLines(1).width('100%')
      }
    }.width('100%').height('100%').padding(13).justifyContent(FlexAlign.Center).backgroundColor('#EFF5FF')
      .onClick(() => { postCardAction(this, new CourseCardAction()); })
  }
}
