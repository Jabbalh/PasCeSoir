<script setup lang="ts">
import type { Approach } from '~/utils/db'

const props = defineProps<{
  approach: Approach
  today: string
}>()

const kind = computed(() => approachKind(props.approach.kind))
const status = computed(() => approachStatus(props.approach, props.today))
const commentText = computed(() => props.approach.comment.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim())
</script>

<template>
  <NuxtLink
    :to="`/journal/${approach.journal_id}/demarches/${approach.id}`"
    class="block p-3.5 rounded-xl border border-default bg-elevated/40 hover:bg-elevated active:scale-[0.99] transition"
    :class="{ 'opacity-70': status === 'terminee' }"
  >
    <div class="flex items-center gap-3">
      <div class="size-10 shrink-0 rounded-full flex items-center justify-center" :class="kind.soft">
        <UIcon :name="kind.icon" class="size-5" />
      </div>
      <div class="min-w-0 flex-1">
        <p class="font-semibold truncate">
          {{ approach.label }}
        </p>
        <p class="text-xs text-muted">
          {{ kind.label }} · {{ approachDates(approach, today) }}
          <UIcon v-if="approach._dirty" name="i-lucide-cloud-upload" class="size-3 text-warning ml-1 align-[-2px]" />
        </p>
      </div>
      <UIcon name="i-lucide-chevron-right" class="size-5 text-muted" />
    </div>
    <div v-if="approach.periods.length" class="flex flex-wrap gap-1.5 mt-2">
      <UBadge v-for="p in DAY_PERIODS.filter(_ => approach.periods.includes(p.value))" :key="p.value" color="neutral" variant="subtle" size="sm" icon="i-lucide-clock">
        {{ p.label }}
      </UBadge>
    </div>
    <p v-if="commentText" class="text-sm text-muted mt-2 line-clamp-2">
      {{ commentText }}
    </p>
  </NuxtLink>
</template>
