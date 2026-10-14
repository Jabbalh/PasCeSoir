<script setup lang="ts">
const route = useRoute()
const journalId = computed(() => route.params.id as string)
const { journal } = useJournal(journalId)
const { data: wakeups, loading } = useWakeups(journalId)

const today = toDateKey(new Date())
const from = ref(toDateKey(addDays(new Date(), -29)))
const to = ref(today)

const presets = [
  { label: '7 j', days: 7 },
  { label: '30 j', days: 30 },
  { label: '3 mois', days: 91 },
  { label: '1 an', days: 365 }
]
function applyPreset(days: number) {
  to.value = toDateKey(new Date())
  from.value = toDateKey(addDays(new Date(), -(days - 1)))
}
function applyAll() {
  const keys = wakeups.value.map(w => nightKey(w.woke_at)).sort()
  from.value = keys[0] ?? today
  to.value = toDateKey(new Date())
}
const activePreset = computed(() => {
  if (to.value !== toDateKey(new Date())) return null
  return presets.find(p => from.value === toDateKey(addDays(new Date(), -(p.days - 1))))?.days ?? null
})

const range = computed(() => (from.value <= to.value ? [from.value, to.value] : [to.value, from.value]) as [string, string])

/** Réveils de la période, rattachés à leur nuit (une nuit = soir J -> matin J+1) */
const inRange = computed(() => {
  const [a, b] = range.value
  return wakeups.value
    .map(w => ({ w, night: nightKey(w.woke_at) }))
    .filter(x => x.night >= a && x.night <= b)
})

const nightsCount = computed(() => {
  const [a, b] = range.value
  return Math.round((fromDateKey(b).getTime() - fromDateKey(a).getTime()) / 86_400_000) + 1
})
const nightsWithWakeup = computed(() => new Set(inRange.value.map(x => x.night)).size)
const avgPerNight = computed(() => (nightsCount.value ? inRange.value.length / nightsCount.value : 0))

const fmtDay = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'short' })
const fmtMonth = new Intl.DateTimeFormat('fr-FR', { month: 'short', year: '2-digit' })
const fmtMonthLong = new Intl.DateTimeFormat('fr-FR', { month: 'long', year: 'numeric' })

const granularity = ref<'week' | 'month'>('week')

/** Séries par semaine / mois, avec les périodes vides (0) */
const series = computed(() => {
  const [a, b] = range.value
  const counts = new Map<string, number>()
  const keyOf = granularity.value === 'week' ? weekKey : monthKey
  for (const x of inRange.value) {
    const k = keyOf(x.night)
    counts.set(k, (counts.get(k) ?? 0) + 1)
  }
  const items: { key: string, label: string, value: number, tooltip: string }[] = []
  if (granularity.value === 'week') {
    for (let d = fromDateKey(weekKey(a)); toDateKey(d) <= b; d = addDays(d, 7)) {
      const k = toDateKey(d)
      const v = counts.get(k) ?? 0
      items.push({
        key: k,
        label: fmtDay.format(d),
        value: v,
        tooltip: `Semaine du ${fmtDay.format(d)} au ${fmtDay.format(addDays(d, 6))} : ${v} réveil${v > 1 ? 's' : ''}`
      })
    }
  } else {
    const start = fromDateKey(a)
    for (let d = new Date(start.getFullYear(), start.getMonth(), 1); monthKey(toDateKey(d)) <= monthKey(b); d = new Date(d.getFullYear(), d.getMonth() + 1, 1)) {
      const k = monthKey(toDateKey(d))
      const v = counts.get(k) ?? 0
      items.push({ key: k, label: fmtMonth.format(d), value: v, tooltip: `${fmtMonthLong.format(d)} : ${v} réveil${v > 1 ? 's' : ''}` })
    }
  }
  return items
})

const showTable = ref(false)

/** Top 10 des raisons (un réveil peut avoir plusieurs raisons) */
const topReasons = computed(() => {
  const counts = new Map<string, number>()
  let withoutReason = 0
  for (const { w } of inRange.value) {
    if (!w.reasons.length) withoutReason++
    for (const r of w.reasons) counts.set(r, (counts.get(r) ?? 0) + 1)
  }
  const total = inRange.value.length || 1
  const top = [...counts.entries()]
    .sort((x, y) => y[1] - x[1] || x[0].localeCompare(y[0]))
    .slice(0, 10)
    .map(([label, value]) => ({ label, value, pct: Math.round((value / total) * 100) }))
  return { top, withoutReason, max: Math.max(1, ...top.map(t => t.value)) }
})

