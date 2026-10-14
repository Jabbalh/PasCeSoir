<script setup lang="ts">
const route = useRoute()
const journalId = computed(() => route.params.id as string)
const supabase = useSupabase()
const toast = useToast()
const { user } = useAuth()
const { online, sync } = useSync()
const { journal, members, isOwner } = useJournal(journalId)
const { updateJournal } = useJournalActions()

// --- Informations ---
const form = reactive({ name: '', child_name: '' })
watch(journal, (j) => {
  if (j && !form.name) {
    form.name = j.name
    form.child_name = j.child_name
  }
}, { immediate: true })

async function saveInfo() {
  await updateJournal(journalId.value, { name: form.name.trim(), child_name: form.child_name.trim() })
  toast.add({ title: 'Journal mis à jour', color: 'success', icon: 'i-lucide-check' })
}

// --- Partage ---
const shareUrl = computed(() => journal.value?.share_token ? `${location.origin}/rejoindre/${journal.value.share_token}` : '')
const sharing = ref(false)

function randomToken() {
  const bytes = crypto.getRandomValues(new Uint8Array(18))
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

async function setShareToken(token: string | null) {
  sharing.value = true
  try {
    // le journal doit exister côté serveur avant de générer un lien
    await sync()
    const { error } = await supabase.from('journals').update({ share_token: token }).eq('id', journalId.value)
    if (error) throw error
    await sync()
    toast.add({ title: token ? 'Lien de partage créé' : 'Lien de partage désactivé', color: 'success' })
  } catch (e) {
    toast.add({ title: 'Oups', description: errorMessage(e), color: 'error' })
  } finally {
    sharing.value = false
  }
}

async function share() {
  const text = `Rejoins le journal des nuits de ${journal.value?.child_name || 'notre enfant'} sur Pas ce soir`
  if (navigator.share) {
    try {
      await navigator.share({ title: 'Pas ce soir', text, url: shareUrl.value })
      return
    } catch { /* partage annulé : on copie */ }
  }
  await copy()
}

async function copy() {
  try {
    await navigator.clipboard.writeText(shareUrl.value)
    toast.add({ title: 'Lien copié', icon: 'i-lucide-clipboard-check', color: 'success' })
  } catch {
    toast.add({ title: 'Copie impossible', description: shareUrl.value, color: 'warning' })
  }
}

// --- Membres ---
const confirmAction = ref<null | { title: string, description: string, label: string, run: () => Promise<void> }>(null)
const confirmOpen = computed({
  get: () => !!confirmAction.value,
  set: (v) => {
    if (!v) confirmAction.value = null
  }
})
const running = ref(false)

async function runConfirm() {
  if (!confirmAction.value) return
  running.value = true
  try {
    await confirmAction.value.run()
    confirmAction.value = null
  } catch (e) {
    toast.add({ title: 'Oups', description: errorMessage(e), color: 'error' })
  } finally {
    running.value = false
  }
}

function askRemoveMember(userId: string, name: string) {
  confirmAction.value = {
    title: `Retirer ${name} ?`,
    description: 'Cette personne n\'aura plus accès au journal.',
    label: 'Retirer',
    run: async () => {
      const { error } = await supabase.from('journal_members').delete().eq('journal_id', journalId.value).eq('user_id', userId)
      if (error) throw error
      await sync()
    }
  }
}

function askLeave() {
  confirmAction.value = {
    title: 'Quitter ce journal ?',
    description: 'Vous n\'y aurez plus accès, sauf nouvelle invitation.',
    label: 'Quitter',
    run: async () => {
      const { error } = await supabase.from('journal_members').delete().eq('journal_id', journalId.value).eq('user_id', user.value!.id)
      if (error) throw error
      await sync()
      await navigateTo('/')
    }
  }
}

function askDelete() {
  confirmAction.value = {
    title: 'Supprimer ce journal ?',
    description: 'Le journal et tous ses réveils seront supprimés pour tous les membres.',
    label: 'Supprimer définitivement',
    run: async () => {
      await updateJournal(journalId.value, { deleted_at: new Date().toISOString() })
      try {
        localStorage.removeItem('pcs:lastJournal')
      } catch { /* ignore */ }
      await navigateTo('/')
    }
  }
}
</script>

<template>
  <div class="space-y-5">
    <h1 class="text-2xl font-bold">
      Réglages
    </h1>

    <UCard>
      <template #header>
        <h2 class="font-semibold">
          Journal
        </h2>
      </template>
      <form class="space-y-4" @submit.prevent="saveInfo">
        <UFormField label="Prénom de l'enfant">
          <UInput v-model="form.child_name" size="lg" class="w-full" />
        </UFormField>
        <UFormField label="Nom du journal" required>
          <UInput v-model="form.name" size="lg" class="w-full" required />
        </UFormField>
        <UButton type="submit" block>
          Enregistrer
        </UButton>
      </form>
    </UCard>

    <UCard>
      <template #header>
        <h2 class="font-semibold">
          Partager le journal
        </h2>
        <p class="text-sm text-muted">
          Envoyez ce lien à l'autre parent, à la nounou… Il pourra créer un compte et rejoindre le journal.
        </p>
      </template>

      <UAlert
        v-if="!online"
        icon="i-lucide-wifi-off"
        color="warning"
        variant="soft"
        title="Connexion internet requise pour gérer le partage"
        class="mb-3"
      />

      <div v-if="shareUrl" class="space-y-3">
        <UInput :model-value="shareUrl" readonly class="w-full" :ui="{ base: 'text-xs' }" @focus="($event.target as HTMLInputElement).select()" />
        <div class="grid grid-cols-2 gap-2">
          <UButton icon="i-lucide-share-2" class="justify-center" @click="share">
            Partager
          </UButton>
          <UButton icon="i-lucide-copy" color="neutral" variant="soft" class="justify-center" @click="copy">
            Copier
          </UButton>
        </div>
        <div v-if="isOwner" class="flex justify-between">
          <UButton size="xs" variant="link" color="neutral" icon="i-lucide-refresh-cw" :disabled="!online || sharing" @click="setShareToken(randomToken())">
            Nouveau lien
          </UButton>
          <UButton size="xs" variant="link" color="error" icon="i-lucide-link-2-off" :disabled="!online || sharing" @click="setShareToken(null)">
            Désactiver le lien
          </UButton>
        </div>
      </div>
      <div v-else-if="isOwner">
        <UButton block icon="i-lucide-link" :loading="sharing" :disabled="!online" @click="setShareToken(randomToken())">
          Créer un lien d'invitation
        </UButton>
      </div>
      <p v-else class="text-sm text-muted">
        Seul le créateur du journal peut créer un lien d'invitation.
      </p>
    </UCard>

    <UCard>
      <template #header>
        <h2 class="font-semibold">
          Membres ({{ members.length }})
        </h2>
      </template>
      <ul class="divide-y divide-default -my-2">
        <li v-for="m in members" :key="m.key" class="flex items-center gap-3 py-2.5">
          <UAvatar :alt="m.display_name" size="sm" />
          <div class="flex-1 min-w-0">
            <p class="truncate font-medium">
              {{ m.user_id === user?.id ? `${m.display_name} (moi)` : m.display_name }}
            </p>
            <p class="text-xs text-muted">
              {{ m.role === 'owner' ? 'Créateur' : 'Membre' }}
            </p>
          </div>
          <UButton
            v-if="isOwner && m.user_id !== user?.id"
            icon="i-lucide-user-minus"
            color="error"
            variant="ghost"
            size="sm"
            :disabled="!online"
            aria-label="Retirer"
            @click="askRemoveMember(m.user_id, m.display_name)"
          />
        </li>
      </ul>
    </UCard>

    <UCard :ui="{ root: 'ring-error/40' }">
      <template #header>
        <h2 class="font-semibold text-error">
          Zone sensible
        </h2>
      </template>
      <UButton v-if="isOwner" block color="error" variant="soft" icon="i-lucide-trash-2" @click="askDelete">
        Supprimer le journal
      </UButton>
      <UButton v-else block color="error" variant="soft" icon="i-lucide-log-out" :disabled="!online" @click="askLeave">
        Quitter le journal
      </UButton>
    </UCard>

    <UModal v-model:open="confirmOpen" :title="confirmAction?.title" :description="confirmAction?.description">
      <template #footer>
        <div class="flex gap-2 w-full">
          <UButton color="neutral" variant="ghost" class="flex-1 justify-center" @click="confirmAction = null">
            Annuler
          </UButton>
          <UButton color="error" class="flex-1 justify-center" :loading="running" @click="runConfirm">
            {{ confirmAction?.label }}
          </UButton>
        </div>
      </template>
    </UModal>
  </div>
</template>
