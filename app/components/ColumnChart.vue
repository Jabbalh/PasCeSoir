<script setup lang="ts">
/**
 * Histogramme vertical : barres fines, extrémités arrondies, infobulle au survol/tap.
 * Avec `segments`, la barre est empilée (de bas en haut, une classe de couleur par segment).
 */
const props = defineProps<{
  items: { key: string, label: string, value: number, tooltip: string, segments?: { value: number, class: string }[] }[]
}>()

const max = computed(() => Math.max(1, ...props.items.map(i => i.value)))
const ticks = computed(() => {
  const m = max.value
  const step = Math.max(1, Math.ceil(m / 4))
  const top = Math.ceil(m / step) * step
  return { top, values: Array.from({ length: Math.floor(top / step) + 1 }, (_, i) => i * step).reverse() }
})
// Étiquettes sélectives : on n'affiche pas toutes les étiquettes de l'axe si trop nombreuses
const labelEvery = computed(() => Math.ceil(props.items.length / 8))
const scroller = ref<HTMLElement | null>(null)

watch(() => props.items, async () => {
  await nextTick()
  if (scroller.value) scroller.value.scrollLeft = scroller.value.scrollWidth
}, { immediate: true })
</script>

<template>
  <div class="flex gap-2">
    <!-- axe Y -->
    <div class="relative h-44 w-6 shrink-0 text-[10px] text-dimmed tabular-nums">
      <span
        v-for="t in ticks.values"
        :key="t"
        class="absolute right-0 -translate-y-1/2"
        :style="{ top: `${(1 - t / ticks.top) * 100}%` }"
      >{{ t }}</span>
    </div>

    <div ref="scroller" class="flex-1 overflow-x-auto pb-1">
      <div class="relative h-44" :style="{ minWidth: `${items.length * 22}px` }">
        <!-- grille discrète -->
        <div
          v-for="t in ticks.values"
          :key="t"
          class="absolute inset-x-0 border-t border-default/60"
          :style="{ top: `${(1 - t / ticks.top) * 100}%` }"
        />
        <div class="absolute inset-0 flex items-end gap-0.5">
          <UTooltip v-for="item in items" :key="item.key" :text="item.tooltip" :content="{ side: 'top' }">
            <button
              type="button"
              class="group flex-1 h-full flex items-end justify-center min-w-5 focus:outline-none"
              :aria-label="item.tooltip"
            >
              <span
                v-if="item.segments"
                class="w-3/5 max-w-6 flex flex-col-reverse gap-px rounded-t-[4px] overflow-hidden transition-opacity group-hover:opacity-80 group-focus-visible:ring-2 ring-primary/50"
                :style="{ height: item.value ? `${(item.value / ticks.top) * 100}%` : '0' }"
              >
                <span
                  v-for="(s, i) in item.segments.filter(s => s.value)"
                  :key="i"
                  class="w-full shrink-0"
                  :class="s.class"
                  :style="{ flexGrow: s.value, flexBasis: 0 }"
                />
              </span>
              <span
                v-else
                class="w-3/5 max-w-6 rounded-t-[4px] bg-primary transition-opacity group-hover:opacity-80 group-focus-visible:ring-2 ring-primary/50"
                :style="{ height: item.value ? `${(item.value / ticks.top) * 100}%` : '0' }"
              />
            </button>
          </UTooltip>
        </div>
      </div>
      <div class="flex gap-0.5 mt-1" :style="{ minWidth: `${items.length * 22}px` }">
        <span
          v-for="(item, i) in items"
          :key="item.key"
          class="flex-1 min-w-5 text-center text-[10px] text-muted whitespace-nowrap overflow-visible"
        >{{ i % labelEvery === 0 ? item.label : '' }}</span>
      </div>
    </div>
  </div>
</template>