/** Répartition par heure de la nuit (18h -> 12h) */
const byHour = computed(() => {
  const hours = [18, 19, 20, 21, 22, 23, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
  const counts = new Map<number, number>()
  for (const { w } of inRange.value) {
    const h = new Date(w.woke_at).getHours()
    counts.set(h, (counts.get(h) ?? 0) + 1)
  }
  return hours.map((h) => {
    const v = counts.get(h) ?? 0
    return { key: String(h), label: `${h}h`, value: v, tooltip: `Entre ${h}h et ${(h + 1) % 24}h : ${v} réveil${v > 1 ? 's' : ''}` }
  })
})
</script>

<template>
  <div class="space-y-5">
    <div>
      <p class="text-sm text-muted">
        {{ journal?.name }}
      </p>
      <h1 class="text-2xl font-bold">
        Statistiques
      </h1>
    </div>

    <!-- Période -->
    <UCard :ui="{ body: 'p-3 sm:p-4 space-y-3' }">
      <div class="flex flex-wrap gap-1.5">
        <UButton
          v-for="p in presets"
          :key="p.days"
          size="sm"
          :variant="activePreset === p.days ? 'solid' : 'soft'"
          :color="activePreset === p.days ? 'primary' : 'neutral'"
          @click="applyPreset(p.days)"
        >
          {{ p.label }}
        </UButton>
        <UButton size="sm" variant="soft" color="neutral" @click="applyAll">
          Tout
        </UButton>
      </div>
      <div class="grid grid-cols-2 gap-2">
        <UFormField label="Du (nuit du)">
          <UInput v-model="from" type="date" class="w-full" :max="to" />
        </UFormField>
        <UFormField label="Au (nuit du)">
          <UInput v-model="to" type="date" class="w-full" :min="from" />
        </UFormField>
      </div>
    </UCard>

    <div v-if="loading" class="space-y-3">
      <USkeleton class="h-24 w-full" />
      <USkeleton class="h-56 w-full" />
    </div>

    <template v-else>
      <!-- Chiffres clés -->
      <div class="grid grid-cols-3 gap-2">
        <div class="rounded-xl border border-default p-3 text-center">
          <p class="text-3xl font-extrabold tabular-nums">
            {{ inRange.length }}
          </p>
          <p class="text-xs text-muted">
            réveils
          </p>
        </div>
        <div class="rounded-xl border border-default p-3 text-center">
          <p class="text-3xl font-extrabold tabular-nums">
            {{ avgPerNight.toLocaleString('fr-FR', { maximumFractionDigits: 1 }) }}
          </p>
          <p class="text-xs text-muted">
            par nuit
          </p>
        </div>
        <div class="rounded-xl border border-default p-3 text-center">
          <p class="text-3xl font-extrabold tabular-nums">
            {{ nightsCount - nightsWithWakeup }}
          </p>
          <p class="text-xs text-muted">
            nuit(s) sans réveil<br>sur {{ nightsCount }}
          </p>
        </div>
      </div>

      <!-- Évolution -->
      <UCard :ui="{ body: 'p-3 sm:p-4 space-y-3' }">
        <div class="flex items-center justify-between gap-2">
          <h2 class="font-semibold">
            Réveils par {{ granularity === 'week' ? 'semaine' : 'mois' }}
          </h2>
          <UTabs
            v-model="granularity"
            size="xs"
            :content="false"
            :items="[{ label: 'Semaine', value: 'week' }, { label: 'Mois', value: 'month' }]"
          />
        </div>
        <ColumnChart :items="series" />
        <UButton size="xs" variant="link" color="neutral" :icon="showTable ? 'i-lucide-chart-column' : 'i-lucide-table'" @click="showTable = !showTable">
          {{ showTable ? 'Masquer le tableau' : 'Voir en tableau' }}
        </UButton>
        <table v-if="showTable" class="w-full text-sm">
          <thead>
            <tr class="text-left text-muted border-b border-default">
              <th class="py-1 font-medium">
                {{ granularity === 'week' ? 'Semaine du' : 'Mois' }}
              </th>
              <th class="py-1 font-medium text-right">
                Réveils
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="s in [...series].reverse()" :key="s.key" class="border-b border-default/50">
              <td class="py-1">
                {{ s.label }}
              </td>
              <td class="py-1 text-right tabular-nums">
                {{ s.value }}
              </td>
            </tr>
          </tbody>
        </table>
      </UCard>

      <!-- Top raisons -->
      <UCard :ui="{ body: 'p-3 sm:p-4 space-y-3' }">
        <h2 class="font-semibold">
          Top 10 des raisons
        </h2>
        <p v-if="!topReasons.top.length" class="text-sm text-muted">
          Aucune raison renseignée sur cette période.
        </p>
        <ol v-else class="space-y-2.5">
          <li v-for="(r, i) in topReasons.top" :key="r.label">
            <div class="flex items-baseline justify-between text-sm mb-1 gap-2">
              <span class="truncate"><span class="text-muted tabular-nums mr-1.5">{{ i + 1 }}.</span>{{ r.label }}</span>
              <span class="tabular-nums text-muted shrink-0"><strong class="text-default">{{ r.value }}</strong> · {{ r.pct }} %</span>
            </div>
            <div class="h-2 rounded-full bg-elevated overflow-hidden">
              <div class="h-full rounded-full bg-primary" :style="{ width: `${(r.value / topReasons.max) * 100}%` }" />
            </div>
          </li>
        </ol>
        <p v-if="topReasons.withoutReason" class="text-xs text-muted">
          {{ topReasons.withoutReason }} réveil(s) sans raison renseignée. Pourcentages calculés sur le nombre de réveils.
        </p>
      </UCard>

      <!-- Heures -->
      <UCard :ui="{ body: 'p-3 sm:p-4 space-y-3' }">
        <h2 class="font-semibold">
          À quelle heure ?
        </h2>
        <ColumnChart :items="byHour" />
      </UCard>
    </template>
  </div>
</template>
