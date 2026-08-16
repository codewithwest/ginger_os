import { memo } from 'react';

const CUBE_FACES = [
  'rotateY(0deg) translateZ(40px)',
  'rotateY(90deg) translateZ(40px)',
  'rotateY(180deg) translateZ(40px)',
  'rotateY(-90deg) translateZ(40px)',
  'rotateX(90deg) translateZ(40px)',
  'rotateX(-90deg) translateZ(40px)',
];

function Cube({ size, top, left, duration, delay, color }: {
  size: number; top: string; left: string; duration: string; delay: string; color: string;
}) {
  return (
    <div
      className="bg-cube"
      style={{
        width: size, height: size, top, left,
        animationDuration: duration, animationDelay: delay,
        ['--cube-color' as string]: color,
      }}
    >
      {CUBE_FACES.map((t, i) => (
        <div key={i} className="bg-cube-face" style={{ transform: t }} />
      ))}
    </div>
  );
}

function Background3DInner() {
  return (
    <div className="bg-scene" aria-hidden="true">
      <div className="bg-grid" />

      {/* floating gradient orbs */}
      <div className="bg-orb" style={{ width: 460, height: 460, top: '-8%', right: '-4%', background: 'rgba(0,210,255,0.16)', animationDuration: '16s' }} />
      <div className="bg-orb" style={{ width: 380, height: 380, bottom: '-10%', left: '-6%', background: 'rgba(0,255,136,0.12)', animationDuration: '22s', animationDelay: '-6s' }} />
      <div className="bg-orb" style={{ width: 300, height: 300, top: '42%', left: '38%', background: 'rgba(58,123,213,0.14)', animationDuration: '28s', animationDelay: '-12s' }} />

      {/* wireframe cubes */}
      <Cube size={120} top="14%" left="6%" duration="38s" delay="-5s" color="rgba(0,210,255,0.35)" />
      <Cube size={70} top="64%" left="88%" duration="26s" delay="-14s" color="rgba(0,255,136,0.35)" />
      <Cube size={46} top="78%" left="12%" duration="20s" delay="-2s" color="rgba(58,123,213,0.4)" />

      {/* rising particles */}
      {[...Array(14)].map((_, i) => (
        <div
          key={i}
          className="bg-particle"
          style={{
            left: `${(i * 7 + 4) % 100}%`,
            bottom: `${(i * 13) % 60}%`,
            animationDuration: `${9 + (i % 6) * 2.5}s`,
            animationDelay: `${(i * 1.7) % 8}s`,
            ['--cube-color' as string]: i % 3 === 0 ? 'rgba(0,255,136,0.7)' : i % 3 === 1 ? 'rgba(0,210,255,0.7)' : 'rgba(58,123,213,0.7)',
          }}
        />
      ))}

      <div className="bg-vignette" />
    </div>
  );
}

export const Background3D = memo(Background3DInner);
