<script setup lang="ts">
import type { EditorToolbarItem } from '@nuxt/ui'

defineProps<{ placeholder?: string }>()
const model = defineModel<string>({ required: true })

const items: EditorToolbarItem[][] = [
  [
    { kind: 'mark', mark: 'bold', icon: 'i-lucide-bold', 'aria-label': 'Gras' },
    { kind: 'mark', mark: 'italic', icon: 'i-lucide-italic', 'aria-label': 'Italique' },
    { kind: 'mark', mark: 'underline', icon: 'i-lucide-underline', 'aria-label': 'Souligné' },
    { kind: 'mark', mark: 'strike', icon: 'i-lucide-strikethrough', 'aria-label': 'Barré' }
  ],
  [
    { kind: 'bulletList', icon: 'i-lucide-list', 'aria-label': 'Liste à puces' },
    { kind: 'orderedList', icon: 'i-lucide-list-ordered', 'aria-label': 'Liste numérotée' },
    { kind: 'blockquote', icon: 'i-lucide-text-quote', 'aria-label': 'Citation' }
  ],
  [
    { kind: 'undo', icon: 'i-lucide-undo', 'aria-label': 'Annuler' },
    { kind: 'redo', icon: 'i-lucide-redo', 'aria-label': 'Rétablir' }
  ]
]
</script>

<template>
  <div class="rounded-lg border border-default bg-default focus-within:border-primary transition-colors">
    <UEditor
      v-slot="{ editor }"
      v-model="model"
      content-type="html"
      :placeholder="placeholder"
      :image="false"
      :mention="false"
      class="min-h-32"
      :ui="{ base: 'px-3 sm:px-3 py-2 min-h-28 *:my-2' }"
    >
      <UEditorToolbar
        :editor="editor"
        :items="items"
        class="border-b border-default px-1 py-1 overflow-x-auto"
      />
    </UEditor>
  </div>
</template>
