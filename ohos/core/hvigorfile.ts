import { harTasks } from '@ohos/hvigor-ohos-plugin';
import { setupPlugin } from '../../plugins/setup/buildkit/hvigor/setup'

export default {
  system: harTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: [setupPlugin()]       /* Custom plugin to extend the functionality of Hvigor. */
}