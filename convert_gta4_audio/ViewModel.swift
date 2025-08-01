//
//  ViewModel.swift
//  convert_gta4_audio
//
//  Created by Alexey Vorobyov on 31.07.2025.
//

import Foundation

@Observable
class ViewModel {
    func doTheHarlemShake() {
        print("ℹ️ documents directory: \(URL.documentsDirectory.path)")
        Task {
            guard let legacyRadio = try? await loadLegacyRadio() else { return }
            convert(legacySeries: legacyRadio)
        }
    }
}

private extension ViewModel {
    func loadLegacyRadio() async throws -> LegacySimRadioDTO.GameSeries? {
        let baseUrl = "https://raw.githubusercontent.com/tmp-acc/"
        let simRadioURLs = [
            //            "GTA-V-Radio-Stations-TestDownload/short/sim_radio_stations.json",
//            "GTA-V-Radio-Stations-TestDownload/long/sim_radio_stations.json",
//            "GTA-IV-Radio-Stations/master/sim_radio_stations.json",
            "GTA-IV-Radio-Stations/master/sim_radio_stations.json"
        ].compactMap { URL(string: "\(baseUrl)\($0)") }
        guard let url = simRadioURLs.first,
              let jsonData = try? await URLSession.shared.data(from: url) else { return nil }

        let radio = try? JSONDecoder().decode(LegacySimRadioDTO.GameSeries.self, from: jsonData.0)
        return radio
    }

    func convert(legacySeries: LegacySimRadioDTO.GameSeries) {
        let commonTracklists = legacySeries.common.commonTracklists
        let stationTracklists = legacySeries.stations.map(\.stationTracklists)
        let allTracklists = commonTracklists + stationTracklists.flatMap(\.self)
        let result = SimRadioDTO.GameSeries(
            origin: nil,
            trackLists: allTracklists,
            stations: legacySeries.stations.map { .init(legacy: $0) }
        )
        saveJSON(radio: result, name: "sim_radio_stations.json")
    }
}

func saveJSON(radio: SimRadioDTO.GameSeries, name: String) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
    do {
        let jsonData = try encoder.encode(radio)
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError()
        }
        let fileURL = documentsDirectory.appendingPathComponent(name)
        try jsonData.write(to: fileURL, options: .atomic)
        print("JSON successfully saved to file: \(fileURL.path)")

    } catch {
        print("Error encoding or writing JSON: \(error)")
    }
}

extension LegacySimRadioDTO.GameSeriesCommon {
    var commonTracklists: [SimRadioDTO.TrackList] {
        fileGroups.map {
            SimRadioDTO.TrackList(
                id: .init(value: $0.tag),
                tracks: $0.files.map { .init(legacy: $0) }
            )
        }
    }
}

extension LegacySimRadioDTO.Station {
    var stationTracklists: [SimRadioDTO.TrackList] {
        var result = fileGroups.map {
            let id = "\(tag)_\($0.tag)"
            return SimRadioDTO.TrackList(
                id: .init(value: id),
                tracks: $0.files.map {
                    .init(
                        legacy: $0,
                        idPrefix: tag,
                        pathPrefix: tag
                    )
                }
            )
        }
        let introFiles = fileGroups.flatMap { $0.files.flatMap { $0.attaches?.files ?? [] } }
        let introTrackList = SimRadioDTO.TrackList(
            id: .init(value: "\(tag)_\("intro")"),
            tracks: introFiles.map {
                .init(
                    legacy: $0,
                    idPrefix: tag,
                    pathPrefix: tag
                )
            }
        )
        if !introTrackList.tracks.isEmpty {
            result.append(introTrackList)
        }
        return result
    }
}

extension SimRadioDTO.Station {
    init(legacy: LegacySimRadioDTO.Station) {
        let tracklists = legacy.stationTracklists.map(\.id)

        self.init(
            isHidden: nil,
            id: .init(value: legacy.tag),
            meta: .init(legacy: legacy.info, stationTag: legacy.tag),
            trackLists: tracklists + tracklists.commonTracklists,
            playlist: .init(
                firstFragment: [],
                fragments: [],
                options: nil,
                positions: nil
            )
        )
    }
}

extension [SimRadioDTO.TrackList.ID] {
    var commonTracklists: [SimRadioDTO.TrackList.ID] {
        [
            ("to_news", "news"),
            ("to_adverts", "adverts"),
            ("to_weather", "weather")
        ].reduce(into: []) { result, mapping in
            if contains(where: { $0.value.hasSuffix(mapping.0) }) {
                result.append(.init(value: mapping.1))
            }
        }
    }
}

extension SimRadioDTO.StationMeta {
    init(
        legacy: LegacySimRadioDTO.StationInfo,
        stationTag: String
    ) {
        let artworkName = (legacy.logo as NSString).deletingPathExtension
        self.init(
            title: legacy.title,
            artwork: "\(stationTag)/\(artworkName)",
            host: legacy.dj,
            genre: legacy.genre,
            genreCode: nil
        )
    }
}

extension SimRadioDTO.Track {
    init(
        legacy: LegacySimRadioDTO.File,
        idPrefix: String? = nil,
        pathPrefix: String? = nil
    ) {
        let introTracks = (legacy.attaches?.files ?? []).map {
            SimRadioDTO.Track(legacy: $0, idPrefix: idPrefix).id
        }

        let path = (legacy.path as NSString).deletingPathExtension
        let id: String = path
            .split(separator: "/")
            .suffix(2)
            .joined(separator: "_")

        let idWithPrefix = if let idPrefix { "\(idPrefix)_\(id)" } else { id }
        let pathWithPrefix = if let pathPrefix { "\(pathPrefix)/\(path)" } else { path }

        self.init(
            id: .init(value: idWithPrefix),
            path: pathWithPrefix,
            start: nil,
            duration: legacy.duration,
            intro: introTracks.isEmpty ? nil : introTracks,
            markers: nil,
            trackList: nil
        )
    }
}
