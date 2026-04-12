import CoreLocation
import Foundation

/// 把 GPS 坐标反查成「北京市朝阳区」这样的可读地名。
/// 带简单的内存缓存，避免短时间内对相邻坐标重复发起请求。
actor GeocodingService {

    static let shared = GeocodingService()

    private let geocoder = CLGeocoder()
    /// key = 保留 3 位小数的 "lat,lng"，粒度约 100 米
    private var cache: [String: String] = [:]

    func placeName(latitude: Double, longitude: Double) async -> String? {
        let key = Self.cacheKey(latitude: latitude, longitude: longitude)
        if let cached = cache[key] {
            return cached
        }

        let location = CLLocation(latitude: latitude, longitude: longitude)
        let locale = Locale(identifier: "zh_CN")

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(
                location,
                preferredLocale: locale
            )
            guard let placemark = placemarks.first else { return nil }
            let name = Self.format(placemark)
            if let name {
                cache[key] = name
            }
            return name
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    private static func cacheKey(latitude: Double, longitude: Double) -> String {
        String(format: "%.3f,%.3f", latitude, longitude)
    }

    /// 拼接「城市·区/景点」风格的中文短描述
    private static func format(_ placemark: CLPlacemark) -> String? {
        // 中文环境下 CLPlacemark 的字段含义：
        //   - administrativeArea: 省/直辖市
        //   - locality: 市
        //   - subLocality: 区 / 街道
        //   - name: POI 名称（商场、公园等）
        var parts: [String] = []
        if let city = placemark.locality, !city.isEmpty {
            parts.append(city)
        } else if let admin = placemark.administrativeArea, !admin.isEmpty {
            parts.append(admin)
        }
        if let sub = placemark.subLocality, !sub.isEmpty {
            parts.append(sub)
        } else if let name = placemark.name, !name.isEmpty {
            parts.append(name)
        }
        let joined = parts.joined(separator: "·")
        return joined.isEmpty ? nil : joined
    }
}
