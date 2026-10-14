const PUBLIC_ROUTES = ['/connexion', '/nouveau-mot-de-passe']

export default defineNuxtRouteMiddleware(async (to) => {
  const { user, isAdmin, init } = useAuth()
  await init()

  const isPublic = PUBLIC_ROUTES.includes(to.path) || to.path.startsWith('/inscription/')
  if (!user.value && !isPublic) {
    return navigateTo({ path: '/connexion', query: to.fullPath !== '/' ? { redirect: to.fullPath } : {} })
  }
  if (user.value && to.path === '/connexion') {
    const redirect = typeof to.query.redirect === 'string' && to.query.redirect.startsWith('/') ? to.query.redirect : '/'
    return navigateTo(redirect)
  }
  if (to.path.startsWith('/admin') && !isAdmin.value) {
    return navigateTo('/')
  }
})
