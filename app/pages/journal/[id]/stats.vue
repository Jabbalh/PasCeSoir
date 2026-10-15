<script setup lang="ts">
const route = useRoute()
const journalId = computed(() => route.params.id as string)
const { journal } = useJournal(journalId)
const { data: wakeups, loading } = useWakeups(journalId)
const { labelOf } = useOptions(journalId)
const { data: approaches } = useApproaches(journalId)

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

/** Types de réveil et leur couleur (graphique empilé et répartition) */
const typeSegments = [
  ...WAKE_TYPES.map((t, i) => ({ ...t, bar: i === 0 ? 'bg-warning' : 'bg-primary' })),
  { value: null, label: 'Non renseigné', icon: 'i-lucide-circle-help', bar: 'bg-accented' }
]

/** Séries par semaine / mois, empilées par type, avec les périodes vides (0) */
const series = computed(() => {
  const [a, b] = range.value
  const counts = new Map<string, number[]>()
  const keyOf = granularity.value === 'week' ? weekKey : monthKey
  for (const x of inRange.value) {
    const k = keyOf(x.night)
    const c = counts.get(k) ?? typeSegments.map(() => 0)
    c[typeSegments.findIndex(s => s.value === (x.w.wake_type ?? null))]!++
    counts.set(k, c)
  }
  const item = (key: string, label: string, title: string) => {
    const c = counts.get(key) ?? typeSegments.map(() => 0)
    const value = c.reduce((s, n) => s + n, 0)
    const detail = typeSegments.flatMap((s, i) => (c[i] ? [`${s.label} ${c[i]}`] : [])).join(', ')
    return {
      key,
      label,
      value,
      counts: c,
      segments: typeSegments.map((s, i) => ({ value: c[i]!, class: s.bar })),
      tooltip: `${title} : ${value} réveil${value > 1 ? 's' : ''}${detail ? ` (${detail})` : ''}`
    }
  }
  const items: ReturnType<typeof item>[] = []
  if (granularity.value === 'week') {
    for (let d = fromDateKey(weekKey(a)); toDateKey(d) <= b; d = addDays(d, 7)) {
      items.push(item(toDateKey(d), fmtDay.format(d), `Semaine du ${fmtDay.format(d)} au ${fmtDay.format(addDays(d, 6))}`))
    }
  } else {
    const start = fromDateKey(a)
    for (let d = new Date(start.getFullYear(), start.getMonth(), 1); monthKey(toDateKey(d)) <= monthKey(b); d = new Date(d.getFullYear(), d.getMonth() + 1, 1)) {
      items.push(item(monthKey(toDateKey(d)), fmtMonth.format(d), fmtMonthLong.format(d)))
    }
  }
  return items
})

const showTable = ref(false)

/** Démarches en place sur la période, de la plus ancienne à la plus récente */
const approachesInRange = computed(() => {
  const [a, b] = range.value
  return approaches.value
    .filter(x => x.start_date <= b && (!x.end_date || x.end_date >= a))
    .sort((x, y) => x.start_date.localeCompare(y.start_date))
})

/** Frise des démarches sous l'histogramme, alignée sur les semaines / mois */
const approachBands = computed(() => {
  const [a, b] = range.value
  const keyOf = granularity.value === 'week' ? weekKey : monthKey
  const index = new Map(series.value.map((s, i) => [s.key, i]))
  return approachesInRange.value.flatMap((x) => {
    const from = index.get(keyOf(x.start_date > a ? x.start_date : a))
    const to = index.get(keyOf(x.end_date && x.end_date < b ? x.end_date : b))
    if (from === undefined || to === undefined) return []
    const k = approachKind(x.kind)
    return [{ key: x.id, label: x.label, from, to, class: k.bar, icon: k.icon, tooltip: `${k.label} · ${x.label} : ${approachDates(x, today).toLowerCase()}` }]
  })
})

/**
 * Effet de chaque démarche : réveils nocturnes (hors levers) par nuit pendant la démarche,
 * comparés aux 30 nuits qui précèdent son début. La nuit en cours, incomplète, est exclue.
 */
