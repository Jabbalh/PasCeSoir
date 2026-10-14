import { liveQuery } from 'dexie'
import type { WatchSource } from 'vue'

export function useDb() {
  const { user } = useAuth()
  if (!user.value) throw new Error('Utilisateur non connecté')
  return openDb(user.value.id)
}

/**
 * Requête réactive sur IndexedDB : se met à jour automatiquement à chaque
 * modification locale (y compris celles apportées par la synchro).
 */
export function useLiveQuery<T>(query: () => T | Promise<T>, initial: T, deps: WatchSource[] = []) {
  const result = shallowRef<T>(initial) as Ref<T>
  const loading = ref(true)
  let sub: { unsubscribe(): void } | null = null

  const start = () => {
    sub?.unsubscribe()
    sub = liveQuery(query).subscribe({
      next: (v) => {
        result.value = v
        loading.value = false
      },
      error: (e) => console.error('[liveQuery]', e)
    })
  }

  if (deps.length) watch(deps, start, { immediate: true })
  else start()

  onScopeDispose(() => sub?.unsubscribe())
  return { data: result, loading }
}
