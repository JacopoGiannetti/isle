#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Una bolla di vetro quasi invisibile sopra il livello. Con `power` alto ingrandisce al centro
// e capovolge verso il bordo, separando i colori sui contorni. `glow` accende una luce azzurra
// a sorriso nella parte bassa, che con `spread` si allarga lungo il bordo.
static float band(float x, float c, float w) {
    float t = (x - c) / w;
    return exp(-t * t);
}

[[ stitchable ]] half4 lens(float2 p, SwiftUI::Layer layer, float2 center, float radius,
                            float power, float glow, float spread, float amount) {
    half4 src = layer.sample(p);
    if (amount <= 0.001 || radius < 1.0) return src;

    float2 d = p - center;
    float dist = length(d);
    float norm = dist / radius;
    float2 n = dist > 0.001 ? d / dist : float2(0.0, 1.0);

    // Ombra chiara e morbida, un po' più in basso della bolla.
    float2 sc = center + float2(0.0, radius * 0.12);
    float sdS = length(p - sc) - radius * 0.9;
    float shade = (1.0 - smoothstep(-radius * 0.15, radius * 0.3, sdS)) * 0.11 * power * amount;
    half4 out = half4(src.rgb * half(1.0 - shade), src.a);

    if (norm < 1.0) {
        // Al centro ingrandisce appena; nella fascia del bordo il campione passa dall'altra parte
        // e l'immagine si capovolge.
        float m = mix(0.97, 0.88, power);
        float e0 = mix(0.45, 0.66, power);
        float s = m - (m + 0.95) * smoothstep(e0, 1.0, norm) * power;
        float norm1 = norm + 1.0 / radius;
        float s1 = m - (m + 0.95) * smoothstep(e0, 1.0, norm1) * power;
        float squeeze = abs(s1 * norm1 - s * norm) * radius;
        float2 q = center + d * s;
        float2 sq = n * clamp(squeeze * 0.5, 0.0, 12.0);
        float disp = 0.11 * power * norm * norm * radius;
        half4 g = (layer.sample(q) + layer.sample(q + sq) + layer.sample(q - sq)
                   + layer.sample(q + sq * 0.5) + layer.sample(q - sq * 0.5)) * 0.2h;
        half4 r = layer.sample(q + n * disp);
        half4 b = layer.sample(q - n * disp);
        half4 lensed = half4(r.r, g.g, b.b, max(g.a, max(r.a, b.a)));
        // Dove l'immagine si gira tutto convergerebbe in un punto: lì il vetro mostra lo sfondo.
        float turn = (1.0 - smoothstep(0.03, 0.16, abs(s))) * power;
        lensed = mix(lensed, src, half(turn));

        // Bordo un filo più scuro e un sottile filo di luce in alto. Si schiarisce solo quello
        // che c'è sotto: aggiungere bianco dove il livello è vuoto lo renderebbe opaco.
        float edge = smoothstep(0.86, 1.0, norm);
        lensed.rgb *= half(1.0 - (0.06 + 0.12 * power) * edge * amount);
        float top = max(0.0, -n.y);
        float rim = smoothstep(0.975, 0.992, norm) * (1.0 - smoothstep(0.992, 1.0, norm)) * (0.2 + 0.8 * top);
        lensed.rgb = mix(lensed.rgb, half3(lensed.a), half(rim * 0.5 * amount));

        float mask = 1.0 - smoothstep(radius - 1.5, radius, dist);
        out = mix(out, lensed, half(mask));
    }

    // Luce azzurra a sorriso: azzurro chiaro dentro, blu nel mezzo, alone lilla che sborda.
    if (glow > 0.001) {
        float ang = smoothstep(mix(0.7, -0.15, spread), 1.0, n.y);
        float a = glow * ang * amount;
        float rc = mix(0.35, 0.86, spread);
        float lilac = band(norm, rc + 0.14, 0.11);
        float cyan = band(norm, rc - 0.1, 0.08);
        float blue = band(norm, rc, 0.065);
        half k = out.a;
        out.rgb = mix(out.rgb, half3(0.86, 0.66, 1.0) * k, half(lilac * 0.5 * a));
        out.rgb = mix(out.rgb, half3(0.5, 0.9, 1.0) * k, half(cyan * 0.75 * a));
        out.rgb = mix(out.rgb, half3(0.12, 0.27, 1.0) * k, half(blue * 0.92 * a));
    }
    return out;
}
