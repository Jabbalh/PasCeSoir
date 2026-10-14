<script setup lang="ts">
const supabase = useSupabase()
const { user } = useAuth()
const { online, sync } = useSync()
const toast = useToast()

const displayName = ref('')
const loading = ref(false)

onMounted(async () => {
  if (!online.value) return
  const { data } = await supabase.from('profiles').select('display_name').eq('id', user.value!.id).single()
  displayName.value = data?.display_name ?? ''
})

async function save() {
  loading.value = true
  try {
    const { error } = await supabase.from('profiles').update({ display_name: displayName.value.trim() }).eq('id', user.value!.id)
    if (error) throw error
    toast.add({ title: 'Profil enregistré', color: 'success' })
    sync()
  } catch (e) {
    toast.add({ title: 'Oups', description: errorMessage(e), color: 'error' })
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="space-y-4">
    <h1 class="text-2xl font-bold">
      Mon profil
    </h1>
    <UCard>
      <form class="space-y-4" @submit.prevent="save">
        <UFormField label="Email">
          <UInput :model-value="user?.email" disabled size="lg" class="w-full" />
        </UFormField>
        <UFormField label="Nom affiché" help="Visible par les autres membres de vos journaux">
          <UInput v-model="displayName" size="lg" class="w-full" required />
        </UFormField>
        <UButton type="submit" block size="lg" :loading="loading" :disabled="!online">
          {{ online ? 'Enregistrer' : 'Connexion requise' }}
        </UButton>
      </form>
    </UCard>
  </div>
</template>
