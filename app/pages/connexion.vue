<script setup lang="ts">
definePageMeta({ layout: 'auth' })

const route = useRoute()
const { signIn, signUp, resetPassword } = useAuth()
const toast = useToast()

const mode = ref<'login' | 'signup' | 'reset'>('login')
const loading = ref(false)
const form = reactive({ email: '', password: '', displayName: '' })

const redirectTo = computed(() =>
  typeof route.query.redirect === 'string' && route.query.redirect.startsWith('/') ? route.query.redirect : '/')
const isInvite = computed(() => redirectTo.value.startsWith('/rejoindre/'))

async function submit() {
  loading.value = true
  try {
    if (mode.value === 'login') {
      await signIn(form.email, form.password)
      await navigateTo(redirectTo.value)
    } else if (mode.value === 'signup') {
      const { needsConfirmation } = await signUp(form.email, form.password, form.displayName)
      if (needsConfirmation) {
        toast.add({
          title: 'Compte créé',
          description: 'Confirmez votre email via le lien reçu, puis connectez-vous.',
          color: 'success',
          duration: 10000
        })
        mode.value = 'login'
      } else {
        await navigateTo(redirectTo.value)
      }
    } else {
      await resetPassword(form.email)
      toast.add({ title: 'Email envoyé', description: 'Suivez le lien reçu pour choisir un nouveau mot de passe.', color: 'success' })
      mode.value = 'login'
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
    <UAlert
      v-if="isInvite"
      class="mb-4"
      icon="i-lucide-mail-open"
      color="primary"
      variant="soft"
      title="Vous êtes invité à rejoindre un journal"
      description="Connectez-vous ou créez un compte pour continuer."
    />

    <UTabs
      v-if="mode !== 'reset'"
      v-model="mode"
      :items="[{ label: 'Connexion', value: 'login' }, { label: 'Créer un compte', value: 'signup' }]"
      :content="false"
      class="mb-4"
    />
    <h2 v-else class="font-semibold mb-4">
      Mot de passe oublié
    </h2>

    <form class="space-y-4" @submit.prevent="submit">
      <UFormField v-if="mode === 'signup'" label="Votre prénom" required>
        <UInput
          v-model="form.displayName"
          placeholder="ex. Maman, Papa, Julie…"
          size="xl"
          class="w-full"
          required
          autocomplete="given-name"
        />
      </UFormField>
      <UFormField label="Email" required>
        <UInput v-model="form.email" type="email" size="xl" class="w-full" required autocomplete="email" inputmode="email" />
      </UFormField>
      <UFormField v-if="mode !== 'reset'" label="Mot de passe" required :hint="mode === 'signup' ? '6 caractères minimum' : undefined">
        <UInput
          v-model="form.password"
          type="password"
          size="xl"
          class="w-full"
          required
          minlength="6"
          :autocomplete="mode === 'signup' ? 'new-password' : 'current-password'"
        />
      </UFormField>

      <UButton type="submit" block size="xl" :loading="loading">
        {{ mode === 'login' ? 'Se connecter' : mode === 'signup' ? 'Créer mon compte' : 'Envoyer le lien' }}
      </UButton>
    </form>

    <div class="mt-4 text-center text-sm">
      <UButton v-if="mode === 'login'" variant="link" color="neutral" @click="mode = 'reset'">
        Mot de passe oublié ?
      </UButton>
      <UButton v-else-if="mode === 'reset'" variant="link" color="neutral" @click="mode = 'login'">
        Retour à la connexion
      </UButton>
    </div>
  </UCard>
</template>
