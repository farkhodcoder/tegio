<script lang="ts">
  // Bonus kartasi non ko'rinishida: har bir shtamp chekich izi.
  let {
    stamps,
    total,
    tiers = [],
    unit = '',
    animate = false,
    freshIndex = -1,
    startDeg = -90
  }: {
    stamps: number;
    total: number;
    tiers?: number[];
    unit?: string;
    animate?: boolean;
    freshIndex?: number;
    startDeg?: number;
  } = $props();

  const C = 160;
  const RING = 106;

  const slots = $derived(
    Array.from({ length: total }, (_, i) => {
      const angle = (i / total) * Math.PI * 2 + (startDeg * Math.PI) / 180;
      return { i, x: C + RING * Math.cos(angle), y: C + RING * Math.sin(angle), tier: tiers.includes(i + 1) };
    })
  );
  const slotRadius = $derived(Math.min(25, Math.PI * RING / total - 5));
  const petals = Array.from({ length: 8 }, (_, i) => (i / 8) * Math.PI * 2);
  const centerDots = [18, 34, 50].flatMap((r, ring) =>
    Array.from({ length: 8 + ring * 6 }, (_, i) => {
      const a = (i / (8 + ring * 6)) * Math.PI * 2 + ring * 0.2;
      return { x: C + r * Math.cos(a), y: C + r * Math.sin(a) };
    })
  );
</script>

<svg viewBox="0 0 320 320" role="img" aria-label={`${stamps} / ${total} ${unit}`} class="non">
  <circle cx={C} cy={C} r="156" fill="var(--crust)" />
  <circle cx={C} cy={C} r="146" fill="var(--dough)" />
  <circle cx={C} cy={C} r="66" fill="#E3BC7C" />
  {#if !unit}
    {#each centerDots as dot, index (index)}
      <circle cx={dot.x} cy={dot.y} r="2.6" fill="#8A5A1C" />
    {/each}
  {:else}
    <text x={C} y={C + 4} text-anchor="middle" class="count">{stamps}<tspan class="of">/{total}</tspan></text>
    <text x={C} y={C + 30} text-anchor="middle" class="unit">{unit}</text>
  {/if}

  {#each slots as slot (slot.i)}
    {@const filled = slot.i < stamps}
    <g
      class:stamp={filled}
      class:fresh={slot.i === freshIndex}
      class:animate
      style={`--delay:${slot.i * 170 + 250}ms;transform-origin:${slot.x}px ${slot.y}px`}
    >
      <circle
        cx={slot.x}
        cy={slot.y}
        r={slotRadius}
        fill={filled ? '#B57A28' : 'none'}
        stroke={slot.tier ? 'var(--accent)' : '#C39A58'}
        stroke-width={slot.tier ? 3 : 1.5}
        stroke-dasharray={filled || slot.tier ? undefined : '3 4'}
      />
      {#if filled}
        <circle cx={slot.x} cy={slot.y} r={slotRadius * 0.18} fill="#5A3808" />
        {#each petals as angle, index (index)}
          <circle
            cx={slot.x + slotRadius * 0.58 * Math.cos(angle)}
            cy={slot.y + slotRadius * 0.58 * Math.sin(angle)}
            r={slotRadius * 0.13}
            fill="#5A3808"
          />
        {/each}
      {/if}
    </g>
  {/each}
</svg>

<style>
  .non {
    display: block;
    width: 100%;
    height: auto;
  }
  .count {
    font: 500 40px var(--display);
    fill: #4a2d05;
  }
  .of {
    font-size: 20px;
  }
  .unit {
    font: 600 13px var(--body);
    fill: #5a3808;
  }
  .stamp.animate {
    animation: press 420ms cubic-bezier(0.3, 1.3, 0.5, 1) backwards;
    animation-delay: var(--delay);
  }
  .stamp.fresh {
    animation: press 420ms cubic-bezier(0.3, 1.3, 0.5, 1);
  }
  @keyframes press {
    from {
      opacity: 0;
      transform: scale(1.7);
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .stamp.animate,
    .stamp.fresh {
      animation: none;
    }
  }
</style>
