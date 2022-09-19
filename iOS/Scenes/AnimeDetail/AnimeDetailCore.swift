//
//  AnimeDetailCore.swift
//  Anime Now!
//
//  Created Erik Bautista on 9/6/22.
//  Copyright © 2022. All rights reserved.
//

import Foundation
import ComposableArchitecture

enum AnimeDetailCore {
    typealias LoadableEpisodes = LoadableState<IdentifiedArrayOf<Episode>>

    struct State: Equatable {
        let anime: Anime
        var episodes = LoadableEpisodes.preparing
//        var videoType: SourceType

        var moreInfo = Set<Episode.ID>()

        enum VideoType {
            case episodes(LoadableEpisodes)
            case movie
        }
    }

    enum Action: Equatable {
        case onAppear
        case closeButtonPressed
        case close
        case fetchedEpisodes(Result<[Episode], API.Error>)
        case selectedEpisode(episode: Episode)
        case fetchedSources(Result<[EpisodeSource], API.Error>)
        case moreInfo(id: Episode.ID)
    }

    struct Environment {
        let animeClient: AnimeClient
        let mainQueue: AnySchedulerOf<DispatchQueue>
        let mainRunLoop: AnySchedulerOf<RunLoop>
    }
}

extension AnimeDetailCore.State {
    var format: Anime.Format {
        anime.format
    }
}

extension AnimeDetailCore {
    static var reducer: Reducer<AnimeDetailCore.State, AnimeDetailCore.Action, AnimeDetailCore.Environment> {
        .init { state, action, environment in
            struct CancelFetchingEpisodesId: Hashable {}
            struct CancelFetchingSourcesId: Hashable {}

            switch action {
            case .onAppear:
                if state.anime.status == .upcoming {
                    break
                }
                state.episodes = .loading
                return environment.animeClient.getEpisodes(state.anime.id)
                    .subscribe(on: DispatchQueue.global(qos: .userInteractive))
                    .receive(on: environment.mainQueue)
                    .catchToEffect()
                    .map(Action.fetchedEpisodes)
                    .cancellable(id: CancelFetchingEpisodesId())
            case .fetchedEpisodes(.success(let episodes)):
                state.episodes = .success(.init(uniqueElements: episodes))
            case .fetchedEpisodes(.failure):
                state.episodes = .failed
            case .moreInfo(id: let id):
               if state.moreInfo.contains(id) {
                   state.moreInfo.remove(id)
               } else {
                   state.moreInfo.insert(id)
               }
            case .selectedEpisode(episode: let episode):
                return environment.animeClient.getSources(episode.id)
                    .subscribe(on: DispatchQueue.global(qos: .userInteractive))
                    .receive(on: environment.mainQueue)
                    .catchToEffect()
                    .map(Action.fetchedSources)
                    .cancellable(id: CancelFetchingSourcesId())
            case .fetchedSources:
                break
            case .closeButtonPressed:
                return .concatenate(
                    .cancel(id: CancelFetchingEpisodesId()),
                    .cancel(id: CancelFetchingSourcesId()),
                    .init(value: .close)
                )
            case .close:
                break
            }
            return .none
        }
    }
}