import { formProvider } from '@kit.FormKit'
import { Want } from '@kit.AbilityKit'

export function openFormManager(bundleName: string) {
  const want: Want = {
    bundleName: bundleName,
    abilityName: 'FormExtAbility',
    parameters: {
      'ohos.extra.param.key.form_dimension': 1,
      'ohos.extra.param.key.form_name': '',
      'ohos.extra.param.key.module_name': 'entry'
    },
  }
  try {
    formProvider.openFormManager(want)
  } catch (err) {
    console.log(`Call openFormManager failed <= ${err.message ?? err}`)
  }
}