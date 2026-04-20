import React, { useState } from 'react';

const KNOWN_LOGOS: Record<string, string> = {
  'Hamrun Spartans': 'https://upload.wikimedia.org/wikipedia/en/e/eb/Hamrun_Spartans_logo.png',
  'Valletta': 'https://upload.wikimedia.org/wikipedia/en/0/07/Valletta_F.C._logo.svg',
  'Floriana': 'https://upload.wikimedia.org/wikipedia/en/a/ad/Floriana_FC_logo.svg',
  'Birkirkara': 'https://upload.wikimedia.org/wikipedia/en/0/07/Birkirkara_FC_logo.png',
  'Sliema Wanderers': 'https://upload.wikimedia.org/wikipedia/en/6/64/Sliema_Wanderers_FC_logo.png',
  'Hibernians': 'https://upload.wikimedia.org/wikipedia/en/7/7b/Hibernians_F.C._logo.svg',
  'AC Milan': 'https://upload.wikimedia.org/wikipedia/commons/d/da/Associazione_Calcio_Milan.svg',
  'Juventus': 'https://upload.wikimedia.org/wikipedia/commons/b/bc/Juventus_FC_2017_icon_%28black%29.svg',
  'Inter Milan': 'https://upload.wikimedia.org/wikipedia/commons/0/05/FC_Internazionale_Milano_2021.svg',
  'Arsenal': 'https://upload.wikimedia.org/wikipedia/en/5/53/Arsenal_FC.svg',
  'Liverpool': 'https://upload.wikimedia.org/wikipedia/en/0/0c/Liverpool_FC.svg',
  'Real Madrid': 'https://upload.wikimedia.org/wikipedia/en/5/56/Real_Madrid_CF.svg',
  'Barcelona': 'https://upload.wikimedia.org/wikipedia/en/4/47/FC_Barcelona_%28crest%29.svg',
  'Man City': 'https://upload.wikimedia.org/wikipedia/en/e/eb/Manchester_City_FC_badge.svg',
  'Man United': 'https://upload.wikimedia.org/wikipedia/en/7/7a/Manchester_United_FC_crest.svg',
  'Aston Villa': 'https://upload.wikimedia.org/wikipedia/en/9/9f/Aston_Villa_logo.svg',
  'Tottenham': 'https://upload.wikimedia.org/wikipedia/en/b/b4/Tottenham_Hotspur.svg',
  'Chelsea': 'https://upload.wikimedia.org/wikipedia/en/c/cc/Chelsea_FC.svg',
  'Newcastle': 'https://upload.wikimedia.org/wikipedia/en/5/56/Newcastle_United_Logo.svg'
};

interface TeamLogoProps {
  teamName: string;
  size?: number;
  className?: string;
}

export function TeamLogo({ teamName, size = 24, className = '' }: TeamLogoProps) {
  const [error, setError] = useState(false);
  const initials = encodeURIComponent(teamName.substring(0, 3).toUpperCase());
  const fallbackUrl = `https://ui-avatars.com/api/?name=${initials}&background=222&color=fff&bold=true&rounded=true&font-size=0.35`;
  const url = KNOWN_LOGOS[teamName] || fallbackUrl;

  return (
    <img 
      src={error ? fallbackUrl : url} 
      alt={`${teamName} logo`}
      width={size}
      height={size}
      className={`object-contain ${className}`}
      onError={() => setError(true)}
      referrerPolicy="no-referrer"
    />
  );
}
