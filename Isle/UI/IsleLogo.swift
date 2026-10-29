import SwiftUI

/// Il marchio: una piccola isola volante con il suo albero, una stella e un filo d'acqua.
struct IsleMark: View {
    var size: CGFloat = 60

    var body: some View {
        Canvas { ctx, s in
            ctx.scaleBy(x: s.width / 64, y: s.height / 64)

            var rock = Path()
            rock.move(to: CGPoint(x: 8, y: 31))
            rock.addLine(to: CGPoint(x: 56, y: 31))
            rock.addQuadCurve(to: CGPoint(x: 33, y: 61), control: CGPoint(x: 50, y: 45))
            rock.addQuadCurve(to: CGPoint(x: 8, y: 31), control: CGPoint(x: 15, y: 43))
            ctx.fill(rock, with: .linearGradient(Gradient(colors: [Color(hex: 0xC2A4BE), Color(hex: 0x6A4F6E)]),
                                                 startPoint: CGPoint(x: 32, y: 31), endPoint: CGPoint(x: 32, y: 61)))
            var facet = Path()
            facet.move(to: CGPoint(x: 31, y: 31))
            facet.addLine(to: CGPoint(x: 56, y: 31))
            facet.addQuadCurve(to: CGPoint(x: 33, y: 61), control: CGPoint(x: 50, y: 45))
            facet.closeSubpath()
            ctx.fill(facet, with: .color(.black.opacity(0.13)))

            var fall = Path(roundedRect: CGRect(x: 13, y: 32, width: 2.6, height: 19), cornerRadius: 1.3)
            fall.addRoundedRect(in: CGRect(x: 17.5, y: 33, width: 1.6, height: 11), cornerSize: CGSize(width: 0.8, height: 0.8))
            ctx.fill(fall, with: .linearGradient(Gradient(colors: [Color(hex: 0xD6F6FF), Color(hex: 0xD6F6FF, opacity: 0)]),
                                                 startPoint: CGPoint(x: 0, y: 32), endPoint: CGPoint(x: 0, y: 51)))

            ctx.fill(Path(ellipseIn: CGRect(x: 6, y: 25, width: 52, height: 13)), with: .color(Color(hex: 0x3F8A45)))
            ctx.fill(Path(ellipseIn: CGRect(x: 6, y: 20.5, width: 52, height: 13)),
                     with: .linearGradient(Gradient(colors: [Color(hex: 0xA6E27A), Color(hex: 0x5DAE52)]),
                                           startPoint: CGPoint(x: 20, y: 20), endPoint: CGPoint(x: 44, y: 34)))

            ctx.fill(Path(ellipseIn: CGRect(x: 15, y: 20, width: 9, height: 7)), with: .color(Color(hex: 0x4E9A4C)))
            ctx.fill(Path(roundedRect: CGRect(x: 35, y: 15, width: 3.4, height: 12), cornerRadius: 1.2), with: .color(Color(hex: 0x7A5236)))
            ctx.fill(Path(ellipseIn: CGRect(x: 27, y: 2, width: 20, height: 18)),
                     with: .linearGradient(Gradient(colors: [Color(hex: 0x7CCB63), Color(hex: 0x3E8A47)]),
                                           startPoint: CGPoint(x: 30, y: 3), endPoint: CGPoint(x: 44, y: 19)))
            ctx.fill(Path(ellipseIn: CGRect(x: 31, y: 5, width: 7, height: 6)), with: .color(.white.opacity(0.35)))

            let c = CGPoint(x: 53, y: 9)
            var star = Path()
            for i in 0..<8 {
                let a = Double(i) * .pi / 4 - .pi / 2
                let r: Double = i % 2 == 0 ? 6.5 : 1.8
                let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                if i == 0 { star.move(to: p) } else { star.addLine(to: p) }
            }
            star.closeSubpath()
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 6, y: c.y - 6, width: 12, height: 12)), with: .color(Color(hex: 0xFFE27A, opacity: 0.35)))
            ctx.fill(star, with: .color(Color(hex: 0xFFD45A)))
        }
        .frame(width: size, height: size)
    }
}

/// Marchio e nome insieme, come nell'icona dell'app.
struct IsleLogo: View {
    var floating = true

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                IsleMark(size: 58)
                    .phaseAnimator([false, true]) { v, up in
                        v.offset(y: floating && up ? -3 : 1)
                    } animation: { _ in .easeInOut(duration: 1.8) }
                Text(Brand.name)
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.white, Color(hex: 0xFFF1D6)], startPoint: .top, endPoint: .bottom))
            }
            Text(Brand.tagline.uppercased())
                .font(.cozy(11, .bold))
                .tracking(2.4)
                .foregroundStyle(.white.opacity(0.9))
        }
        .shadow(color: Color(hex: 0x10202A, opacity: 0.3), radius: 10, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Brand.name), \(Brand.tagline)")
    }
}
