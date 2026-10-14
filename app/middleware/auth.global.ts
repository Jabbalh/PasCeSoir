const PUBLIC_ROUTES = ['/connexion', '/nouveau-mot-de-passe']

export default defineNuxtRouteMiddleware(async (to) => {
  const { user, init } = useAuth()
  await init()

  const isPublic = PUBLIC_ROUTES.includes(to.path)
  if (!user.value && !isPublic) {
    return navigateTo({ path: '/connexion', query: to.fullPath !== '/' ? { redirect: to.fullPath } : {} })
  }
  if (user.value && to.path === '/connexion') {
    const redirect = typeof to.query.redirect === 'string' && to.query.redirect.startsWith('/') ? to.query.redirect : '/'
    return navigateTo(redirect)
  }
})