const BEFORE_NIGHTS = 30
const approachEffects = computed(() => {
  const lastNight = toDateKey(addDays(fromDateKey(nightKey(new Date())), -1))
  const perNight = new Map<string, number>()
  for (const w of wakeups.value) {
    if (w.wake_type === 'lever') continue
    const k = nightKey(w.woke_at)
    perNight.set(k, (perNight.get(k) ?? 0) + 1)
  }
  // pas de données avant la création du journal ni avant le premier réveil saisi
  const firstWakeup = wakeups.value.at(-1)
  const dataStart = [journal.value && nightKey(journal.value.created_at), firstWakeup && nightKey(firstWakeup.woke_at)]
    .filter((k): k is string => !!k)
    .sort()[0] ?? today
  const stat = (from: string, to: string) => {
    if (to < from) return null
    let total = 0
    for (let d = fromDateKey(from); toDateKey(d) <= to; d = addDays(d, 1)) total += perNight.get(toDateKey(d)) ?? 0
    const nights = daysBetween(from, to)
    return { nights, avg: total / nights }
  }
  return approachesInRange.value.map((x) => {
    const beforeTo = toDateKey(addDays(fromDateKey(x.start_date), -1))
    const beforeFrom = toDateKey(addDays(fromDateKey(x.start_date), -BEFORE_NIGHTS))
    const before = stat(beforeFrom > dataStart ? beforeFrom : dataStart, beforeTo)
    const during = stat(x.start_date, x.end_date && x.end_date < lastNight ? x.end_date : lastNight)
    const delta = before && during && before.avg ? Math.round(((during.avg - before.avg) / before.avg) * 100) : null
    return { approach: x, kind: approachKind(x.kind), before, during, delta }
  })
})
const fmtAvg = (n: number) => n.toLocaleString('fr-FR', { maximumFractionDigits: 1 })

/** Top 10 des raisons (un réveil peut avoir plusieurs raisons) */
const topReasons = computed(() => {
  const counts = new Map<string, number>()
  let withoutReason = 0
  for (const { w } of inRange.value) {
    if (!w.reason_ids.length) withoutReason++
    for (const r of w.reason_ids) counts.set(r, (counts.get(r) ?? 0) + 1)
  }
  const total = inRange.value.length || 1
  const top = [...counts.entries()]
    .map(([id, value]) => ({ id, label: labelOf(id), value, pct: Math.round((value / total) * 100) }))
    .sort((x, y) => y.value - x.value || x.label.localeCompare(y.label))
    .slice(0, 10)
  return { top, withoutReason, max: Math.max(1, ...top.map(t => t.value)) }
})

