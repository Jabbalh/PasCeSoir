<script setup lang="ts">
interface AppInvite {
  id: string
  token: string
  note: string
  created_at: string
  expires_at: string
  revoked_at: string | null
  used_at: string | null
  used_by_profile: { display_name: string } | null
}

const supabase = useSupabase()
const toast = useToast()
const { user } = useAuth()
const { online } = useSync()

const invites = ref<AppInvite[]>([])
const loading = ref(true)

async function load() {
  if (!online.value) {
    loading.value = false
    return
  }
  loading.value = true
  const { data, error } = await supabase
    .from('app_invites')
    .select('id, token, note, created_at, expires_at, revoked_at, used_at, used_by_profile:profiles!app_invites_used_by_fkey(display_name)')
    .order('created_at', { ascending: false })
  loading.value = false
  if (error) {
    toast.add({ title: 'Oups', description: errorMessage(error), color: 'error' })
    return
  }
  invites.value = data as unknown as AppInvite[]
}

onMounted(load)
watch(online, (o) => {
  if (o) load()
})

// --- Création ---
const durations = [
  { label: '24 heures', value: 1 },
  { label: '7 jours', value: 7 },
  { label: '30 jours', value: 30 }
]
const form = reactive({ note: '', days: 7 })
const creating = ref(false)

async function create() {
  creating.value = true
  try {
    const expires = new Date(Date.now() + form.days * 86_400_000).toISOString()
    const { data, error } = await supabase
      .from('app_invites')
      .insert({ token: randomToken(), note: form.note.trim(), created_by: user.value!.id, expires_at: expires })
      .select('token')
      .single()
    if (error) throw error
    form.note = ''
    await load()
    await share(data.token)
  } catch (e) {
    toast.add({ title: 'Oups', description: errorMessage(e), color: 'error' })
  } finally {
    creating.value = false
  }
}

// --- Actions ---
function linkOf(token: string) {
  return `${location.origin}/inscription/${token}`
}

async function share(token: string) {
  const result = await shareOrCopy(linkOf(token), 'Pas ce soir', 'Je t\'invite à utiliser Pas ce soir, le journal des réveils de nos enfants')
  if (result === 'copied') toast.add({ title: 'Lien copié', icon: 'i-lucide-clipboard-check', color: 'success' })
  if (result === 'failed') toast.add({ title: 'Copie impossible', description: linkOf(token), color: 'warning' })
}

async function revoke(invite: AppInvite) {
  const { error } = await supabase.from('app_invites').update({ revoked_at: new Date().toISOString() }).eq('id', invite.id)
  if (error) {
    toast.add({ title: 'Oups', description: errorMessage(error), color: 'error' })
    return
  }
  toast.add({ title: 'Invitation révoquée', icon: 'i-lucide-link-2-off' })
  await load()
}

function status(i: AppInvite) {
  if (i.used_at) return { label: `Utilisée par ${i.used_by_profile?.display_name ?? 'un compte supprimé'}`, color: 'success' as const, active: false }
  if (i.revoked_at) return { label: 'Révoquée', color: 'neutral' as const, active: false }
  if (new Date(i.expires_at) <= new Date()) return { label: 'Expirée', color: 'neutral' as const, active: false }
  return { label: `Active jusqu'au ${formatDateTime(i.expires_at)}`, color: 'primary' as const, active: true }
}
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-2xl font-bold">
        Administration
      </h1>
      <p class="text-sm text-muted">
        Invitez quelqu'un à utiliser l'application. Il pourra créer son compte puis son propre journal.
      </p>
    </div>

    <UAlert
      v-if="!online"
      icon="i-lucide-wifi-off"
      color="warning"
      variant="soft"
      title="Connexion internet requise"
    />

    <UCard>
      <template #header>
        <h2 class="font-semibold">
          Nouvelle invitation
        </h2>
        <p class="text-sm text-muted">
          Lien à usage unique : il ne sert qu'à créer un seul compte.
        </p>
      </template>
      <form class="space-y-4" @submit.prevent="create">
        <UFormField label="Pour qui ?" hint="Note pour vous seul">
          <UInput v-model="form.note" placeholder="ex. Julie (cousine)" class="w-full" />
        </UFormField>
        <UFormField label="Validité">
          <div class="flex gap-2">
            <UButton
              v-for="d in durations"
              :key="d.value"
              size="sm"
              :variant="form.days === d.value ? 'solid' : 'soft'"
              :color="form.days === d.value ? 'primary' : 'neutral'"
              @click="form.days = d.value"
            >
              {{ d.label }}
            </UButton>
          </div>
        </UFormField>
        <UButton type="submit" block icon="i-lucide-send" :loading="creating" :disabled="!online">
          Créer et partager le lien
        </UButton>
      </form>
    </UCard>

    <UCard>
      <template #header>
        <h2 class="font-semibold">
          Invitations
        </h2>
      </template>
      <div v-if="loading" class="space-y-2">
        <USkeleton v-for="i in 3" :key="i" class="h-12 w-full" />
      </div>
      <p v-else-if="!invites.length" class="text-sm text-muted">
        Aucune invitation pour le moment.
      </p>
      <ul v-else class="divide-y divide-default -my-2">
        <li v-for="i in invites" :key="i.id" class="py-3 flex items-center gap-2">
          <div class="flex-1 min-w-0">
            <p class="font-medium truncate">
              {{ i.note || 'Sans note' }}
            </p>
            <p class="text-xs text-muted">
              Créée le {{ formatDateTime(i.created_at) }}
            </p>
            <UBadge :color="status(i).color" variant="subtle" size="sm" class="mt-1">
              {{ status(i).label }}
            </UBadge>
          </div>
          <template v-if="status(i).active">
            <UButton icon="i-lucide-share-2" size="sm" color="neutral" variant="ghost" aria-label="Partager" @click="share(i.token)" />
            <UButton icon="i-lucide-link-2-off" size="sm" color="error" variant="ghost" aria-label="Révoquer" @click="revoke(i)" />
          </template>
        </li>
      </ul>
    </UCard>
  </div>
</template>
