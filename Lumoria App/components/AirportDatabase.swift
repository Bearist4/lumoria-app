//
//  AirportDatabase.swift
//  Lumoria App
//
//  Static catalog of major IATA airports used to resolve an airport code
//  from a coordinate when MapKit's search result doesn't carry the IATA in
//  the name. Covers ~150 of the world's busiest airports — enough for the
//  vast majority of user flights.
//
//  To expand this list: append entries to `seed`. Coords are WGS84 (lat, lng)
//  taken from Wikipedia / OurAirports (public domain).
//

import CoreLocation
import Foundation

struct Airport: Hashable {
    let iata: String
    let name: String
    let city: String
    let country: String
    let countryCode: String
    let lat: Double
    let lng: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

enum AirportDatabase {

    /// Returns the nearest known airport within `radius` meters of `coord`,
    /// or nil if nothing matches. `radius` default is 10km — wide enough to
    /// cover a sprawling airport campus but tight enough to reject a city
    /// center that happens to sit near a smaller airstrip.
    static func nearest(
        to coord: CLLocationCoordinate2D,
        within radius: CLLocationDistance = 10_000
    ) -> Airport? {
        let target = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        var best: (airport: Airport, distance: CLLocationDistance)?
        for airport in seed {
            let candidate = CLLocation(latitude: airport.lat, longitude: airport.lng)
            let d = target.distance(from: candidate)
            if d <= radius, best == nil || d < best!.distance {
                best = (airport, d)
            }
        }
        return best?.airport
    }

    // MARK: - Seed