/** Répartition lever / réveil nocturne (pourcentages sur l'ensemble des réveils de la période) */
const byType = computed(() => {
  const total = inRange.value.length
  const segments = typeSegments.map((s) => {
    const count = inRange.value.filter(({ w }) => (w.wake_type ?? null) === s.value).length
    return { ...s, count, pct: total ? Math.round((count / total) * 100) : 0 }
  })
  return { total, segments }
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

/**
 * Export PDF par l'impression du navigateur (« Enregistrer au format PDF ») : rendu vectoriel,
 * sans dépendance, hors connexion. Le thème clair est appliqué par app.vue (beforeprint) ;
 * le titre du document sert de nom de fichier proposé.
 */
function exportPdf() {
  const title = document.title
  document.title = `${journal.value?.child_name || journal.value?.name || 'statistiques'} - ${range.value[0]} au ${range.value[1]}`
  const restore = () => (document.title = title)
  window.addEventListener('afterprint', restore, { once: true })
  try {
    window.print()
  } catch {
    window.removeEventListener('afterprint', restore)
    restore()
  }
}
</script>

<template>
  <div class="space-y-5 print:space-y-4">
    <div class="flex items-end gap-2">
      <div class="flex-1 min-w-0">
        <p class="text-sm text-muted">
          {{ journal?.name }}<span v-if="journal?.child_name" class="hidden print:inline"> · {{ journal.child_name }}</span>
        </p>
        <h1 class="text-2xl font-bold">
          Statistiques
        </h1>
        <!-- en-tête du rapport imprimé -->
        <p class="hidden print:block text-sm">
          Nuits du {{ formatDay(range[0]) }} au {{ formatDay(range[1]) }} · généré le {{ formatDay(today) }}
        </p>
      </div>
      <UButton
        icon="i-lucide-file-down"
        color="neutral"
        variant="soft"
        class="print:hidden"
        :disabled="loading"
        @click="exportPdf"
      >
        PDF
      </UButton>
    </div>

    <!-- Période -->
    <UCard class="print:hidden" :ui="{ body: 'p-3 sm:p-4 space-y-3' }">
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
      <div class="grid grid-cols-3 gap-2 break-inside-avoid">
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

      <!-- Lever / nocturne -->
      <UCard class="break-inside-avoid" :ui="{ body: 'p-3 sm:p-4 space-y-3' }">
        <h2 class="font-semibold">
          Lever ou réveil nocturne
        </h2>
        <p v-if="!byType.total" class="text-sm text-muted">
          Aucun réveil sur cette période.
        </p>
        <template v-else>
          <div class="flex h-3 rounded-full bg-elevated overflow-hidden" role="img" :aria-label="byType.segments.map(s => `${s.label} : ${s.count}`).join(', ')">
            <div
              v-for="s in byType.segments.filter(seg => seg.count)"
              :key="s.label"
              class="h-full"
              :class="s.bar"
              :style="{ width: `${(s.count / byType.total) * 100}%` }"
            />
          </div>
          <ul class="space-y-1.5 text-sm">
            <li v-for="s in byType.segments" :key="s.label" class="flex items-center gap-2">
              <span class="size-2.5 rounded-full shrink-0" :class="s.bar" />
              <UIcon :name="s.icon" class="size-4 text-muted" />
              <span class="flex-1">{{ s.label }}</span>
              <span class="tabular-nums text-muted"><strong class="text-default">{{ s.count }}</strong> · {{ s.pct }} %</span>
            </li>
          </ul>
        </template>
      </UCard>

      <!-- Évolution -->
      <UCard class="break-inside-avoid" :ui="{ body: 'p-3 sm:p-4 space-y-3' }">
        <div class="flex items-center justify-between gap-2">
          <h2 class="font-semibold">
            Réveils par {{ granularity === 'week' ? 'semaine' : 'mois' }}
          </h2>
          <UTabs
            class="print:hidden"
            v-model="granularity"
            size="xs"
            :content="false"
            :items="[{ label: 'Semaine', value: 'week' }, { label: 'Mois', value: 'month' }]"
          />
        </div>
        <ColumnChart :items="series" :bands="approachBands" />
        <ul class="flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted">
          <li v-for="s in typeSegments" :key="s.label" class="flex items-center gap-1.5">
            <span class="size-2.5 rounded-full" :class="s.bar" />{{ s.label }}
          </li>
        </ul>
        <UButton size="xs" variant="link" color="neutral" class="print:hidden" :icon="showTable ? 'i-lucide-chart-column' : 'i-lucide-table'" @click="showTable = !showTable">
          {{ showTable ? 'Masquer le tableau' : 'Voir en tableau' }}
        </UButton>
        <table v-if="showTable" class="w-full text-sm">
          <thead>
            <tr class="text-left text-muted border-b border-default">
              <th class="py-1 font-medium">
                {{ granularity === 'week' ? 'Semaine du' : 'Mois' }}
              </th>
              <th v-for="t in typeSegments" :key="t.label" class="py-1 font-medium text-right">
                {{ t.label }}
              </th>
              <th class="py-1 font-medium text-right">
                Total
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="s in [...series].reverse()" :key="s.key" class="border-b border-default/50">
              <td class="py-1">
                {{ s.label }}
              </td>
              <td v-for="(n, i) in s.counts" :key="i" class="py-1 text-right tabular-nums text-muted">
                {{ n }}
              </td>
              <td class="py-1 text-right tabular-nums font-medium">
                {{ s.value }}
              </td>
            </tr>
          </tbody>
        </table>
      </UCard>

      <!-- Démarches : avant / pendant -->
      <UCard class="break-inside-avoid" :ui="{ body: 'p-3 sm:p-4 space-y-3' }">
        <div class="flex items-center justify-between gap-2">
          <h2 class="font-semibold">
            Effet des démarches
          </h2>
          <ULink :to="`/journal/${journalId}/demarches`" class="text-xs text-muted print:hidden">Gérer</ULink>
        </div>
        <p v-if="!approachEffects.length" class="text-sm text-muted">
          Aucune démarche sur cette période.
        </p>
        <ul v-else class="divide-y divide-default">
          <li v-for="e in approachEffects" :key="e.approach.id" class="py-2.5 first:pt-0 last:pb-0 space-y-1.5 break-inside-avoid">
            <div class="flex items-center gap-2 min-w-0">
              <span class="size-6 shrink-0 rounded-full flex items-center justify-center" :class="e.kind.soft">
                <UIcon :name="e.kind.icon" class="size-3.5" />
              </span>
              <span class="font-medium truncate flex-1">{{ e.approach.label }}</span>
              <UBadge
                v-if="e.delta !== null"
                :color="e.delta < 0 ? 'success' : e.delta > 0 ? 'error' : 'neutral'"
                variant="subtle"
                size="sm"
                :icon="e.delta < 0 ? 'i-lucide-trending-down' : e.delta > 0 ? 'i-lucide-trending-up' : 'i-lucide-minus'"
              >
                {{ e.delta > 0 ? '+' : '' }}{{ e.delta }} %
              </UBadge>
            </div>
            <p class="text-xs text-muted">
              {{ approachDates(e.approach, today) }}
            </p>
            <div class="grid grid-cols-2 gap-2 text-sm">
              <div class="rounded-lg bg-elevated/60 px-2.5 py-1.5">
                <p class="text-xs text-muted">
                  Avant
                </p>
                <p v-if="e.before" class="tabular-nums">
                  <strong>{{ fmtAvg(e.before.avg) }}</strong> <span class="text-muted">/ nuit · {{ e.before.nights }} n.</span>
                </p>
                <p v-else class="text-muted text-xs">
                  Pas de données
                </p>
              </div>
              <div class="rounded-lg bg-elevated/60 px-2.5 py-1.5">
                <p class="text-xs text-muted">
                  Pendant
                </p>
                <p v-if="e.during" class="tabular-nums">
                  <strong>{{ fmtAvg(e.during.avg) }}</strong> <span class="text-muted">/ nuit · {{ e.during.nights }} n.</span>
                </p>
                <p v-else class="text-muted text-xs">
                  Pas encore de nuit complète
                </p>
              </div>
            </div>
          </li>
        </ul>
        <p v-if="approachEffects.length" class="text-xs text-muted">
          Réveils nocturnes par nuit (levers exclus) : pendant la démarche, comparés aux {{ BEFORE_NIGHTS }} nuits précédant son début. Calcul sur tout l'historique, indépendamment de la période choisie ; plusieurs démarches simultanées peuvent se combiner.
        </p>
      </UCard>

      <!-- Top raisons -->
      <UCard class="break-inside-avoid" :ui="{ body: 'p-3 sm:p-4 space-y-3' }">
        <h2 class="font-semibold">
          Top 10 des raisons
        </h2>
        <p v-if="!topReasons.top.length" class="text-sm text-muted">
          Aucune raison renseignée sur cette période.
        </p>
        <ol v-else class="space-y-2.5">
          <li v-for="(r, i) in topReasons.top" :key="r.id">
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
      <UCard class="break-inside-avoid" :ui="{ body: 'p-3 sm:p-4 space-y-3' }">
        <h2 class="font-semibold">
          À quelle heure ?
        </h2>
        <ColumnChart :items="byHour" />
      </UCard>
    </template>
  </div>
</template>
