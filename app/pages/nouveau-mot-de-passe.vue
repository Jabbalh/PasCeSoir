<script setup lang="ts">
definePageMeta({ layout: 'auth' })

const { updatePassword, user } = useAuth()
const toast = useToast()
const password = ref('')
const loading = ref(false)

async function submit() {
  loading.value = true
  try {
    await updatePassword(password.value)
    toast.add({ title: 'Mot de passe modifié', color: 'success' })
    await navigateTo('/')
  } catch (e) {
    toast.add({ title: 'Oups', description: errorMessage(e), color: 'error' })
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <UCard>
    <h2 class="font-semibold mb-4">
      Nouveau mot de passe
    </h2>
    <p v-if="!user" class="text-sm text-muted mb-4">
      Ouvrez cette page depuis le lien reçu par email.
    </p>
    <form class="space-y-4" @submit.prevent="submit">
      <UFormField label="Nouveau mot de passe" required hint="6 caractères minimum">
        <UInput v-model="password" type="password" size="xl" class="w-full" minlength="6" required autocomplete="new-password" />
      </UFormField>
      <UButton type="submit" block size="xl" :loading="loading" :disabled="!user">
        Enregistrer
      </UButton>
    </form>
  </UCard>
</template>
