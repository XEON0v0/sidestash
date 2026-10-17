import Testing
import simd
@testable import SideStash

struct GlassBevelTests {
    private let bevel = GlassBevel(width: 10, heightRatio: 1, profileExponent: 4, refractiveIndex: 1.5)
    private let samples = Array(stride(from: Float(0), through: 1, by: 0.05))

    // MARK: - Profile

    @Test func profile_risesFromTheOutlineToThePlateau() {
        #expect(bevel.profile(at: 0) == 0)
        #expect(abs(bevel.profile(at: 1) - 1) < 1e-6)
        let heights = samples.map { bevel.profile(at: $0) }
        #expect(zip(heights, heights.dropFirst()).allSatisfy { $0 < $1 })
        #expect(abs(bevel.height(at: 1) - 10) < 1e-4)
    }

    @Test func slope_isNearVerticalAtTheOutlineAndFlatAtThePlateau() {
        #expect(bevel.slope(at: 0) > 50)
        #expect(bevel.slope(at: 1) == 0)
        let slopes = samples.map { bevel.slope(at: $0) }
        #expect(zip(slopes, slopes.dropFirst()).allSatisfy { $0 >= $1 })
    }

    @Test func tightProfile_gathersItsCurvatureAtTheOutline() {
        // Steeper than 30° only in the outer part of the slope.
        let steep = tan(Float.pi / 6)
        #expect(bevel.slope(at: 0.2) > steep)
        #expect(bevel.slope(at: 0.35) < steep)

        let round = GlassBevel(width: 10, heightRatio: 1, profileExponent: 2, refractiveIndex: 1.5)
        #expect(round.slope(at: 0.35) > steep)
    }

    @Test func normal_tiltsOutwardAtTheOutlineAndPointsUpOnThePlateau() {
        let outward = SIMD2<Float>(1, 0)
        let edge = bevel.normal(at: 0.001, outward: outward)

        #expect(edge.x > 0.9)
        #expect(edge.z < 0.3)
        #expect(abs(simd_length(edge) - 1) < 1e-5)
        #expect(bevel.normal(at: 1, outward: outward) == SIMD3(0, 0, 1))
    }

    // MARK: - Optics

    @Test func fresnel_reflectsMostAtGrazingAngles() {
        #expect(abs(bevel.fresnel(cosine: 0) - 1) < 1e-6)
        // Glass reflects 4% head-on.
        #expect(abs(bevel.fresnel(cosine: 1) - 0.04) < 1e-4)
        #expect(bevel.fresnel(cosine: 0.3) > bevel.fresnel(cosine: 0.9))
    }

    @Test func refraction_pullsTheViewRayInwardOnlyWhereTheSlopeTilts() {
        #expect(abs(bevel.refractionOffset(at: 0)) < 1e-3)
        #expect(abs(bevel.refractionOffset(at: 1)) < 1e-6)

        let offset = bevel.refractionOffset(at: 0.1)
        #expect(offset > 1)
        #expect(offset < bevel.width)

        let air = GlassBevel(width: 10, heightRatio: 1, profileExponent: 4, refractiveIndex: 1)
        #expect(abs(air.refractionOffset(at: 0.1)) < 1e-4)
    }

    // MARK: - Outline

    @Test func outlinePoint_findsTheInsetAndOutwardNormal() {
        let size = SIMD2<Float>(296, 44)

        let top = GlassOutlinePoint(SIMD2(148, 0.5), size: size, cornerRadius: 12)
        #expect(abs(top.inset - 0.5) < 1e-5)
        #expect(top.normal == SIMD2(0, -1))

        let leading = GlassOutlinePoint(SIMD2(1, 22), size: size, cornerRadius: 12)
        #expect(abs(leading.inset - 1) < 1e-5)
        #expect(leading.normal == SIMD2(-1, 0))

        // On the top-left corner's diagonal, 2 pt in.
        let diagonal = Float(0.5).squareRoot()
        let corner = GlassOutlinePoint(SIMD2(12, 12) - SIMD2(repeating: diagonal * 10), size: size, cornerRadius: 12)
        #expect(abs(corner.inset - 2) < 1e-4)
        #expect(simd_length(corner.normal - SIMD2(-diagonal, -diagonal)) < 1e-4)

        #expect(GlassOutlinePoint(SIMD2(148, 22), size: size, cornerRadius: 12).inset == 22)
        #expect(abs(GlassOutlinePoint(SIMD2(-1, 22), size: size, cornerRadius: 12).inset + 1) < 1e-5)
    }

    @Test func outlinePoint_followsACapsulesRoundEnds() {
        let size = SIMD2<Float>(132, 40)

        let end = GlassOutlinePoint(SIMD2(0.5, 20), size: size, cornerRadius: 20)
        #expect(abs(end.inset - 0.5) < 1e-4)
        #expect(simd_length(end.normal - SIMD2(-1, 0)) < 1e-4)

        let top = GlassOutlinePoint(SIMD2(66, 0.5), size: size, cornerRadius: 20)
        #expect(abs(top.inset - 0.5) < 1e-5)
        #expect(top.normal == SIMD2(0, -1))
    }
}
