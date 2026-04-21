import confetti from 'canvas-confetti';

export const triggerConfetti = () => {
  confetti({
    particleCount: 150,
    spread: 70,
    origin: { y: 0.6 },
    colors: ['#00e5a0', '#5352ed', '#ffd32a']
  });
};
