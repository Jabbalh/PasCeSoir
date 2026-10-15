import { DAY_PERIODS, type Approach } from './db'
import { fromDateKey } from './night'

export type ApproachStatus = 'a_venir' | 'en_cours' | 'terminee'

/** État d'une démarche à une date (AAAA-MM-JJ) : la date de fin est incluse */
export function approachStatus(a: Pick<Approach, 'start_date' | 'end_date'>, today: string): ApproachStatus {
  if (a.start_date > today) return 'a_venir'
  if (a.end_date && a.end_date < today) return 'terminee'
  return 'en_cours'
}

/** La démarche est-elle en place ce jour-là (ou la nuit commençant ce soir-là) ? */
export function isApproachActiveOn(a: Pick<Approach, 'start_date' | 'end_date'>, day: string): boolean {
  return a.start_date <= day && (!a.end_date || a.end_date >= day)
}

const fmtDate = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'short', year: 'numeric' })

export function formatDay(key: string): string {
  return fmtDate.format(fromDateKey(key))
}

/** « Depuis le 3 oct. 2026 », « Du 3 oct. au 12 oct. 2026 », « À partir du 20 oct. 2026 » */
export function approachDates(a: Pick<Approach, 'start_date' | 'end_date'>, today: string): string {
  if (a.end_date) return a.end_date === a.start_date ? `Le ${formatDay(a.start_date)}` : `Du ${formatDay(a.start_date)} au ${formatDay(a.end_date)}`
  return a.start_date > today ? `À partir du ${formatDay(a.start_date)}` : `Depuis le ${formatDay(a.start_date)}`
}

/** Nombre de jours (bornes incluses) */
export function daysBetween(from: string, to: string): number {
  return Math.round((fromDateKey(to).getTime() - fromDateKey(from).getTime()) / 86_400_000) + 1
}

export function periodsLabel(periods: Approach['periods']): string {
  return DAY_PERIODS.filter(p => periods.includes(p.value)).map(p => p.label).join(', ')
}
