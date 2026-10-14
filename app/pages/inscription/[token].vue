<script setup lang="ts">
definePageMeta({ layout: 'auth' })

const route = useRoute()
const supabase = useSupabase()
const toast = useToast()
const { user, signUp } = useAuth()
const { online } = useSync()

const token = computed(() => route.params.token as string)
const state = ref<'loading' | 'valid' | 'invalid'>('loading')
const loading = ref(false)
const form = reactive({ displayName: '', email: '', password: '' })

async function check() {
  if (!online.value) return
  state.value = 'loading'
  const { data, error } = await supabase.rpc('app_invite_is_valid', { p_token: token.value })
  state.value = !error && data ? 'valid' : 'invalid'
}

onMounted(check)
watch(online, (o) => {
  if (o) check()
})

async function submit() {
  loading.value = true
  try {
    const { needsConfirmation } = await signUp(form.email, form.password, form.displayName, { app: token.value })
    if (needsConfirmation) {
      toast.add({
        title: 'Compte créé',
        description: 'Confirmez votre email via le lien reçu, puis connectez-vous.',
        color: 'success',
        duration: 10000
      })
      await navigateTo('/connexion')
    } else {
      toast.add({ title: 'Bienvenue !', description: 'Créez maintenant le journal de votre enfant.', icon: 'i-lucide-party-popper', color: 'success' })
      await navigateTo('/')
    }
  } catch (e) {
    toast.add({ title: 'Oups', description: errorMessage(e), color: 'error' })
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <UCard>
    <UEmpty
      v-if="user"
      icon="i-lucide-user-check"
      title="Vous avez déjà un compte"
      description="Cette invitation sert à créer un nouveau compte."
      :actions="[{ label: 'Mes journaux', to: '/' }]"
    />
    <UEmpty
      v-else-if="!online"
      icon="i-lucide-wifi-off"
      title="Connexion requise"
      description="Connectez-vous à internet pour créer votre compte."
    />
    <div v-else-if="state === 'loading'" class="flex justify-center py-8">
      <UIcon name="i-lucide-loader-circle" class="size-8 animate-spin text-muted" />
    </div>
    <UEmpty
      v-else-if="state === 'invalid'"
      icon="i-lucide-link-2-off"
      title="Invitation invalide"
      description="Ce lien a expiré, a déjà été utilisé ou a été révoqué. Demandez-en un nouveau."
      :actions="[{ label: 'J\'ai déjà un compte', to: '/connexion', color: 'neutral', variant: 'soft' }]"
    />
    <template v-else>
      <UAlert
        class="mb-4"
        icon="i-lucide-mail-open"
        color="primary"
        variant="soft"
        title="Vous êtes invité à utiliser Pas ce soir"
        description="Créez votre compte, puis le journal de votre enfant."
      />
      <form class="space-y-4" @submit.prevent="submit">
        <UFormField label="Votre prénom" required>
          <UInput v-model="form.displayName" placeholder="ex. Maman, Papa, Julie…" size="xl" class="w-full" required autocomplete="given-name" />
        </UFormField>
        <UFormField label="Email" required>
          <UInput v-model="form.email" type="email" size="xl" class="w-full" required autocomplete="email" inputmode="email" />
        </UFormField>
        <UFormField label="Mot de passe" required hint="6 caractères minimum">
          <UInput v-model="form.password" type="password" size="xl" class="w-full" required minlength="6" autocomplete="new-password" />
        </UFormField>
        <UButton type="submit" block size="xl" :loading="loading">
          Créer mon compte
        </UButton>
      </form>
      <div class="mt-4 text-center">
        <UButton to="/connexion" variant="link" color="neutral" size="sm">
          J'ai déjà un compte
        </UButton>
      </div>
    </template>
  </UCard>
</template>
