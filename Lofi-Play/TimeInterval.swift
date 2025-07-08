//
//  TimeInterval.swift
//  Lofi-Play
//
//  Created by 김민서 on 6/20/25.
//
import Foundation

extension TimeInterval {
    /// TimeInterval을 "mm:ss" 또는 "h:mm:ss" 형식의 문자열로 변환합니다.
    func formatAsTime() -> String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    /// TimeInterval을 더 상세한 형식으로 변환합니다 (선택사항)
    func formatAsDetailedTime() -> String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        var components: [String] = []
        
        if hours > 0 {
            components.append("\(hours)시간")
        }
        if minutes > 0 {
            components.append("\(minutes)분")
        }
        if seconds > 0 || components.isEmpty {
            components.append("\(seconds)초")
        }
        
        return components.joined(separator: " ")
    }
}
