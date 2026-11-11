export function usePathname() {
  if (typeof window === 'undefined') return '/';
  return window.location.pathname;
}

export function useRouter() {
  return {
    push: (url: string) => {
      if (typeof window !== 'undefined') window.location.assign(url);
    },
    replace: (url: string) => {
      if (typeof window !== 'undefined') window.location.replace(url);
    },
    back: () => {
      if (typeof window !== 'undefined') window.history.back();
    },
    refresh: () => {
      if (typeof window !== 'undefined') window.location.reload();
    },
  };
}

