<template>
  <div class="min-h-dvh flex flex-col items-center justify-center px-4 py-10 bg-default pt-[env(safe-area-inset-top)]">
    <div class="w-full max-w-sm">
      <div class="flex flex-col items-center mb-8">
        <img src="/icon.svg" alt="" class="size-20 mb-3">
        <h1 class="text-3xl font-extrabold">Pas ce soir</h1>
        <p class="text-muted text-sm mt-1">Le journal des réveils de votre enfant</p>
      </div>
      <slot />
    </div>
  </div>
</template>