    /// Major airports by IATA code, roughly 150 entries covering the busiest
    /// hubs on every continent. Alphabetized by IATA.
    static let seed: [Airport] = [
        .init(iata: "ACE", name: "Lanzarote", city: "Arrecife", country: "Spain", countryCode: "ES", lat: 28.9455, lng: -13.6052),
        .init(iata: "ADD", name: "Addis Ababa Bole", city: "Addis Ababa", country: "Ethiopia", countryCode: "ET", lat: 8.9778, lng: 38.7989),
        .init(iata: "ADL", name: "Adelaide", city: "Adelaide", country: "Australia", countryCode: "AU", lat: -34.9461, lng: 138.5308),
        .init(iata: "AKL", name: "Auckland", city: "Auckland", country: "New Zealand", countryCode: "NZ", lat: -37.0082, lng: 174.7850),
        .init(iata: "AMS", name: "Amsterdam Schiphol", city: "Amsterdam", country: "Netherlands", countryCode: "NL", lat: 52.3086, lng: 4.7639),
        .init(iata: "ARN", name: "Stockholm Arlanda", city: "Stockholm", country: "Sweden", countryCode: "SE", lat: 59.6519, lng: 17.9186),
        .init(iata: "ATH", name: "Athens Eleftherios Venizelos", city: "Athens", country: "Greece", countryCode: "GR", lat: 37.9364, lng: 23.9445),
        .init(iata: "ATL", name: "Hartsfield-Jackson Atlanta", city: "Atlanta", country: "United States", countryCode: "US", lat: 33.6407, lng: -84.4277),
        .init(iata: "AUH", name: "Abu Dhabi", city: "Abu Dhabi", country: "United Arab Emirates", countryCode: "AE", lat: 24.4330, lng: 54.6511),
        .init(iata: "BAH", name: "Bahrain", city: "Manama", country: "Bahrain", countryCode: "BH", lat: 26.2708, lng: 50.6336),
        .init(iata: "BCN", name: "Barcelona El Prat", city: "Barcelona", country: "Spain", countryCode: "ES", lat: 41.2974, lng: 2.0833),
        .init(iata: "BER", name: "Berlin Brandenburg", city: "Berlin", country: "Germany", countryCode: "DE", lat: 52.3667, lng: 13.5033),
        .init(iata: "BHX", name: "Birmingham", city: "Birmingham", country: "United Kingdom", countryCode: "GB", lat: 52.4539, lng: -1.7480),
        .init(iata: "BKK", name: "Bangkok Suvarnabhumi", city: "Bangkok", country: "Thailand", countryCode: "TH", lat: 13.6900, lng: 100.7501),
        .init(iata: "BLR", name: "Bengaluru Kempegowda", city: "Bengaluru", country: "India", countryCode: "IN", lat: 13.1986, lng: 77.7066),
        .init(iata: "BNE", name: "Brisbane", city: "Brisbane", country: "Australia", countryCode: "AU", lat: -27.3842, lng: 153.1175),
        .init(iata: "BOG", name: "Bogotá El Dorado", city: "Bogotá", country: "Colombia", countryCode: "CO", lat: 4.7016, lng: -74.1469),
        .init(iata: "BOM", name: "Mumbai Chhatrapati Shivaji", city: "Mumbai", country: "India", countryCode: "IN", lat: 19.0896, lng: 72.8656),
        .init(iata: "BOS", name: "Boston Logan", city: "Boston", country: "United States", countryCode: "US", lat: 42.3656, lng: -71.0096),
        .init(iata: "BRU", name: "Brussels", city: "Brussels", country: "Belgium", countryCode: "BE", lat: 50.9014, lng: 4.4844),
        .init(iata: "BUD", name: "Budapest Ferenc Liszt", city: "Budapest", country: "Hungary", countryCode: "HU", lat: 47.4389, lng: 19.2558),
        .init(iata: "BWI", name: "Baltimore/Washington", city: "Baltimore", country: "United States", countryCode: "US", lat: 39.1774, lng: -76.6684),
        .init(iata: "CAI", name: "Cairo", city: "Cairo", country: "Egypt", countryCode: "EG", lat: 30.1219, lng: 31.4056),
        .init(iata: "CAN", name: "Guangzhou Baiyun", city: "Guangzhou", country: "China", countryCode: "CN", lat: 23.3924, lng: 113.2988),
        .init(iata: "CCU", name: "Kolkata Netaji Subhas Chandra Bose", city: "Kolkata", country: "India", countryCode: "IN", lat: 22.6546, lng: 88.4467),
        .init(iata: "CDG", name: "Paris Charles de Gaulle", city: "Paris", country: "France", countryCode: "FR", lat: 49.0097, lng: 2.5479),
        .init(iata: "CGK", name: "Jakarta Soekarno-Hatta", city: "Jakarta", country: "Indonesia", countryCode: "ID", lat: -6.1256, lng: 106.6559),
        .init(iata: "CHC", name: "Christchurch", city: "Christchurch", country: "New Zealand", countryCode: "NZ", lat: -43.4894, lng: 172.5322),
        .init(iata: "CLT", name: "Charlotte Douglas", city: "Charlotte", country: "United States", countryCode: "US", lat: 35.2140, lng: -80.9431),
        .init(iata: "CMB", name: "Colombo Bandaranaike", city: "Colombo", country: "Sri Lanka", countryCode: "LK", lat: 7.1808, lng: 79.8841),
        .init(iata: "CMN", name: "Casablanca Mohammed V", city: "Casablanca", country: "Morocco", countryCode: "MA", lat: 33.3675, lng: -7.5897),
        .init(iata: "CNX", name: "Chiang Mai", city: "Chiang Mai", country: "Thailand", countryCode: "TH", lat: 18.7668, lng: 98.9626),
        .init(iata: "CPH", name: "Copenhagen", city: "Copenhagen", country: "Denmark", countryCode: "DK", lat: 55.6180, lng: 12.6560),
        .init(iata: "CPT", name: "Cape Town", city: "Cape Town", country: "South Africa", countryCode: "ZA", lat: -33.9715, lng: 18.6021),
        .init(iata: "CTS", name: "Sapporo New Chitose", city: "Sapporo", country: "Japan", countryCode: "JP", lat: 42.7752, lng: 141.6923),
        .init(iata: "CTU", name: "Chengdu Tianfu", city: "Chengdu", country: "China", countryCode: "CN", lat: 30.3120, lng: 104.4416),
        .init(iata: "CUN", name: "Cancún", city: "Cancún", country: "Mexico", countryCode: "MX", lat: 21.0365, lng: -86.8770),
        .init(iata: "DCA", name: "Ronald Reagan Washington National", city: "Washington", country: "United States", countryCode: "US", lat: 38.8521, lng: -77.0377),
        .init(iata: "DEL", name: "Delhi Indira Gandhi", city: "Delhi", country: "India", countryCode: "IN", lat: 28.5562, lng: 77.0999),
        .init(iata: "DEN", name: "Denver", city: "Denver", country: "United States", countryCode: "US", lat: 39.8561, lng: -104.6737),
        .init(iata: "DFW", name: "Dallas/Fort Worth", city: "Dallas", country: "United States", countryCode: "US", lat: 32.8998, lng: -97.0403),
        .init(iata: "DMK", name: "Bangkok Don Mueang", city: "Bangkok", country: "Thailand", countryCode: "TH", lat: 13.9126, lng: 100.6070),
        .init(iata: "DOH", name: "Doha Hamad", city: "Doha", country: "Qatar", countryCode: "QA", lat: 25.2611, lng: 51.6138),
        .init(iata: "DPS", name: "Denpasar Ngurah Rai", city: "Denpasar", country: "Indonesia", countryCode: "ID", lat: -8.7482, lng: 115.1674),
        .init(iata: "DTW", name: "Detroit Metropolitan", city: "Detroit", country: "United States", countryCode: "US", lat: 42.2124, lng: -83.3534),
        .init(iata: "DUB", name: "Dublin", city: "Dublin", country: "Ireland", countryCode: "IE", lat: 53.4213, lng: -6.2701),
        .init(iata: "DXB", name: "Dubai International", city: "Dubai", country: "United Arab Emirates", countryCode: "AE", lat: 25.2532, lng: 55.3657),
        .init(iata: "EDI", name: "Edinburgh", city: "Edinburgh", country: "United Kingdom", countryCode: "GB", lat: 55.9500, lng: -3.3725),
        .init(iata: "EWR", name: "Newark Liberty", city: "Newark", country: "United States", countryCode: "US", lat: 40.6895, lng: -74.1745),
        .init(iata: "EZE", name: "Buenos Aires Ezeiza", city: "Buenos Aires", country: "Argentina", countryCode: "AR", lat: -34.8222, lng: -58.5358),
        .init(iata: "FCO", name: "Rome Fiumicino", city: "Rome", country: "Italy", countryCode: "IT", lat: 41.8003, lng: 12.2389),
        .init(iata: "FLL", name: "Fort Lauderdale-Hollywood", city: "Fort Lauderdale", country: "United States", countryCode: "US", lat: 26.0742, lng: -80.1506),
        .init(iata: "FRA", name: "Frankfurt", city: "Frankfurt", country: "Germany", countryCode: "DE", lat: 50.0379, lng: 8.5622),
        .init(iata: "FUK", name: "Fukuoka", city: "Fukuoka", country: "Japan", countryCode: "JP", lat: 33.5853, lng: 130.4500),
        .init(iata: "GDL", name: "Guadalajara", city: "Guadalajara", country: "Mexico", countryCode: "MX", lat: 20.5217, lng: -103.3111),
        .init(iata: "GIG", name: "Rio de Janeiro Galeão", city: "Rio de Janeiro", country: "Brazil", countryCode: "BR", lat: -22.8090, lng: -43.2506),
        .init(iata: "GLA", name: "Glasgow", city: "Glasgow", country: "United Kingdom", countryCode: "GB", lat: 55.8642, lng: -4.4333),
        .init(iata: "GMP", name: "Seoul Gimpo", city: "Seoul", country: "South Korea", countryCode: "KR", lat: 37.5583, lng: 126.7906),
        .init(iata: "GRU", name: "São Paulo Guarulhos", city: "São Paulo", country: "Brazil", countryCode: "BR", lat: -23.4356, lng: -46.4731),
        .init(iata: "GVA", name: "Geneva", city: "Geneva", country: "Switzerland", countryCode: "CH", lat: 46.2381, lng: 6.1089),
        .init(iata: "HAN", name: "Hanoi Noi Bai", city: "Hanoi", country: "Vietnam", countryCode: "VN", lat: 21.2187, lng: 105.8042),
        .init(iata: "HEL", name: "Helsinki-Vantaa", city: "Helsinki", country: "Finland", countryCode: "FI", lat: 60.3172, lng: 24.9633),
        .init(iata: "HKG", name: "Hong Kong", city: "Hong Kong", country: "Hong Kong", countryCode: "HK", lat: 22.3080, lng: 113.9185),
        .init(iata: "HKT", name: "Phuket", city: "Phuket", country: "Thailand", countryCode: "TH", lat: 8.1132, lng: 98.3169),
        .init(iata: "HND", name: "Tokyo Haneda", city: "Tokyo", country: "Japan", countryCode: "JP", lat: 35.5494, lng: 139.7798),
        .init(iata: "HOU", name: "William P. Hobby", city: "Houston", country: "United States", countryCode: "US", lat: 29.6454, lng: -95.2789),
        .init(iata: "HYD", name: "Hyderabad Rajiv Gandhi", city: "Hyderabad", country: "India", countryCode: "IN", lat: 17.2403, lng: 78.4294),
        .init(iata: "IAD", name: "Washington Dulles", city: "Washington", country: "United States", countryCode: "US", lat: 38.9531, lng: -77.4565),
        .init(iata: "IAH", name: "George Bush Intercontinental", city: "Houston", country: "United States", countryCode: "US", lat: 29.9902, lng: -95.3368),
        .init(iata: "ICN", name: "Seoul Incheon", city: "Seoul", country: "South Korea", countryCode: "KR", lat: 37.4602, lng: 126.4407),
        .init(iata: "IST", name: "Istanbul", city: "Istanbul", country: "Turkey", countryCode: "TR", lat: 41.2753, lng: 28.7519),
        .init(iata: "ITM", name: "Osaka Itami", city: "Osaka", country: "Japan", countryCode: "JP", lat: 34.7855, lng: 135.4382),
        .init(iata: "JED", name: "Jeddah King Abdulaziz", city: "Jeddah", country: "Saudi Arabia", countryCode: "SA", lat: 21.6789, lng: 39.1534),
        .init(iata: "JFK", name: "John F. Kennedy International", city: "New York", country: "United States", countryCode: "US", lat: 40.6413, lng: -73.7781),
        .init(iata: "JNB", name: "Johannesburg O. R. Tambo", city: "Johannesburg", country: "South Africa", countryCode: "ZA", lat: -26.1337, lng: 28.2420),
        .init(iata: "KEF", name: "Keflavík", city: "Reykjavík", country: "Iceland", countryCode: "IS", lat: 63.9850, lng: -22.6056),
        .init(iata: "KHH", name: "Kaohsiung", city: "Kaohsiung", country: "Taiwan", countryCode: "TW", lat: 22.5771, lng: 120.3500),
        .init(iata: "KIX", name: "Osaka Kansai", city: "Osaka", country: "Japan", countryCode: "JP", lat: 34.4320, lng: 135.2304),
        .init(iata: "KTM", name: "Kathmandu Tribhuvan", city: "Kathmandu", country: "Nepal", countryCode: "NP", lat: 27.6981, lng: 85.3592),
        .init(iata: "KUL", name: "Kuala Lumpur", city: "Kuala Lumpur", country: "Malaysia", countryCode: "MY", lat: 2.7456, lng: 101.7072),
        .init(iata: "KWI", name: "Kuwait", city: "Kuwait City", country: "Kuwait", countryCode: "KW", lat: 29.2266, lng: 47.9689),
        .init(iata: "LAS", name: "Harry Reid", city: "Las Vegas", country: "United States", countryCode: "US", lat: 36.0840, lng: -115.1537),
        .init(iata: "LAX", name: "Los Angeles International", city: "Los Angeles", country: "United States", countryCode: "US", lat: 33.9416, lng: -118.4085),
        .init(iata: "LCY", name: "London City", city: "London", country: "United Kingdom", countryCode: "GB", lat: 51.5053, lng: 0.0553),
        .init(iata: "LGA", name: "New York LaGuardia", city: "New York", country: "United States", countryCode: "US", lat: 40.7769, lng: -73.8740),
        .init(iata: "LGW", name: "London Gatwick", city: "London", country: "United Kingdom", countryCode: "GB", lat: 51.1537, lng: -0.1821),
        .init(iata: "LHR", name: "London Heathrow", city: "London", country: "United Kingdom", countryCode: "GB", lat: 51.4700, lng: -0.4543),
        .init(iata: "LIM", name: "Lima Jorge Chávez", city: "Lima", country: "Peru", countryCode: "PE", lat: -12.0219, lng: -77.1144),
        .init(iata: "LIN", name: "Milan Linate", city: "Milan", country: "Italy", countryCode: "IT", lat: 45.4451, lng: 9.2767),
        .init(iata: "LIS", name: "Lisbon Humberto Delgado", city: "Lisbon", country: "Portugal", countryCode: "PT", lat: 38.7742, lng: -9.1342),
        .init(iata: "LOS", name: "Lagos Murtala Muhammed", city: "Lagos", country: "Nigeria", countryCode: "NG", lat: 6.5774, lng: 3.3212),
        .init(iata: "LTN", name: "London Luton", city: "London", country: "United Kingdom", countryCode: "GB", lat: 51.8747, lng: -0.3683),
        .init(iata: "MAA", name: "Chennai", city: "Chennai", country: "India", countryCode: "IN", lat: 12.9941, lng: 80.1709),
        .init(iata: "MAD", name: "Madrid Barajas", city: "Madrid", country: "Spain", countryCode: "ES", lat: 40.4983, lng: -3.5676),
        .init(iata: "MAN", name: "Manchester", city: "Manchester", country: "United Kingdom", countryCode: "GB", lat: 53.3537, lng: -2.2750),
        .init(iata: "MCO", name: "Orlando International", city: "Orlando", country: "United States", countryCode: "US", lat: 28.4312, lng: -81.3081),
        .init(iata: "MCT", name: "Muscat", city: "Muscat", country: "Oman", countryCode: "OM", lat: 23.5933, lng: 58.2844),
        .init(iata: "MEL", name: "Melbourne", city: "Melbourne", country: "Australia", countryCode: "AU", lat: -37.6733, lng: 144.8430),
        .init(iata: "MEX", name: "Mexico City Benito Juárez", city: "Mexico City", country: "Mexico", countryCode: "MX", lat: 19.4361, lng: -99.0719),
        .init(iata: "MIA", name: "Miami International", city: "Miami", country: "United States", countryCode: "US", lat: 25.7959, lng: -80.2870),
        .init(iata: "MNL", name: "Manila Ninoy Aquino", city: "Manila", country: "Philippines", countryCode: "PH", lat: 14.5086, lng: 121.0194),
        .init(iata: "MSP", name: "Minneapolis–Saint Paul", city: "Minneapolis", country: "United States", countryCode: "US", lat: 44.8848, lng: -93.2223),
        .init(iata: "MUC", name: "Munich", city: "Munich", country: "Germany", countryCode: "DE", lat: 48.3538, lng: 11.7861),
        .init(iata: "MXP", name: "Milan Malpensa", city: "Milan", country: "Italy", countryCode: "IT", lat: 45.6306, lng: 8.7281),
        .init(iata: "NBO", name: "Nairobi Jomo Kenyatta", city: "Nairobi", country: "Kenya", countryCode: "KE", lat: -1.3192, lng: 36.9278),
        .init(iata: "NRT", name: "Tokyo Narita", city: "Tokyo", country: "Japan", countryCode: "JP", lat: 35.7720, lng: 140.3929),
        .init(iata: "OKA", name: "Naha", city: "Naha", country: "Japan", countryCode: "JP", lat: 26.2058, lng: 127.6459),
        .init(iata: "OPO", name: "Porto", city: "Porto", country: "Portugal", countryCode: "PT", lat: 41.2361, lng: -8.6775),
        .init(iata: "ORD", name: "Chicago O'Hare", city: "Chicago", country: "United States", countryCode: "US", lat: 41.9742, lng: -87.9073),
        .init(iata: "ORY", name: "Paris Orly", city: "Paris", country: "France", countryCode: "FR", lat: 48.7262, lng: 2.3652),
        .init(iata: "OSL", name: "Oslo Gardermoen", city: "Oslo", country: "Norway", countryCode: "NO", lat: 60.1939, lng: 11.1004),
        .init(iata: "PDX", name: "Portland International", city: "Portland", country: "United States", countryCode: "US", lat: 45.5898, lng: -122.5951),
        .init(iata: "PEK", name: "Beijing Capital", city: "Beijing", country: "China", countryCode: "CN", lat: 40.0801, lng: 116.5846),
        .init(iata: "PER", name: "Perth", city: "Perth", country: "Australia", countryCode: "AU", lat: -31.9403, lng: 115.9669),
        .init(iata: "PHL", name: "Philadelphia International", city: "Philadelphia", country: "United States", countryCode: "US", lat: 39.8729, lng: -75.2437),
        .init(iata: "PHX", name: "Phoenix Sky Harbor", city: "Phoenix", country: "United States", countryCode: "US", lat: 33.4342, lng: -112.0116),
        .init(iata: "PKX", name: "Beijing Daxing", city: "Beijing", country: "China", countryCode: "CN", lat: 39.5098, lng: 116.4105),
        .init(iata: "PRG", name: "Prague Václav Havel", city: "Prague", country: "Czech Republic", countryCode: "CZ", lat: 50.1008, lng: 14.2600),
        .init(iata: "PVG", name: "Shanghai Pudong", city: "Shanghai", country: "China", countryCode: "CN", lat: 31.1443, lng: 121.8083),
        .init(iata: "RUH", name: "Riyadh King Khalid", city: "Riyadh", country: "Saudi Arabia", countryCode: "SA", lat: 24.9578, lng: 46.6989),
        .init(iata: "SAN", name: "San Diego International", city: "San Diego", country: "United States", countryCode: "US", lat: 32.7336, lng: -117.1897),
        .init(iata: "SAW", name: "Istanbul Sabiha Gökçen", city: "Istanbul", country: "Turkey", countryCode: "TR", lat: 40.8986, lng: 29.3092),
        .init(iata: "SCL", name: "Santiago Arturo Merino Benítez", city: "Santiago", country: "Chile", countryCode: "CL", lat: -33.3927, lng: -70.7857),
        .init(iata: "SEA", name: "Seattle-Tacoma", city: "Seattle", country: "United States", countryCode: "US", lat: 47.4502, lng: -122.3088),
        .init(iata: "SFO", name: "San Francisco International", city: "San Francisco", country: "United States", countryCode: "US", lat: 37.6213, lng: -122.3790),
        .init(iata: "SGN", name: "Ho Chi Minh City Tân Sơn Nhất", city: "Ho Chi Minh City", country: "Vietnam", countryCode: "VN", lat: 10.8188, lng: 106.6519),
        .init(iata: "SHA", name: "Shanghai Hongqiao", city: "Shanghai", country: "China", countryCode: "CN", lat: 31.1979, lng: 121.3363),
        .init(iata: "SIN", name: "Singapore Changi", city: "Singapore", country: "Singapore", countryCode: "SG", lat: 1.3644, lng: 103.9915),
        .init(iata: "STN", name: "London Stansted", city: "London", country: "United Kingdom", countryCode: "GB", lat: 51.8860, lng: 0.2389),
        .init(iata: "SYD", name: "Sydney Kingsford Smith", city: "Sydney", country: "Australia", countryCode: "AU", lat: -33.9399, lng: 151.1753),
        .init(iata: "SZX", name: "Shenzhen Bao'an", city: "Shenzhen", country: "China", countryCode: "CN", lat: 22.6393, lng: 113.8108),
        .init(iata: "TLV", name: "Tel Aviv Ben Gurion", city: "Tel Aviv", country: "Israel", countryCode: "IL", lat: 32.0114, lng: 34.8867),
        .init(iata: "TPA", name: "Tampa International", city: "Tampa", country: "United States", countryCode: "US", lat: 27.9755, lng: -82.5332),
        .init(iata: "TPE", name: "Taipei Taoyuan", city: "Taipei", country: "Taiwan", countryCode: "TW", lat: 25.0777, lng: 121.2328),
        .init(iata: "TSA", name: "Taipei Songshan", city: "Taipei", country: "Taiwan", countryCode: "TW", lat: 25.0694, lng: 121.5521),
        .init(iata: "VCE", name: "Venice Marco Polo", city: "Venice", country: "Italy", countryCode: "IT", lat: 45.5053, lng: 12.3519),
        .init(iata: "VIE", name: "Vienna", city: "Vienna", country: "Austria", countryCode: "AT", lat: 48.1103, lng: 16.5697),
        .init(iata: "WAW", name: "Warsaw Chopin", city: "Warsaw", country: "Poland", countryCode: "PL", lat: 52.1657, lng: 20.9671),
        .init(iata: "WLG", name: "Wellington", city: "Wellington", country: "New Zealand", countryCode: "NZ", lat: -41.3272, lng: 174.8053),
        .init(iata: "YUL", name: "Montréal–Trudeau", city: "Montréal", country: "Canada", countryCode: "CA", lat: 45.4706, lng: -73.7408),
        .init(iata: "YVR", name: "Vancouver", city: "Vancouver", country: "Canada", countryCode: "CA", lat: 49.1967, lng: -123.1815),
        .init(iata: "YYC", name: "Calgary", city: "Calgary", country: "Canada", countryCode: "CA", lat: 51.1315, lng: -114.0106),
        .init(iata: "YYZ", name: "Toronto Pearson", city: "Toronto", country: "Canada", countryCode: "CA", lat: 43.6777, lng: -79.6248),
        .init(iata: "ZRH", name: "Zurich", city: "Zurich", country: "Switzerland", countryCode: "CH", lat: 47.4582, lng: 8.5555),
    ]
}
