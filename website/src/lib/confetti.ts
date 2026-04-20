import confetti from 'canvas-confetti';

export const triggerConfetti = () => {
  confetti({
    particleCount: 150,
    spread: 70,
    origin: { y: 0.6 },
    colors: ['#98ff98', '#ff7f50', '#fdfcf0']
  });
};
