@Entry
@Component
struct WidgetCard {
  @State title: string = ''
  
  build() {
    Column() {
      Row() {      
        Text(this.title)
        .fontSize('20fp')
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font'))
      }
      .height('100%')
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .onAppear(() => {
      this.title = 'FlClash'
      postCardAction(this, {  
        action: 'call',
        bundleName: 'com.follow.clash',
        abilityName: 'TempAbility',
        params: {
          method: 'call'
        }
      })
    })
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        bundleName: 'com.follow.clash',
        abilityName: 'EntryAbility'
      })
    })
  }
}