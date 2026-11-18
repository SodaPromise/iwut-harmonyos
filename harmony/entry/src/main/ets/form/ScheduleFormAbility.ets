import { Want } from '@kit.AbilityKit';
import { FormExtensionAbility, formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { cardData, registerCard } from '../services/ScheduleCards';

export default class ScheduleFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const id = want.parameters?.[formInfo.FormParam.IDENTITY_KEY];
    if (typeof id === 'string') {
      try { registerCard(this.context, id, true); } catch (_) {}
    }
    return cardData(this.context);
  }

  onUpdateForm(formId: string): void {
    formProvider.updateForm(formId, cardData(this.context)).catch(() => {});
  }

  onRemoveForm(formId: string): void {
    try { registerCard(this.context, formId, false); } catch (_) {}
  }

  onAcquireFormState(_want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }
}
