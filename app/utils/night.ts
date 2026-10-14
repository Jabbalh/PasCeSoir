/**
 * Une « nuit » va de 14h à 14h le lendemain : un réveil à 3h du matin le mardi
 * appartient à la nuit du lundi au mardi.
 */
export const NIGHT_PIVOT_HOUR = 14

/** Clé de nuit = date (AAAA-MM-JJ, heure locale) du soir */
export function nightKey(date: Date | string): string {
  const d = new Date(date)
  d.setHours(d.getHours() - NIGHT_PIVOT_HOUR)
  return toDateKey(d)
}

export function toDateKey(d: Date): string {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

export function fromDateKey(key: string): Date {
  const [y, m, d] = key.split('-').map(Number)
  return new Date(y!, m! - 1, d!)
}

export function addDays(d: Date, n: number): Date {
  const r = new Date(d)
  r.setDate(r.getDate() + n)
  return r
}

/** Bornes [début, fin[ de la nuit (pour requêtes) */
export function nightRange(key: string): [Date, Date] {
  const start = fromDateKey(key)
  start.setHours(NIGHT_PIVOT_HOUR, 0, 0, 0)
  return [start, addDays(start, 1)]
}

const fmtShort = new Intl.DateTimeFormat('fr-FR', { weekday: 'short', day: 'numeric', month: 'short' })

export function nightLabel(key: string): string {
  const start = fromDateKey(key)
  const end = addDays(start, 1)
  return `Nuit du ${fmtShort.format(start)} au ${fmtShort.format(end)}`
}

export function formatTime(date: string | Date): string {
  return new Date(date).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })
}

export function formatDateTime(date: string | Date): string {
  return new Date(date).toLocaleString('fr-FR', {
    weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit'
  })
}

/** Lundi (clé AAAA-MM-JJ) de la semaine contenant la date */
export function weekKey(key: string): string {
  const d = fromDateKey(key)
  const day = (d.getDay() + 6) % 7
  return toDateKey(addDays(d, -day))
}

export function monthKey(key: string): string {
  return key.slice(0, 7)
}

/** Valeur pour <input type="datetime-local"> */
export function toLocalInput(date: string | Date): string {
  const d = new Date(date)
  return `${toDateKey(d)}T${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
}
