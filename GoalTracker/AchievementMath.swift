//
//  AchievementMath.swift
//  GoalTracker
//
//  達成度カード(ReflectionAchievementCard / CompositeSummaryCard)の
//  数値・リング区間の計算を、UIから独立した検証可能な純粋関数として提供する。
//
//  修正の背景:
//  従来は分母を「rate3 != nil ? 3 : (rate2 != nil ? 2 : 1)」で決めていたため、
//  rate2 == nil かつ rate3 != nil(週次目標なし・月次目標ありの月)のときに
//  2要素の合計を3で割ってしまい、達成度が実際より低く表示されていた。
//  本実装では「非nilの達成率だけを配列にまとめ、その件数を分母」とする。
//

import Foundation

enum AchievementMath {

    /// nilを除いた達成率のみを順序を保って返す
    static func validRates(_ rates: [Double?]) -> [Double] {
        rates.compactMap { $0 }
    }

    /// 非nil要素数を分母とした平均達成率。要素が1件もない場合は0
    static func average(_ rates: [Double?]) -> Double {
        let valid = validRates(rates)
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0, +) / Double(valid.count)
    }

    /// リング描画用の区間(trimのfrom/to、0.0〜1.0)。
    /// 分母は非nil要素数で、averageと必ず一致する
    /// (全区間の合計 = average と同じ割合になる)。
    static func segmentBounds(_ rates: [Double?]) -> [(from: Double, to: Double)] {
        let valid = validRates(rates)
        guard !valid.isEmpty else { return [] }
        let denominator = Double(valid.count)
        var accumulated = 0.0
        return valid.map { rate in
            let from = accumulated / denominator
            accumulated += rate
            return (from: from, to: accumulated / denominator)
        }
    }

    /// 達成率と描画色などの付随情報をペアのまま非nilだけに絞り込む
    /// (リングの区間と色の対応がずれないようにするためのヘルパー)
    static func validPairs<T>(_ pairs: [(rate: Double?, value: T)]) -> [(rate: Double, value: T)] {
        pairs.compactMap { pair in
            pair.rate.map { (rate: $0, value: pair.value) }
        }
    }
}
