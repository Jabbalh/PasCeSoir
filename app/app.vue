<script setup lang="ts">
const { user } = useAuth()
const { start } = useSync()

watch(user, (u) => {
  if (u) start()
}, { immediate: true })

// Impression / export PDF : toujours en thème clair (fond blanc, encre lisible)
onMounted(() => {
  const html = document.documentElement
  let wasDark = false
  window.addEventListener('beforeprint', () => {
    wasDark = html.classList.contains('dark')
    if (wasDark) html.classList.replace('dark', 'light')
  })
  window.addEventListener('afterprint', () => {
    if (wasDark) html.classList.replace('light', 'dark')
    wasDark = false
  })
})
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
