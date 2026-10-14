<script setup lang="ts">
const { user } = useAuth()
const { start } = useSync()

watch(user, (u) => {
  if (u) start()
}, { immediate: true })
</script>

<template>
  <UApp :toaster="{ position: 'top-center', duration: 4000 }">
    <NuxtPwaManifest />
    <ClientOnly>
      <PwaPrompts />
    </ClientOnly>
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
  </UApp>
</template>
