import React, { useRef, useState, useCallback } from 'react';
import { View, Text, PanResponder, LayoutChangeEvent } from 'react-native';
import Svg, { Path } from 'react-native-svg';
import { useColors } from '../hooks/useColors';
import { radius, font } from '../lib/theme';
import { Button } from './ui/Button';
import { Eraser } from 'lucide-react-native';

interface SignaturePadProps {
  height?: number;
  /** Called with an SVG data-URI of the signature (empty string if cleared). */
  onChange: (svgDataUri: string) => void;
}

/**
 * Lightweight signature capture using SVG + PanResponder (no extra native
 * deps). Exports the strokes as an SVG data-URI so the proof of delivery can
 * be stored/synced even offline, without an image upload.
 */
export function SignaturePad({ height = 180, onChange }: SignaturePadProps) {
  const { colors } = useColors();
  const [paths, setPaths] = useState<string[]>([]);
  const [current, setCurrent] = useState<string>('');
  const widthRef = useRef(300);

  const buildSvg = useCallback(
    (all: string[]) => {
      if (all.length === 0) return '';
      const w = widthRef.current;
      const body = all
        .map(
          (d) =>
            `<path d="${d}" stroke="#0F172A" stroke-width="2.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`,
        )
        .join('');
      const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${height}" viewBox="0 0 ${w} ${height}">${body}</svg>`;
      return `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`;
    },
    [height],
  );

  const responder = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onMoveShouldSetPanResponder: () => true,
      onPanResponderGrant: (e) => {
        const { locationX, locationY } = e.nativeEvent;
        setCurrent(`M ${locationX.toFixed(1)} ${locationY.toFixed(1)}`);
      },
      onPanResponderMove: (e) => {
        const { locationX, locationY } = e.nativeEvent;
        setCurrent((c) => `${c} L ${locationX.toFixed(1)} ${locationY.toFixed(1)}`);
      },
      onPanResponderRelease: () => {
        setCurrent((c) => {
          if (!c) return '';
          setPaths((prev) => {
            const next = [...prev, c];
            onChange(buildSvg(next));
            return next;
          });
          return '';
        });
      },
    }),
  ).current;

  const clear = () => {
    setPaths([]);
    setCurrent('');
    onChange('');
  };

  const onLayout = (e: LayoutChangeEvent) => {
    widthRef.current = e.nativeEvent.layout.width;
  };

  const allPaths = current ? [...paths, current] : paths;

  return (
    <View style={{ width: '100%' }}>
      <View
        onLayout={onLayout}
        {...responder.panHandlers}
        style={{
          height,
          backgroundColor: colors.cardMuted,
          borderRadius: radius.lg,
          borderWidth: 2,
          borderColor: colors.border,
          overflow: 'hidden',
        }}
      >
        <Svg width="100%" height="100%">
          {allPaths.map((d, i) => (
            <Path
              key={i}
              d={d}
              stroke={colors.text}
              strokeWidth={2.5}
              fill="none"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          ))}
        </Svg>
        {paths.length === 0 && !current ? (
          <Text
            style={{
              position: 'absolute',
              alignSelf: 'center',
              top: height / 2 - 10,
              color: colors.textSubtle,
              fontWeight: font.medium,
            }}
          >
            Assine aqui com o dedo
          </Text>
        ) : null}
      </View>
      <View style={{ marginTop: 8, alignSelf: 'flex-end' }}>
        <Button
          label="Limpar"
          variant="ghost"
          size="sm"
          fullWidth={false}
          onPress={clear}
          icon={<Eraser size={16} color={colors.textMuted} />}
        />
      </View>
    </View>
  );
}
