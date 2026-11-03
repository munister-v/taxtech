// The clock of the evening in Rome (BankLanding runs it, RomeMap follows it): `p` is how far the evening has got,
// `g` how much the map camera has left the headline for the route.
export const romeClock = { p: 0, g: 0, subs: new Set<() => void>() };

export function setRomeClock(p: number, g: number) {
  romeClock.p = p; romeClock.g = g;
  romeClock.subs.forEach(f => f());
}
