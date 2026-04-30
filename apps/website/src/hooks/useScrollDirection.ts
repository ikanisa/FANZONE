import { useState, useEffect } from 'react';

export function useScrollDirection() {
  const [scrollDirection, setScrollDirection] = useState<'up' | 'down'>('up');

  useEffect(() => {
    let lastScrollY = window.pageYOffset;

    const updateScrollDirection = () => {
      const scrollY = window.pageYOffset;
      const direction = scrollY > lastScrollY ? 'down' : 'up';
      
      // Add a small threshold to avoid jitter on tiny scrolls (bounce effects)
      if (
        direction !== scrollDirection && 
        (scrollY - lastScrollY > 5 || scrollY - lastScrollY < -5) &&
        scrollY > 50 // Keep bars visible at the very top of the page
      ) {
        setScrollDirection(direction);
      }
      
      // Always show at the top of the page
      if (scrollY <= 50) {
        setScrollDirection('up');
      }

      lastScrollY = scrollY > 0 ? scrollY : 0;
    };

    window.addEventListener('scroll', updateScrollDirection, { passive: true });
    return () => {
      window.removeEventListener('scroll', updateScrollDirection);
    };
  }, [scrollDirection]);

  return scrollDirection;
}
