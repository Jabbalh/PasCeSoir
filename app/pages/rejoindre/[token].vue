<script setup lang="ts">
const route = useRoute()
const supabase = useSupabase()
const toast = useToast()
const { online, sync } = useSync()

const token = computed(() => route.params.token as string)
const preview = ref<{ journal_name: string, child_name: string } | null>(null)
const state = ref<'loading' | 'ready' | 'invalid' | 'joining'>('loading')

async function load() {
  if (!online.value) return
  state.value = 'loading'
  const { data, error } = await supabase.rpc('invitation_preview', { p_token: token.value })
  if (error || !data?.length) {
    state.value = 'invalid'
    return
  }
  preview.value = data[0]
  state.value = 'ready'
}

onMounted(load)
watch(online, (o) => {
  if (o) load()
})

async function join() {
  state.value = 'joining'
  try {
    const { data: journalId, error } = await supabase.rpc('join_journal', { p_token: token.value })
    if (error) throw error
    await sync()
    toast.add({ title: 'Bienvenue dans le journal !', icon: 'i-lucide-party-popper', color: 'success' })
    await navigateTo(`/journal/${journalId}`, { replace: true })
  } catch (e) {
    toast.add({ title: 'Oups', description: errorMessage(e), color: 'error' })
    state.value = 'ready'
  }
}
</script>

<template>
  <div class="py-8">
    <UEmpty
      v-if="!online"
      icon="i-lucide-wifi-off"
      title="Connexion requise"
      description="Connectez-vous à internet pour rejoindre ce journal."
    />
    <div v-else-if="state === 'loading'" class="flex justify-center py-10">
      <UIcon name="i-lucide-loader-circle" class="size-8 animate-spin text-muted" />
    </div>
    <UEmpty
      v-else-if="state === 'invalid'"
      icon="i-lucide-link-2-off"
      title="Lien invalide"
      description="Ce lien d'invitation n'existe pas ou a été désactivé. Demandez-en un nouveau."
      :actions="[{ label: 'Mes journaux', to: '/' }]"
    />
    <UCard v-else class="text-center">
      <UIcon name="i-lucide-mail-open" class="size-12 text-primary mx-auto mb-3" />
      <p class="text-muted">
        Vous êtes invité à rejoindre
      </p>
      <h1 class="text-2xl font-bold my-1">
        {{ preview?.journal_name }}
      </h1>
      <p v-if="preview?.child_name" class="text-sm text-muted mb-6">
        le journal des nuits de {{ preview.child_name }}
      </p>
      <UButton block size="xl" icon="i-lucide-user-plus" :loading="state === 'joining'" @click="join">
        Rejoindre le journal
      </UButton>
    </UCard>
  </div>
</template>
